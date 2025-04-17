// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";
import {BLS} from "../../src/libraries/BLS.sol";
import {TypesLib} from "../../src/libraries/TypesLib.sol";

import {UUPSProxy} from "../../src/proxy/UUPSProxy.sol";
import {SignatureSchemeAddressProvider} from "../../src/signature-schemes/SignatureSchemeAddressProvider.sol";
import {SignatureSender} from "../../src/signature-requests/SignatureSender.sol";
import {BN254SignatureScheme} from "../../src/signature-schemes/BN254SignatureScheme.sol";
import {RandomnessSender} from "../../src/randomness/RandomnessSender.sol";
import {Randomness} from "../../src/randomness/Randomness.sol";
import {MockRandomnessReceiver} from "../../src/mocks/MockRandomnessReceiver.sol";

contract RandomnessSenderTest is Test {
    SignatureSchemeAddressProvider public addrProvider;
    BN254SignatureScheme public bn254SignatureScheme;

    UUPSProxy signatureSenderProxy;
    UUPSProxy randomnessSenderProxy;

    SignatureSender public signatureSender;
    RandomnessSender public randomnessSender;

    bytes public validPK =
        hex"204a5468e6d01b87c07655eebbb1d43913e197f53281a7d56e2b1a0beac194aa00899f6a3998ecb2f832d35025bf38bef7429005e6b591d9e0ffb10078409f220a6758eec538bb8a511eed78c922a213e4cc06743aeb10ed77f63416fe964c3505d04df1d2daeefa07790b41a9e0ab762e264798bc36340dc3a0cc5654cefa4b";
    bytes public validSignature =
        hex"0d1a2ccd46cb80f94b40809dbd638b44c78e456a4e06b886e8c8f300fa4073950b438ea53140bb1bc93a1c632ab4df0a07d702f34e48ecb7d31da7762a320ad5";

    bytes public conditions = "";
    string public constant bn254SignatureSchemeID = "BN254";
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    address public immutable owner = address(1);

    function setUp() public {
        vm.startPrank(owner);

        // deploy signature scheme address provider
        addrProvider = new SignatureSchemeAddressProvider(address(0));

        // deploy bn254 signature scheme
        bn254SignatureScheme = new BN254SignatureScheme();
        addrProvider.updateSignatureScheme(bn254SignatureSchemeID, address(bn254SignatureScheme));

        BLS.PointG2 memory pk = abi.decode(validPK, (BLS.PointG2));

        // deploy implementation contracts for signature and randomness senders
        SignatureSender signatureSenderImplementationV1 = new SignatureSender();
        RandomnessSender randomnessSenderImplementationV1 = new RandomnessSender();

        // deploy proxy contracts and point them to their implementation contracts
        signatureSenderProxy = new UUPSProxy(address(signatureSenderImplementationV1), "");
        console.log("Signature Sender proxy contract deployed at: ", address(signatureSenderProxy));

        randomnessSenderProxy = new UUPSProxy(address(randomnessSenderImplementationV1), "");
        console.log("Randomness Sender proxy contract deployed at: ", address(randomnessSenderProxy));

        // wrap proxy address in implementation ABI to support delegate calls
        signatureSender = SignatureSender(address(signatureSenderProxy));
        randomnessSender = RandomnessSender(address(randomnessSenderProxy));

        // initialize the contracts
        signatureSender.initialize([pk.x[1], pk.x[0]], [pk.y[1], pk.y[0]], owner, address(addrProvider));
        randomnessSender.initialize(address(signatureSender), owner);

        vm.stopPrank();
    }

    function test_DeploymentConfigurations() public view {
        assertTrue(signatureSender.hasRole(ADMIN_ROLE, owner));
        assertTrue(randomnessSender.hasRole(ADMIN_ROLE, owner));
        assert(address(signatureSender) != address(0));
        assert(address(randomnessSender) != address(0));
        console.logBytes(bn254SignatureScheme.DST());
        console.log(bn254SignatureScheme.getChainId());
        console.logString(string(bn254SignatureScheme.DST()));
    }

    function test_requestRandomness() public {
        MockRandomnessReceiver consumer = new MockRandomnessReceiver(address(randomnessSender));

        uint256 nonce = 1;
        uint256 requestId = 1;

        TypesLib.RandomnessRequest memory r = TypesLib.RandomnessRequest({nonce: nonce, callback: address(consumer)});
        bytes memory m = randomnessSender.messageFrom(r);
        console.logBytes(m);

        vm.expectEmit(true, true, false, true);
        emit RandomnessSender.RandomnessRequested(requestId, nonce, address(consumer), block.timestamp);
        consumer.rollDice();

        uint256 requestIdFromConsumer = consumer.requestId();

        vm.prank(owner);
        signatureSender.fulfilSignatureRequest(requestIdFromConsumer, validSignature);
        assertFalse(signatureSender.isInFlight(requestIdFromConsumer));
    }

    function test_UpdateSignatureScheme() public {
        vm.prank(owner);
        vm.expectRevert("Invalid contract address for schemeAddress");
        addrProvider.updateSignatureScheme(bn254SignatureSchemeID, 0x73D1EcCa90a16F27691c63eCad7D5119f0bC743A);
    }

    function test_requestRandomnessWithCallback() public {
        MockRandomnessReceiver consumer = new MockRandomnessReceiver(address(randomnessSender));

        assert(address(consumer.randomnessSender()) != address(0));

        uint256 requestId = 1;
        bytes memory message = hex"b10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6";
        bytes memory messageHash =
            hex"13bdbf3f759a1131f123b2db998675f963efc434b14a4e244533e1bd21312a27136e00872336b98d30449c6b08f8ed8b34306c6ffd969f036833ec1ed81ca31f";

        vm.expectEmit(true, true, true, true, address(signatureSender));
        emit SignatureSender.SignatureRequested(
            requestId, address(randomnessSender), "BN254", message, messageHash, hex"", block.timestamp
        );
        consumer.rollDice();

        uint256 requestID = consumer.requestId();
        assert(requestID > 0);

        assert(signatureSender.isInFlight(requestID));
        assert(signatureSender.getCountOfUnfulfilledRequestIds() == 1);

        vm.expectEmit(true, false, false, true, address(signatureSender));
        emit SignatureSender.SignatureRequestFulfilled(requestID, validSignature);

        vm.prank(owner);
        signatureSender.fulfilSignatureRequest(requestID, validSignature);
        assertFalse(signatureSender.isInFlight(requestID));

        assertEq(consumer.randomness(), keccak256(validSignature));

        assert(!signatureSender.isInFlight(requestID));
        assert(signatureSender.getCountOfUnfulfilledRequestIds() == 0);
        assert(signatureSender.getAllErroredRequestIds().length == 0);
        assert(signatureSender.getAllFulfilledRequestIds().length == 1);
    }

    // Randomness library tests
    function test_selectArrayIndices_Zero_returnsEmpty() public pure {
        uint256[] memory expected = new uint256[](0);
        uint256[] memory actual = Randomness.selectArrayIndices(0, 1, hex"deadbeef");
        assertEq(expected, actual, "array was not empty");
    }

    function test_selectArrayIndices_One_returnsAll() public pure {
        uint256[] memory expected = new uint256[](1);
        expected[0] = uint256(0);
        uint256[] memory actual = Randomness.selectArrayIndices(1, 1, hex"deadbeef");
        assertEq(expected, actual, "full array wasn't returned");
    }

    function test_selectArrayIndices_ReturnsCorrectCount() public pure {
        uint256 countToDraw = 10;
        uint256 arrLength = 100;
        uint256[] memory actual = Randomness.selectArrayIndices(arrLength, countToDraw, hex"deadbeef");
        assertEq(actual.length, countToDraw, "array return didn't have the right count");
        for (uint256 i = 0; i < actual.length; i++) {
            assert(i <= arrLength);
        }
    }

    function test_randomnessSignatureVerification() public view {
        address requester = address(10);
        uint256 requestID = 1;
        bool passedVerificationCheck =
            Randomness.verify(address(randomnessSender), address(signatureSender), validSignature, requestID, requester, bn254SignatureScheme.DST());
        assert(passedVerificationCheck);
    }
}

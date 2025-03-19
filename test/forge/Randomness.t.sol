// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";
import {BLS} from "../../src/libraries/BLS.sol";
import {TypesLib} from "../../src/libraries/TypesLib.sol";

import {UUPSProxy} from "../../src/proxy/UUPSProxy.sol";
import {SignatureSchemeAddressProvider} from "../../src/signature-schemes/SignatureSchemeAddressProvider.sol";
import {SignatureSender} from "../../src/signature-requests/SignatureSender.sol";
import {MockBN254SignatureScheme} from "../../src/mocks/MockBN254SignatureScheme.sol";
import {RandomnessSender} from "../../src/randomness/RandomnessSender.sol";
import {Randomness} from "../../src/randomness/Randomness.sol";
import {MockRandomnessReceiver} from "../../src/mocks/MockRandomnessReceiver.sol";

contract RandomnessSenderTest is Test {
    SignatureSchemeAddressProvider public addrProvider;
    MockBN254SignatureScheme public bn254SignatureScheme;

    UUPSProxy signatureSenderProxy;
    UUPSProxy randomnessSenderProxy;

    SignatureSender public signatureSender;
    RandomnessSender public randomnessSender;

    bytes public validPK =
        hex"17f941e4476dcbb7f1bcdd8009de1c0eb566584dcc71f2fdd47c19299e1b157b1e19f27cfb92e62703c6749417ddfdfcc27c97c468017d7f5b38de1c18dc00dc25c3b772e4a73242e892c96926f61e7337dc2e71fe0627f05908d4d53f5cda222767676ceb18f948326ab16d056fd553bed1d2a6aa0e83f59b90c35a7ef9d073";
    bytes public validSignature =
        hex"2eeaedb81b1db5f76c1cfa65c30d932140d373581d20df6359fb5543a8da994f08db5e1ca5a8da473cee8627e9babdb50081ceff658841762907cc02bb32b6bc";

    bytes public conditions = "";
    string public constant bn254SignatureSchemeID = "BN254";
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    address public immutable owner = address(1);

    function setUp() public {
        vm.startPrank(owner);

        // deploy signature scheme address provider
        addrProvider = new SignatureSchemeAddressProvider(address(0));

        // deploy bn254 signature scheme
        bn254SignatureScheme = new MockBN254SignatureScheme();
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
        signatureSender.initialize(pk.x, pk.y, owner, address(addrProvider));
        randomnessSender.initialize(address(signatureSender), owner);

        vm.stopPrank();
    }

    function test_DeploymentConfigurations() public view {
        assertTrue(signatureSender.hasRole(ADMIN_ROLE, owner));
        assertTrue(randomnessSender.hasRole(ADMIN_ROLE, owner));
        assert(address(signatureSender) != address(0));
        assert(address(randomnessSender) != address(0));
    }

    function test_requestRandomness() public {
        MockRandomnessReceiver consumer = new MockRandomnessReceiver(address(randomnessSender));

        uint256 nonce = 1;
        uint256 requestId = 1;

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

    function test_requestRandomnessWithPublicKeyAsSerialisedG2Point() public {
        // public key as G2 Point extracted from bls-bn254-js using mcl.serialiseG2Point(pubKey)
        // [
        //     12442316349387811221527474815635500164351084936938085948346776284608224569107n,
        //     19858693350313519863251011409884323881765010968244803200893755253561698475319n,
        //     6652058991114990590879242656355868341472089621891739731103204316870185931002n,
        //     4797408320450670032659855449042593139334917799405362591512354151532022265130n
        // ]

        vm.prank(owner);
        BLS.PointG2 memory pk = BLS.PointG2({
            x: [
                12442316349387811221527474815635500164351084936938085948346776284608224569107,
                19858693350313519863251011409884323881765010968244803200893755253561698475319
            ],
            y: [
                6652058991114990590879242656355868341472089621891739731103204316870185931002,
                4797408320450670032659855449042593139334917799405362591512354151532022265130
            ]
        });

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
        signatureSender.initialize(pk.x, pk.y, owner, address(addrProvider));
        randomnessSender.initialize(address(signatureSender), owner);

        MockRandomnessReceiver consumer = new MockRandomnessReceiver(address(randomnessSender));

        uint256 requestId = 1;
        uint256 nonce = 1;

        vm.expectEmit(true, true, false, true);
        emit RandomnessSender.RandomnessRequested(requestId, nonce, address(consumer), block.timestamp);
        consumer.rollDice();

        uint256 requestIdFromConsumer = consumer.requestId();

        vm.prank(owner);
        validSignature =
            hex"27b3ffac2cb20c0e84870b2faae9095a3706fe34de99de92d0e447eb392e19b42bbff765ad9190fae62e2c4801204194c604acf8baf17a6b67a62ed59c7549f7";
        signatureSender.fulfilSignatureRequest(requestIdFromConsumer, validSignature);
        assertFalse(signatureSender.isInFlight(requestIdFromConsumer));
    }

    function test_requestRandomnessWithCallback() public {
        MockRandomnessReceiver consumer = new MockRandomnessReceiver(address(randomnessSender));

        assert(address(consumer.randomnessSender()) != address(0));

        uint256 requestId = 1;
        bytes memory message = hex"f1340c24d522ebe58dea2f543c1935c1978858405e39cf96c0e37cc82831b483";
        bytes memory messageHash =
            hex"1448564251ddb6420dbe7b5936558cd5f8d2fb224fb21097392c5b6dbc11dfff1a9c3cbd091dbfb492938a7a8014f8ce0c2d3cac9738f622d74df53334cfa833";

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
            Randomness.verify(address(randomnessSender), address(signatureSender), validSignature, requestID, requester);
        assert(passedVerificationCheck);
    }
}

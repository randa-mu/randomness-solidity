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
        hex"193dd83042440aa88f03559af73082aa3a82fd75ac010e44f998df71a70c1b18091e61b376a2269e8781808a334c4d003a6d28d0f1c846c77ad616ef46036efb1356aff6f95e17ffed7154053386fb08d45d7d6c243fefe735533c41f20d2f66292a799c4de5c4101e9cd6234419cafde90ce78372363329e8013a6591dc1f4c";
    bytes public validSignature =
        hex"239f4439927ce9a65d9faa6a3dc37e76465ca03ccb9b5eac7431ea3672519cb40edeb214c433757f8168b48057c03f7ead38c7ccd5e640da35f536cda7368cdb";

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

    function test_requestRandomnessWithPublicKeyAsSerialisedG2Point() public {
        vm.prank(owner);
        BLS.PointG2 memory pk = BLS.PointG2({
            x: [
                8638149349330570108677652796441858165325404935563082096242826356078161984234,
                16121525072112359361934926943209995720689965714217991232266179978519906297287
            ],
            y: [
                16807748867183577599481162153843986787005704461067392034723877177545450990242,
                10711948243348821890958607098066069707979954878386017489889834504283417879449
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
            hex"07cb8bd273e8f72e8563d4c40a186a93df75bd1783d1beacf9ed9cac80f0e7f7150170e72cde05b9a33aa3a8a10a4cde04c37f41860c5a5d585de9cf89d810db";
        signatureSender.fulfilSignatureRequest(requestIdFromConsumer, validSignature);
        assertFalse(signatureSender.isInFlight(requestIdFromConsumer));
    }

    function test_requestRandomnessWithCallback() public {
        MockRandomnessReceiver consumer = new MockRandomnessReceiver(address(randomnessSender));

        assert(address(consumer.randomnessSender()) != address(0));

        uint256 requestId = 1;
        bytes memory message = hex"f1340c24d522ebe58dea2f543c1935c1978858405e39cf96c0e37cc82831b483";
        bytes memory messageHash =
            hex"239feb7815f404ac6f284711d3667256be9be0eb8a962de1b31d21b253212a0b229fbde78040491bfa60796624dfaa8cca66be300352841d3d42712b81f5485f";

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

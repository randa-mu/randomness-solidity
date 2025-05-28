// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";

import {
    TypesLib,
    RandomnessTest,
    Deployment,
    SignatureSchemeAddressProvider,
    RandomnessSender,
    SignatureSender,
    BN254SignatureScheme,
    MockRandomnessReceiver
} from "./base/Randomness.t.sol";

import {MockRevertingRandomnessReceiver} from "../../src/mocks/MockRevertingRandomnessReceiver.sol";

contract DirectFundingTest is RandomnessTest {
    function test_FulfillSignatureRequest_WithDirectFunding_Successfully() public {
        mockRandomnessReceiver = deployRandomnessReceiver(admin, address(randomnessSender));
        assertEq(mockRandomnessReceiver.randomness(), 0x0);

        uint256 nonce = 1;
        uint256 requestId = 1;

        TypesLib.RandomnessRequestCreationParams memory r =
            TypesLib.RandomnessRequestCreationParams({nonce: nonce, callback: address(mockRandomnessReceiver)});
        bytes memory m = randomnessSender.messageFrom(r);
        console.logBytes(m);

        // get request price
        uint32 callbackGasLimit = 500_000;
        uint256 requestPrice = randomnessSender.calculateRequestPriceNative(callbackGasLimit);

        assertTrue(requestPrice > 0, "Invalid request price");
        console.log("Estimated request price", requestPrice);

        // create randomness request
        vm.expectEmit(true, true, false, true);
        emit RandomnessSender.RandomnessRequested(requestId, nonce, address(mockRandomnessReceiver), block.timestamp);
        mockRandomnessReceiver.rollDiceWithDirectFunding{value: requestPrice}(callbackGasLimit);

        uint256 requestIdFromConsumer = mockRandomnessReceiver.requestId();

        // fetch request information including callbackGasLimit from signature sender
        TypesLib.SignatureRequest memory signatureRequest = signatureSender.getRequest(requestId);

        // fetch request information from randomness sender
        TypesLib.RandomnessRequest memory randomnessRequest = randomnessSender.getRequest(requestId);

        assertTrue(
            randomnessRequest.callbackGasLimit == callbackGasLimit,
            "Stored callbackGasLimit does not match callbacGasLimit from user request"
        );

        assertTrue(randomnessRequest.subId == 0, "Direct funding request id should be zero");
        assertTrue(
            randomnessRequest.directFundingFeePaid > 0 && randomnessRequest.directFundingFeePaid == requestPrice,
            "Invalid price paid by user contract for request"
        );
        assertTrue(
            randomnessRequest.requestId == requestId, "Request id mismatch between randomnessSender and signatureSender"
        );

        vm.txGasPrice(100_000);
        uint256 gasBefore = gasleft();

        vm.prank(admin);
        signatureSender.fulfillSignatureRequest(requestIdFromConsumer, validSignature);

        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;
        console.log("Request CallbackGasLimit:", randomnessRequest.callbackGasLimit);
        console.log("Request CallbackGasPrice:", randomnessRequest.directFundingFeePaid);
        console.log("Tx Gas used:", gasUsed);
        console.log("Tx Gas price (wei):", tx.gasprice);
        console.log("Tx Total cost (wei):", gasUsed * tx.gasprice);

        assertFalse(signatureSender.isInFlight(requestIdFromConsumer));
        assertEq(mockRandomnessReceiver.randomness(), keccak256(validSignature));

        assert(!signatureSender.isInFlight(requestId));
        assert(signatureSender.getCountOfUnfulfilledRequestIds() == 0);
        assert(signatureSender.getAllErroredRequestIds().length == 0);
        assert(signatureSender.getAllFulfilledRequestIds().length == 1);

        assertTrue(
            !signatureSender.hasErrored(requestId),
            "Payment collection in callback to receiver contract should not fail"
        );

        signatureRequest = signatureSender.getRequest(requestId);
        assertTrue(signatureRequest.isFulfilled, "Signature not provided in signature sender by offchain oracle");

        // check deductions from user and withdrawable amount in blocklock sender for admin
        randomnessRequest = randomnessSender.getRequest(requestId);

        console.log("Direct funding fee paid", randomnessRequest.directFundingFeePaid);
        console.log(
            "Revenue after actual callback tx cost", randomnessRequest.directFundingFeePaid - (gasUsed * tx.gasprice)
        );

        assertTrue(
            randomnessSender.s_totalNativeBalance() == 0, "We don't expect any funded subscriptions at this point"
        );
        assertTrue(
            randomnessSender.s_withdrawableDirectFundingFeeNative() == randomnessRequest.directFundingFeePaid,
            "Request price paid should be withdrawable by admin at this point"
        );
        assertTrue(
            randomnessSender.s_withdrawableSubscriptionFeeNative() == 0,
            "We don't expect any funded subscriptions at this point"
        );

        vm.prank(admin);
        uint256 adminBalance = admin.balance;
        randomnessSender.withdrawDirectFundingFeesNative(payable(admin));
        assertTrue(
            admin.balance + randomnessRequest.directFundingFeePaid > adminBalance,
            "Admin balance should be higher after withdrawing fees"
        );
    }

    function test_CallbackShouldNotRevert_IfInterfaceIsNotImplemented() public {
        assertTrue(randomnessSender.s_configured(), "BlocklockSender not configured");
        assertFalse(randomnessSender.s_disabled(), "BlocklockSender is paused");

        // get request price
        uint32 callbackGasLimit = 500_000;
        uint256 requestPrice = randomnessSender.calculateRequestPriceNative(callbackGasLimit);

        // make randomness request
        vm.prank(alice);
        uint32 requestCallbackGasLimit = callbackGasLimit;
        uint256 requestId = randomnessSender.requestRandomness{value: requestPrice}(requestCallbackGasLimit);

        vm.txGasPrice(100_000);
        vm.prank(admin);
        signatureSender.fulfillSignatureRequest(requestId, validSignature);

        assertFalse(signatureSender.isInFlight(requestId));
        // fetch request information from randomness sender
        TypesLib.RandomnessRequest memory randomnessRequest = randomnessSender.getRequest(requestId);
        assertEq(keccak256(randomnessRequest.signature), keccak256(validSignature));
    }

    function test_FulfillDecryptionRequest_WithLowCallbackGasLimit() public {
        mockRandomnessReceiver = deployRandomnessReceiver(admin, address(randomnessSender));
        assertEq(mockRandomnessReceiver.randomness(), 0x0);

        uint256 requestId = 1;

        // get request price
        uint32 callbackGasLimit = 1000;
        uint256 requestPrice = randomnessSender.calculateRequestPriceNative(callbackGasLimit);

        // create randomness request
        mockRandomnessReceiver.rollDiceWithDirectFunding{value: requestPrice}(callbackGasLimit);

        // fetch request information from randomness sender
        TypesLib.RandomnessRequest memory randomnessRequest = randomnessSender.getRequest(requestId);
        assertEq(randomnessRequest.callbackGasLimit, callbackGasLimit);
        assertGt(randomnessRequest.directFundingFeePaid, 0);

        // fulfill request
        vm.prank(admin);
        signatureSender.fulfillSignatureRequest(requestId, validSignature);

        // fetch request information from randomness sender
        randomnessRequest = randomnessSender.getRequest(requestId);

        uint256 requestIdFromConsumer = mockRandomnessReceiver.requestId();

        assertFalse(signatureSender.isInFlight(requestIdFromConsumer));
        // if callback gas limit is too low, callback to receiver contract will not work
        // but user will be charged for gas overhead
        assertEq(mockRandomnessReceiver.randomness(), 0x0);
    }

    function test_FulfillDecryptionRequest_WithZeroCallbackGasLimit() public {
        mockRandomnessReceiver = deployRandomnessReceiver(admin, address(randomnessSender));
        assertEq(mockRandomnessReceiver.randomness(), 0x0);

        uint256 requestId = 1;

        // get request price
        uint32 callbackGasLimit = 0;
        uint256 requestPrice = randomnessSender.calculateRequestPriceNative(callbackGasLimit);

        // create randomness request
        mockRandomnessReceiver.rollDiceWithDirectFunding{value: requestPrice}(callbackGasLimit);

        // fetch request information from randomness sender
        TypesLib.RandomnessRequest memory randomnessRequest = randomnessSender.getRequest(requestId);
        assertEq(randomnessRequest.callbackGasLimit, callbackGasLimit);
        assertGt(randomnessRequest.directFundingFeePaid, 0);

        // fulfill request
        vm.prank(admin);
        signatureSender.fulfillSignatureRequest(requestId, validSignature);

        // fetch request information from randomness sender
        randomnessRequest = randomnessSender.getRequest(requestId);

        uint256 requestIdFromConsumer = mockRandomnessReceiver.requestId();

        assertFalse(signatureSender.isInFlight(requestIdFromConsumer));
        assertEq(mockRandomnessReceiver.randomness(), 0x0);
    }

    function test_FulfillDecryptionRequest_WithRevertingReceiver() public {
        MockRevertingRandomnessReceiver mockRandomnessReceiver =
            new MockRevertingRandomnessReceiver(address(randomnessSender), admin);

        uint256 requestId = 1;

        // get request price
        uint32 callbackGasLimit = 200_000;
        uint256 requestPrice = randomnessSender.calculateRequestPriceNative(callbackGasLimit);

        // create randomness request
        mockRandomnessReceiver.rollDiceWithDirectFunding{value: requestPrice}(callbackGasLimit);

        // fetch request information from randomness sender
        TypesLib.RandomnessRequest memory randomnessRequest = randomnessSender.getRequest(requestId);
        assertEq(randomnessRequest.callbackGasLimit, callbackGasLimit);
        assertGt(randomnessRequest.directFundingFeePaid, 0);

        // fulfill request
        vm.prank(admin);
        vm.expectEmit(address(randomnessSender));
        emit RandomnessSender.RandomnessCallbackFailed(requestId);
        signatureSender.fulfillSignatureRequest(requestId, validSignature);

        // fetch request information from randomness sender
        randomnessRequest = randomnessSender.getRequest(requestId);

        uint256 requestIdFromConsumer = mockRandomnessReceiver.requestId();

        assertFalse(signatureSender.isInFlight(requestIdFromConsumer));
        assertEq(mockRandomnessReceiver.randomness(), 0x0);
    }
}

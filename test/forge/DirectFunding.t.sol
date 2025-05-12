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

contract DirectFundingTest is RandomnessTest {
    function test_FulfillSignature_DirectFunding_Request_Successfully() public {
        uint256 contractFundBuffer = 1 ether;

        mockRandomnessReceiver =
            deployAndFundReceiverWithDirectFunding(admin, address(randomnessSender), contractFundBuffer);
        assertEq(mockRandomnessReceiver.randomness(), 0x0);

        uint256 nonce = 1;
        uint64 requestId = 1;

        TypesLib.RandomnessRequestCreationParams memory r =
            TypesLib.RandomnessRequestCreationParams({nonce: nonce, callback: address(mockRandomnessReceiver)});
        bytes memory m = randomnessSender.messageFrom(r);
        console.logBytes(m);

        // get request price
        uint32 callbackGasLimit = 500_000;
        uint256 requestPrice = randomnessSender.calculateRequestPriceNative(callbackGasLimit);

        uint256 aliceBalance = alice.balance;

        vm.prank(alice);
        mockRandomnessReceiver.fundContractNative{value: requestPrice}();

        assertTrue(
            mockRandomnessReceiver.getBalance() == requestPrice + contractFundBuffer,
            "Incorrect ether balance for randomness receiver contract"
        );
        assertTrue(alice.balance == (aliceBalance - requestPrice), "Alice balance not debited");
        assertTrue(requestPrice > 0, "Invalid request price");
        console.log("Estimated request price", requestPrice);

        // create randomness request
        vm.expectEmit(true, true, false, true);
        emit RandomnessSender.RandomnessRequested(requestId, nonce, address(mockRandomnessReceiver), block.timestamp);
        mockRandomnessReceiver.rollDiceWithDirectFunding(callbackGasLimit);

        uint64 requestIdFromConsumer = mockRandomnessReceiver.requestId();

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
}

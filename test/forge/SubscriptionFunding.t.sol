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

contract SubscriptionFundingTest is RandomnessTest {
    address[] public consumersToAddToSubscription;

    function test_FulfillSignatureRequest_WithSubscription_Successfully() public {
        // create subscription and fund it
        assert(mockRandomnessReceiver.subscriptionId() == 0);

        uint256 contractFundBuffer = 3 ether;

        mockRandomnessReceiver =
            deployAndFundReceiverWithSubscription(alice, address(randomnessSender), contractFundBuffer);

        uint256 subId = mockRandomnessReceiver.subscriptionId();
        assert(subId != 0);
        console.log("Subscription id = ", subId);

        (uint96 nativeBalance, uint64 reqCount, address subOwner, address[] memory consumers) =
            randomnessSender.getSubscription(subId);
        assertEq(nativeBalance, contractFundBuffer);
        assertEq(reqCount, 0);
        assertEq(subOwner, address(mockRandomnessReceiver));
        assertEq(consumers.length, 1);

        // get request price
        uint32 callbackGasLimit = 100_000;
        uint256 requestPrice = randomnessSender.calculateRequestPriceNative(callbackGasLimit);
        assertTrue(requestPrice > 0, "Invalid request price");

        vm.prank(alice);
        uint256 requestId = mockRandomnessReceiver.rollDiceWithSubscription(callbackGasLimit);

        // fetch request information from randomness sender
        TypesLib.RandomnessRequest memory randomnessRequest = randomnessSender.getRequest(requestId);
        assertTrue(randomnessRequest.subId != 0, "Subscription funding request id should not be zero");
        assertTrue(
            randomnessRequest.directFundingFeePaid == 0,
            "User contract should not be charged immediately for subscription request"
        );

        vm.txGasPrice(100_000);
        uint256 gasBefore = gasleft();

        vm.prank(admin);
        signatureSender.fulfillSignatureRequest(requestId, validSignature);

        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;
        console.log("Request CallbackGasLimit:", randomnessRequest.callbackGasLimit);
        console.log("Request CallbackGasPrice:", randomnessRequest.directFundingFeePaid);
        console.log("Tx Gas used:", gasUsed);
        console.log("Tx Gas price (wei):", tx.gasprice);
        console.log("Tx Total cost (wei):", gasUsed * tx.gasprice);

        assertFalse(signatureSender.isInFlight(requestId));
        assertEq(mockRandomnessReceiver.randomness(), keccak256(validSignature));

        assert(!signatureSender.isInFlight(requestId));
        assert(signatureSender.getCountOfUnfulfilledRequestIds() == 0);
        assert(signatureSender.getAllErroredRequestIds().length == 0);
        assert(signatureSender.getAllFulfilledRequestIds().length == 1);

        assertTrue(
            !signatureSender.hasErrored(requestId),
            "Payment collection in callback to receiver contract should not fail"
        );

        TypesLib.SignatureRequest memory signatureRequest = signatureSender.getRequest(requestId);
        assertTrue(signatureRequest.isFulfilled, "Signature not provided in signature sender by offchain oracle");

        // check for fee deductions from subscription account
        // subId should be charged at this point, and request count for subId should be increased
        (nativeBalance, reqCount,,) = randomnessSender.getSubscription(subId);

        uint256 totalSubBalanceBeforeRequest = contractFundBuffer;
        uint256 exactFeePaid = totalSubBalanceBeforeRequest - nativeBalance;

        console.log("Subscription native balance after request = ", nativeBalance);
        console.log("Subscription fee charged for request = ", exactFeePaid);
        /// @notice check that the exactFeePaid is covered by estimated price and not higher than estimated price derived from
        /// calling randomnessSender.calculateRequestPriceNative(callbackGasLimit);
        console.log(totalSubBalanceBeforeRequest, nativeBalance, exactFeePaid);
        assertTrue(requestPrice >= exactFeePaid, "Request price estimation should cover exact fee charged for request");
        assertTrue(
            totalSubBalanceBeforeRequest == exactFeePaid + nativeBalance, "subId should be charged at this point"
        );

        assertTrue(gasUsed * tx.gasprice < exactFeePaid, "subId should be charged for overhead");
        assertTrue(reqCount == 1, "Incorrect request count, it should be one");

        signatureRequest = signatureSender.getRequest(requestId);
        assertTrue(signatureRequest.isFulfilled, "Signature not provided in signature sender by offchain oracle");
        assertTrue(
            mockRandomnessReceiver.randomness() == keccak256(validSignature), "Randomness value mismatch after callback"
        );
        assertTrue(mockRandomnessReceiver.requestId() == 1, "Request id in receiver contract is incorrect");

        assertTrue(
            randomnessSender.s_withdrawableDirectFundingFeeNative() == 0,
            "We don't expect any direct funding payments from this subscription request"
        );

        assertTrue(
            randomnessSender.s_withdrawableSubscriptionFeeNative() == exactFeePaid,
            "Request price paid should be withdrawable by admin at this point"
        );

        vm.prank(admin);
        uint256 adminBalance = admin.balance;
        randomnessSender.withdrawSubscriptionFeesNative(payable(admin));
        assertTrue(admin.balance + exactFeePaid > adminBalance, "Admin balance should be higher after withdrawing fees");

        assert(randomnessSender.s_totalNativeBalance() == nativeBalance);
    }

    function test_NoChargeAtRequestTime_ForSubscriptionRequest() public {
        // create subscription and fund it
        assert(mockRandomnessReceiver.subscriptionId() == 0);

        uint256 contractFundBuffer = 3 ether;

        mockRandomnessReceiver =
            deployAndFundReceiverWithSubscription(alice, address(randomnessSender), contractFundBuffer);

        uint256 subId = mockRandomnessReceiver.subscriptionId();
        assert(subId != 0);
        console.log("Subscription id = ", subId);

        (uint96 nativeBalance, uint64 reqCount, address subOwner, address[] memory consumers) =
            randomnessSender.getSubscription(subId);
        assertEq(nativeBalance, contractFundBuffer);
        assertEq(reqCount, 0);
        assertEq(subOwner, address(mockRandomnessReceiver));
        assertEq(consumers.length, 1);

        // get request price
        uint32 callbackGasLimit = 100_000;
        uint256 requestPrice = randomnessSender.calculateRequestPriceNative(callbackGasLimit);
        assertTrue(requestPrice > 0, "Invalid request price");

        vm.prank(alice);
        uint256 requestId = mockRandomnessReceiver.rollDiceWithSubscription(callbackGasLimit);

        // fetch request information from randomness sender
        TypesLib.RandomnessRequest memory randomnessRequest = randomnessSender.getRequest(requestId);
        assertTrue(randomnessRequest.subId != 0, "Subscription funding request id should not be zero");
        assertTrue(
            randomnessRequest.directFundingFeePaid == 0,
            "User contract should not be charged immediately for subscription request"
        );

        (nativeBalance, reqCount,,) = randomnessSender.getSubscription(subId);
        assertEq(nativeBalance, contractFundBuffer);
        assertEq(reqCount, 0);
    }

    function test_FulfillSignatureRequest_WithSubscription_AndLowCallbackGasLimit() public {
        // create subscription and fund it
        assert(mockRandomnessReceiver.subscriptionId() == 0);

        uint256 contractFundBuffer = 3 ether;

        mockRandomnessReceiver =
            deployAndFundReceiverWithSubscription(alice, address(randomnessSender), contractFundBuffer);

        uint256 subId = mockRandomnessReceiver.subscriptionId();
        assert(subId != 0);
        console.log("Subscription id = ", subId);

        (uint96 nativeBalance, uint64 reqCount, address subOwner, address[] memory consumers) =
            randomnessSender.getSubscription(subId);
        assertEq(nativeBalance, contractFundBuffer);
        assertEq(reqCount, 0);
        assertEq(subOwner, address(mockRandomnessReceiver));
        assertEq(consumers.length, 1);

        // get request price
        uint32 callbackGasLimit = 1000;
        uint256 requestPrice = randomnessSender.calculateRequestPriceNative(callbackGasLimit);
        assertTrue(requestPrice > 0, "Invalid request price");

        vm.prank(alice);
        uint256 requestId = mockRandomnessReceiver.rollDiceWithSubscription(callbackGasLimit);

        // fetch request information from randomness sender
        TypesLib.RandomnessRequest memory randomnessRequest = randomnessSender.getRequest(requestId);
        assertTrue(randomnessRequest.subId != 0, "Subscription funding request id should not be zero");
        assertTrue(
            randomnessRequest.directFundingFeePaid == 0,
            "User contract should not be charged immediately for subscription request"
        );

        vm.txGasPrice(100_000);
        uint256 gasBefore = gasleft();

        vm.prank(admin);
        signatureSender.fulfillSignatureRequest(requestId, validSignature);

        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;
        console.log("Request CallbackGasLimit:", randomnessRequest.callbackGasLimit);
        console.log("Request CallbackGasPrice:", randomnessRequest.directFundingFeePaid);
        console.log("Tx Gas used:", gasUsed);
        console.log("Tx Gas price (wei):", tx.gasprice);
        console.log("Tx Total cost (wei):", gasUsed * tx.gasprice);

        assertFalse(signatureSender.isInFlight(requestId));

        assert(!signatureSender.isInFlight(requestId));
        assert(signatureSender.getCountOfUnfulfilledRequestIds() == 0);
        assert(signatureSender.getAllErroredRequestIds().length == 0);
        assert(signatureSender.getAllFulfilledRequestIds().length == 1);

        assertTrue(
            !signatureSender.hasErrored(requestId),
            "Payment collection in callback to receiver contract should not fail"
        );

        TypesLib.SignatureRequest memory signatureRequest = signatureSender.getRequest(requestId);
        assertTrue(signatureRequest.isFulfilled, "Signature not provided in signature sender by offchain oracle");

        // check for fee deductions from subscription account
        // subId should be charged at this point, and request count for subId should be increased
        (nativeBalance, reqCount,,) = randomnessSender.getSubscription(subId);

        uint256 totalSubBalanceBeforeRequest = contractFundBuffer;
        uint256 exactFeePaid = totalSubBalanceBeforeRequest - nativeBalance;

        console.log("Subscription native balance after request = ", nativeBalance);
        console.log("Subscription fee charged for request = ", exactFeePaid);
        /// @notice check that the exactFeePaid is covered by estimated price and not higher than estimated price derived from
        /// calling randomnessSender.calculateRequestPriceNative(callbackGasLimit);
        console.log(totalSubBalanceBeforeRequest, nativeBalance, exactFeePaid);
        assertTrue(requestPrice >= exactFeePaid, "Request price estimation should cover exact fee charged for request");
        assertTrue(
            totalSubBalanceBeforeRequest == exactFeePaid + nativeBalance, "subId should be charged at this point"
        );

        assertTrue(gasUsed * tx.gasprice < exactFeePaid, "subId should be charged for overhead");
        assertTrue(reqCount == 1, "Incorrect request count, it should be one");

        signatureRequest = signatureSender.getRequest(requestId);
        assertTrue(signatureRequest.isFulfilled, "Signature not provided in signature sender by offchain oracle");
        assertTrue(mockRandomnessReceiver.randomness() != keccak256(validSignature), "Callback should fail");
        assertTrue(mockRandomnessReceiver.requestId() == 1, "Request id in receiver contract is incorrect");

        assertTrue(
            randomnessSender.s_withdrawableDirectFundingFeeNative() == 0,
            "We don't expect any direct funding payments from this subscription request"
        );

        assertTrue(
            randomnessSender.s_withdrawableSubscriptionFeeNative() == exactFeePaid,
            "Request price paid should be withdrawable by admin at this point"
        );

        vm.prank(admin);
        uint256 adminBalance = admin.balance;
        randomnessSender.withdrawSubscriptionFeesNative(payable(admin));
        assertTrue(admin.balance + exactFeePaid > adminBalance, "Admin balance should be higher after withdrawing fees");

        assert(randomnessSender.s_totalNativeBalance() == nativeBalance);
    }

    /// @notice If user specifies zero callbackGasLimit, they are still charged for gas overhead which is added
    /// to cover for sending of keys and decryption
    function test_FulfillSignatureRequest_WithZeroCallbackGasLimit() public {
        // create subscription and fund it
        assert(mockRandomnessReceiver.subscriptionId() == 0);

        uint256 contractFundBuffer = 3 ether;

        mockRandomnessReceiver =
            deployAndFundReceiverWithSubscription(alice, address(randomnessSender), contractFundBuffer);

        uint256 subId = mockRandomnessReceiver.subscriptionId();
        assert(subId != 0);
        console.log("Subscription id = ", subId);

        (uint96 nativeBalance, uint64 reqCount, address subOwner, address[] memory consumers) =
            randomnessSender.getSubscription(subId);
        assertEq(nativeBalance, contractFundBuffer);
        assertEq(reqCount, 0);
        assertEq(subOwner, address(mockRandomnessReceiver));
        assertEq(consumers.length, 1);

        // get request price
        uint32 callbackGasLimit = 0;
        uint256 requestPrice = randomnessSender.calculateRequestPriceNative(callbackGasLimit);
        assertTrue(requestPrice > 0, "Invalid request price");

        vm.prank(alice);
        uint256 requestId = mockRandomnessReceiver.rollDiceWithSubscription(callbackGasLimit);

        // fetch request information from randomness sender
        TypesLib.RandomnessRequest memory randomnessRequest = randomnessSender.getRequest(requestId);
        assertTrue(randomnessRequest.subId != 0, "Subscription funding request id should not be zero");
        assertTrue(
            randomnessRequest.directFundingFeePaid == 0,
            "User contract should not be charged immediately for subscription request"
        );

        vm.txGasPrice(100_000);
        uint256 gasBefore = gasleft();

        vm.prank(admin);
        signatureSender.fulfillSignatureRequest(requestId, validSignature);

        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;
        console.log("Request CallbackGasLimit:", randomnessRequest.callbackGasLimit);
        console.log("Request CallbackGasPrice:", randomnessRequest.directFundingFeePaid);
        console.log("Tx Gas used:", gasUsed);
        console.log("Tx Gas price (wei):", tx.gasprice);
        console.log("Tx Total cost (wei):", gasUsed * tx.gasprice);

        assertFalse(signatureSender.isInFlight(requestId));

        assert(!signatureSender.isInFlight(requestId));
        assert(signatureSender.getCountOfUnfulfilledRequestIds() == 0);
        assert(signatureSender.getAllErroredRequestIds().length == 0);
        assert(signatureSender.getAllFulfilledRequestIds().length == 1);

        assertTrue(
            !signatureSender.hasErrored(requestId),
            "Payment collection in callback to receiver contract should not fail"
        );

        TypesLib.SignatureRequest memory signatureRequest = signatureSender.getRequest(requestId);
        assertTrue(signatureRequest.isFulfilled, "Signature not provided in signature sender by offchain oracle");

        // check for fee deductions from subscription account
        // subId should be charged at this point, and request count for subId should be increased
        (nativeBalance, reqCount,,) = randomnessSender.getSubscription(subId);

        uint256 totalSubBalanceBeforeRequest = contractFundBuffer;
        uint256 exactFeePaid = totalSubBalanceBeforeRequest - nativeBalance;

        console.log("Subscription native balance after request = ", nativeBalance);
        console.log("Subscription fee charged for request = ", exactFeePaid);
        /// @notice check that the exactFeePaid is covered by estimated price and not higher than estimated price derived from
        /// calling randomnessSender.calculateRequestPriceNative(callbackGasLimit);
        console.log(totalSubBalanceBeforeRequest, nativeBalance, exactFeePaid);
        assertTrue(requestPrice >= exactFeePaid, "Request price estimation should cover exact fee charged for request");
        assertTrue(
            totalSubBalanceBeforeRequest == exactFeePaid + nativeBalance, "subId should be charged at this point"
        );

        assertTrue(gasUsed * tx.gasprice < exactFeePaid, "subId should be charged for overhead");
        assertTrue(reqCount == 1, "Incorrect request count, it should be one");

        signatureRequest = signatureSender.getRequest(requestId);
        assertTrue(signatureRequest.isFulfilled, "Signature not provided in signature sender by offchain oracle");
        assertTrue(mockRandomnessReceiver.randomness() != keccak256(validSignature), "Callback should fail");
        assertTrue(mockRandomnessReceiver.requestId() == 1, "Request id in receiver contract is incorrect");

        assertTrue(
            randomnessSender.s_withdrawableDirectFundingFeeNative() == 0,
            "We don't expect any direct funding payments from this subscription request"
        );

        assertTrue(
            randomnessSender.s_withdrawableSubscriptionFeeNative() == exactFeePaid,
            "Request price paid should be withdrawable by admin at this point"
        );

        vm.prank(admin);
        uint256 adminBalance = admin.balance;
        randomnessSender.withdrawSubscriptionFeesNative(payable(admin));
        assertTrue(admin.balance + exactFeePaid > adminBalance, "Admin balance should be higher after withdrawing fees");

        assert(randomnessSender.s_totalNativeBalance() == nativeBalance);
    }

    function test_FulfillSignatureRequest_ForSubscription_WithOnlyRequestPriceBalance() public {
        // create subscription and fund it
        assert(mockRandomnessReceiver.subscriptionId() == 0);

        // get request price
        uint32 callbackGasLimit = 100_000;
        uint256 requestPrice = randomnessSender.calculateRequestPriceNative(callbackGasLimit);
        assertTrue(requestPrice > 0, "Invalid request price");

        mockRandomnessReceiver = deployAndFundReceiverWithSubscription(alice, address(randomnessSender), requestPrice);

        vm.prank(alice);
        uint256 requestId = mockRandomnessReceiver.rollDiceWithSubscription(callbackGasLimit);

        // fetch request information from randomness sender
        TypesLib.RandomnessRequest memory randomnessRequest = randomnessSender.getRequest(requestId);
        assertTrue(randomnessRequest.subId != 0, "Subscription funding request id should not be zero");
        assertTrue(
            randomnessRequest.directFundingFeePaid == 0,
            "User contract should not be charged immediately for subscription request"
        );

        vm.txGasPrice(100_000);
        uint256 gasBefore = gasleft();

        vm.prank(admin);
        signatureSender.fulfillSignatureRequest(requestId, validSignature);

        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;
        console.log("Request CallbackGasLimit:", randomnessRequest.callbackGasLimit);
        console.log("Request CallbackGasPrice:", randomnessRequest.directFundingFeePaid);
        console.log("Tx Gas used:", gasUsed);
        console.log("Tx Gas price (wei):", tx.gasprice);
        console.log("Tx Total cost (wei):", gasUsed * tx.gasprice);

        assertFalse(signatureSender.isInFlight(requestId));
        assertEq(mockRandomnessReceiver.randomness(), keccak256(validSignature));

        assert(!signatureSender.isInFlight(requestId));
        assert(signatureSender.getCountOfUnfulfilledRequestIds() == 0);
        assert(signatureSender.getAllErroredRequestIds().length == 0);
        assert(signatureSender.getAllFulfilledRequestIds().length == 1);

        assertTrue(
            !signatureSender.hasErrored(requestId),
            "Payment collection in callback to receiver contract should not fail"
        );

        TypesLib.SignatureRequest memory signatureRequest = signatureSender.getRequest(requestId);
        assertTrue(signatureRequest.isFulfilled, "Signature not provided in signature sender by offchain oracle");

        // check for fee deductions from subscription account
        // subId should be charged at this point, and request count for subId should be increased
        (uint96 nativeBalance,,,) = randomnessSender.getSubscription(randomnessRequest.subId);

        uint256 totalSubBalanceBeforeRequest = requestPrice;
        uint256 exactFeePaid = totalSubBalanceBeforeRequest - nativeBalance;

        console.log("Subscription native balance after request = ", nativeBalance);
        console.log("Subscription fee charged for request = ", exactFeePaid);
        /// @notice check that the exactFeePaid is covered by estimated price and not higher than estimated price derived from
        /// calling randomnessSender.calculateRequestPriceNative(callbackGasLimit);
        console.log(totalSubBalanceBeforeRequest, nativeBalance, exactFeePaid);
        assertTrue(requestPrice >= exactFeePaid, "Request price estimation should cover exact fee charged for request");
        assertTrue(
            totalSubBalanceBeforeRequest == exactFeePaid + nativeBalance, "subId should be charged at this point"
        );

        assertTrue(gasUsed * tx.gasprice < exactFeePaid, "subId should be charged for overhead");

        signatureRequest = signatureSender.getRequest(requestId);
        assertTrue(signatureRequest.isFulfilled, "Signature not provided in signature sender by offchain oracle");
        assertTrue(
            mockRandomnessReceiver.randomness() == keccak256(validSignature), "Randomness value mismatch after callback"
        );
        assertTrue(mockRandomnessReceiver.requestId() == 1, "Request id in receiver contract is incorrect");

        assertTrue(
            randomnessSender.s_withdrawableDirectFundingFeeNative() == 0,
            "We don't expect any direct funding payments from this subscription request"
        );

        assertTrue(
            randomnessSender.s_withdrawableSubscriptionFeeNative() == exactFeePaid,
            "Request price paid should be withdrawable by admin at this point"
        );

        vm.prank(admin);
        uint256 adminBalance = admin.balance;
        randomnessSender.withdrawSubscriptionFeesNative(payable(admin));
        assertTrue(admin.balance + exactFeePaid > adminBalance, "Admin balance should be higher after withdrawing fees");

        assert(randomnessSender.s_totalNativeBalance() == nativeBalance);
    }

    function test_CancelSubscription() public {
        mockRandomnessReceiver = deployAndFundReceiverWithSubscription(alice, address(randomnessSender), 5 ether);

        uint256 aliceBalancePreCancellation = alice.balance;

        vm.prank(alice);
        mockRandomnessReceiver.cancelSubscription(alice);

        uint256 aliceBalancePostCancellation = alice.balance;

        assertTrue(
            aliceBalancePostCancellation > aliceBalancePreCancellation,
            "Balance did not increase after subscription cancellation"
        );
    }

    function test_CancelSubscription_WithPendingRequest_ShouldRevert() public {
        // create subscription and fund it
        assert(mockRandomnessReceiver.subscriptionId() == 0);

        vm.prank(alice);
        mockRandomnessReceiver.createSubscriptionAndFundNative{value: 5 ether}();

        uint256 totalSubBalanceBeforeRequest = 5 ether;

        // get request price
        uint32 callbackGasLimit = 0;
        uint256 requestPrice = randomnessSender.calculateRequestPriceNative(callbackGasLimit);
        console.log("Request price for offchain oracle callbackGasLimit", requestPrice);

        // make blocklock request
        vm.prank(alice);
        uint32 requestCallbackGasLimit = callbackGasLimit;
        uint256 requestId = mockRandomnessReceiver.rollDiceWithSubscription(requestCallbackGasLimit);

        // fetch request information from blocklock sender
        TypesLib.RandomnessRequest memory randomnessRequest = randomnessSender.getRequest(requestId);

        assertTrue(
            randomnessRequest.callbackGasLimit == requestCallbackGasLimit,
            "Stored callbackGasLimit does not match callbacGasLimit from user request"
        );

        assertTrue(randomnessRequest.subId != 0, "Subscription funding request id should not be zero");
        assertTrue(
            randomnessRequest.directFundingFeePaid == 0,
            "User contract should not be charged immediately for subscription request"
        );
        assertTrue(
            randomnessRequest.requestId == requestId, "Request id mismatch between randomnessSender and signatureSender"
        );

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("PendingRequestExists()"));
        mockRandomnessReceiver.cancelSubscription(alice);

        assertTrue(randomnessSender.s_totalNativeBalance() == totalSubBalanceBeforeRequest, "User not charged");
    }

    function test_FulfillSignatureRequest_ForSubscriptionWithZeroBalance_ShouldRevert() public {
        // create subscription and fund it
        assert(mockRandomnessReceiver.subscriptionId() == 0);

        uint256 contractFundBuffer = 0;

        mockRandomnessReceiver =
            deployAndFundReceiverWithSubscription(alice, address(randomnessSender), contractFundBuffer);

        uint256 subId = mockRandomnessReceiver.subscriptionId();
        assert(subId != 0);
        console.log("Subscription id = ", subId);

        (uint96 nativeBalance, uint64 reqCount, address subOwner, address[] memory consumers) =
            randomnessSender.getSubscription(subId);
        assertEq(nativeBalance, contractFundBuffer);
        assertEq(reqCount, 0);
        assertEq(subOwner, address(mockRandomnessReceiver));
        assertEq(consumers.length, 1);

        // get request price
        uint32 callbackGasLimit = 100_000;
        uint256 requestPrice = randomnessSender.calculateRequestPriceNative(callbackGasLimit);
        assertTrue(requestPrice > 0, "Invalid request price");

        vm.prank(alice);
        uint256 requestId = mockRandomnessReceiver.rollDiceWithSubscription(callbackGasLimit);

        // fetch request information from randomness sender
        TypesLib.RandomnessRequest memory randomnessRequest = randomnessSender.getRequest(requestId);
        assertTrue(randomnessRequest.subId != 0, "Subscription funding request id should not be zero");
        assertTrue(
            randomnessRequest.directFundingFeePaid == 0,
            "User contract should not be charged immediately for subscription request"
        );

        vm.txGasPrice(100_000);
        uint256 gasBefore = gasleft();

        vm.prank(admin);
        signatureSender.fulfillSignatureRequest(requestId, validSignature);

        uint256 gasAfter = gasleft();
        uint256 gasUsed = gasBefore - gasAfter;
        console.log("Request CallbackGasLimit:", randomnessRequest.callbackGasLimit);
        console.log("Request CallbackGasPrice:", randomnessRequest.directFundingFeePaid);
        console.log("Tx Gas used:", gasUsed);
        console.log("Tx Gas price (wei):", tx.gasprice);
        console.log("Tx Total cost (wei):", gasUsed * tx.gasprice);

        assertTrue(signatureSender.isInFlight(requestId));

        assert(signatureSender.isInFlight(requestId));
        assert(signatureSender.getCountOfUnfulfilledRequestIds() == 0);
        assert(signatureSender.getAllErroredRequestIds().length == 1);
        assert(signatureSender.getAllFulfilledRequestIds().length == 0);

        assertTrue(
            signatureSender.hasErrored(requestId), "Payment collection in callback to receiver contract should fail"
        );

        TypesLib.SignatureRequest memory signatureRequest = signatureSender.getRequest(requestId);
        assertTrue(signatureRequest.isFulfilled, "There should have been an attempt to fulfill the request");

        // check for fee deductions from subscription account
        // subId should be charged at this point, and request count for subId should be increased
        (nativeBalance, reqCount,,) = randomnessSender.getSubscription(subId);

        uint256 totalSubBalanceBeforeRequest = contractFundBuffer;
        uint256 exactFeePaid = totalSubBalanceBeforeRequest - nativeBalance;

        console.log("Subscription native balance after request = ", nativeBalance);
        console.log("Subscription fee charged for request = ", exactFeePaid);
        /// @notice check that the exactFeePaid is covered by estimated price and not higher than estimated price derived from
        /// calling randomnessSender.calculateRequestPriceNative(callbackGasLimit);
        console.log(totalSubBalanceBeforeRequest, nativeBalance, exactFeePaid);
        assertTrue(requestPrice >= exactFeePaid, "Request price estimation should cover exact fee charged for request");
        assertTrue(
            totalSubBalanceBeforeRequest == exactFeePaid + nativeBalance, "subId should be charged at this point"
        );

        // subscription and native balance should be zero
        assert(totalSubBalanceBeforeRequest == 0 && exactFeePaid == 0 && nativeBalance == 0);

        assertTrue(gasUsed * tx.gasprice > exactFeePaid, "subId cannot be charged for gas overhead");
        assertTrue(reqCount == 0, "Incorrect request count, it should be zero post fulfill tx");

        signatureRequest = signatureSender.getRequest(requestId);
        assertTrue(signatureRequest.isFulfilled, "Signature not provided in signature sender by offchain oracle");
        assertTrue(
            mockRandomnessReceiver.randomness() != keccak256(validSignature),
            "Randomness value should not be sent to callback with failed payment"
        );
        assertTrue(mockRandomnessReceiver.requestId() == 1, "Request id in receiver contract is incorrect");

        assertTrue(
            randomnessSender.s_withdrawableDirectFundingFeeNative() == 0,
            "We don't expect any direct funding payments from this subscription request"
        );

        assertTrue(
            randomnessSender.s_withdrawableSubscriptionFeeNative() == 0,
            "There should be zero request price to withdraw by admin at this point"
        );

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("InsufficientBalance()"));
        uint256 adminBalance = admin.balance;
        randomnessSender.withdrawDirectFundingFeesNative(payable(admin));
        assertTrue(admin.balance == adminBalance, "Admin balance should not change without withdrawing fees");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Test, console} from "forge-std-1.10.0/Test.sol";

import {
    Deployment,
    SignatureSchemeAddressProvider,
    RandomnessSender,
    SignatureSender,
    BN254SignatureScheme,
    BLS12381SignatureScheme,
    BLS12381CompressedSignatureScheme
} from "./base/Deployment.t.sol";

import {ChainlinkVRFSubscriptionConsumer} from
    "../../src/chainlink_compatible/mocks/ChainlinkVRFSubscriptionConsumer.sol";

import {ChainlinkVRFCoordinatorV2_5Adapter} from "../../src/chainlink_compatible/ChainlinkVRFCoordinatorV2_5Adapter.sol";

/// @title Chainlink VRF v2.5 Integration Test with Subscriptions
/// @author
/// @notice This test verifies the correct integration between a Chainlink-compatible VRF wrapper and subscription-based randomness requests.
/// @dev Inherits from Deployment and uses Foundry's `Test` utilities.
contract ChainlinkVRFV2_5Integration_SubscriptionTest is Deployment {
    SignatureSchemeAddressProvider internal signatureSchemeAddressProvider;
    BN254SignatureScheme internal bn254SignatureScheme;
    BLS12381SignatureScheme internal bls12381SignatureScheme;
    BLS12381CompressedSignatureScheme internal bls12381CompressedSignatureScheme;
    SignatureSender internal signatureSender;
    RandomnessSender internal randomnessSender;

    /// @notice Sets up the deployment contracts before each test
    function setUp() public override {
        super.setUp();

        (
            signatureSchemeAddressProvider,
            bn254SignatureScheme,
            bls12381SignatureScheme,
            bls12381CompressedSignatureScheme,
            randomnessSender,
            signatureSender
        ) = deployContracts();
    }

    /// @notice Tests that a randomness request via a Chainlink-compatible subscription is fulfilled correctly
    /// @dev Deploys and configures the consumer and wrapper contracts, creates a subscription, and validates the full request/response cycle
    function test_chainlinkFulfillSignatureRequest_WithSubscription_Successfully() public {
        // Verify randomness sender is deployed
        assertTrue(address(randomnessSender) != address(0), "RandomnessSender is not deployed");

        // Deploy wrapper adapter
        address owner = admin;
        address _randomnessSender = address(randomnessSender);

        uint32 _s_wrapperGasOverhead = 100_000;

        ChainlinkVRFCoordinatorV2_5Adapter wrapper = new ChainlinkVRFCoordinatorV2_5Adapter(owner, _randomnessSender);

        vm.prank(owner);
        vm.expectEmit(address(wrapper));
        emit ChainlinkVRFCoordinatorV2_5Adapter.WrapperGasOverheadUpdated(_s_wrapperGasOverhead);
        wrapper.setWrapperGasOverhead(_s_wrapperGasOverhead);

        // Deploy consumer contract as alice
        vm.prank(alice);
        ChainlinkVRFSubscriptionConsumer consumer = new ChainlinkVRFSubscriptionConsumer(0, address(wrapper));

        // Create subscription
        uint256 subId = consumer.createSubscription();

        // Calculate funding amounts
        uint32 callbackGasLimit = 400_000;
        uint256 requestPrice = wrapper.calculateRequestPriceNative(callbackGasLimit, 1);
        uint256 subscriptionFundBuffer = 1 ether;

        // Fund the subscription
        consumer.fundSubscriptionWithNative{value: requestPrice + subscriptionFundBuffer}(subId);

        // Add a new consumer to the subscription
        vm.prank(alice);
        consumer.addConsumer(subId, makeAddr("new-consumer"));

        // Validate subscription data
        (, uint96 nativeBalance,, address _owner, address[] memory consumers) = wrapper.getSubscription(subId);

        assertTrue(_owner == address(wrapper), "Subscription owner in RandomnessSender should be wrapper contract");
        assertTrue(consumers.length == 2, "There should be 2 consumers, wrapper contract and added consumer");
        assertTrue(nativeBalance == requestPrice + subscriptionFundBuffer, "Subscription native balance is incorrect");

        // Initial requestId state check
        assertTrue(consumer.requestId() == 0, "requestId should be zero post deployment");

        // Request randomness
        uint256 requestId = 1;
        uint256 nonce = 1;
        vm.prank(alice); // from contract owner
        vm.expectEmit(true, true, false, true);
        emit RandomnessSender.RandomnessRequested(requestId, nonce, address(wrapper), block.timestamp);
        consumer.requestRandomWords(callbackGasLimit);

        // Check request ID and pre-fulfillment state
        assertTrue(consumer.requestId() == requestId, "requestId should be updated after request");
        assertTrue(
            consumer.getRandomWords(requestId).length == 0,
            "randomness array for requestId should be empty before request is fulfilled"
        );

        // Fulfill the request using the signature sender
        vm.txGasPrice(100_000);
        signatureSender.fulfillSignatureRequest(requestId, validSignature);

        // Validate no direct funding fee was taken
        assertTrue(
            randomnessSender.s_withdrawableDirectFundingFeeNative() == 0,
            "No direct funding fee should be collected for subscription"
        );

        // Check subscription fee is collected
        assertTrue(
            randomnessSender.s_withdrawableSubscriptionFeeNative() > 0
                && randomnessSender.s_withdrawableSubscriptionFeeNative() <= requestPrice,
            "Subscription fee should be non-zero and not exceed request price"
        );

        // Validate response randomness
        assertTrue(
            consumer.getRandomWords(requestId).length == 1, "Randomness array should be populated after fulfillment"
        );
        assertTrue(consumer.getRandomWords(requestId)[0] != 0, "Randomness value should not be zero");

        console.log("received randomness", consumer.getRandomWords(requestId)[0]);
    }

    /// @notice Tests successful subscription ownership transfer flow
    function test_subscriptionOwnershipTransfer_successful() public {
        // Deploy wrapper adapter
        ChainlinkVRFCoordinatorV2_5Adapter wrapper = new ChainlinkVRFCoordinatorV2_5Adapter(admin, address(randomnessSender));

        // Create subscription as alice
        vm.prank(alice);
        uint256 subId = wrapper.createSubscription();

        // Verify initial state
        assertTrue(wrapper.getPendingSubscriptionOwner(subId) == address(0), "No pending owner initially");
        
        // Request ownership transfer to bob
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit ChainlinkVRFCoordinatorV2_5Adapter.SubscriptionOwnerTransferRequested(subId, alice, bob);
        wrapper.requestSubscriptionOwnerTransfer(subId, bob);

        // Verify pending state
        assertTrue(wrapper.getPendingSubscriptionOwner(subId) == bob, "Bob should be pending owner");

        // Accept ownership transfer as bob
        vm.prank(bob);
        vm.expectEmit(true, false, false, true);
        emit ChainlinkVRFCoordinatorV2_5Adapter.SubscriptionOwnerTransferred(subId, alice, bob);
        wrapper.acceptSubscriptionOwnerTransfer(subId);

        // Verify ownership transfer completed
        assertTrue(wrapper.getPendingSubscriptionOwner(subId) == address(0), "No pending owner after transfer");

        // Verify bob can now manage the subscription
        vm.prank(bob);
        wrapper.addConsumer(subId, makeAddr("new-consumer"));

        // Verify alice can no longer manage the subscription
        vm.prank(alice);
        vm.expectRevert("Caller is not subscription owner");
        wrapper.addConsumer(subId, makeAddr("another-consumer"));
    }

    /// @notice Tests that non-owner cannot request ownership transfer
    function test_subscriptionOwnershipTransfer_onlyOwnerCanRequest() public {
        ChainlinkVRFCoordinatorV2_5Adapter wrapper = new ChainlinkVRFCoordinatorV2_5Adapter(admin, address(randomnessSender));

        vm.prank(alice);
        uint256 subId = wrapper.createSubscription();

        // Try to request transfer as non-owner (bob)
        vm.prank(bob);
        vm.expectRevert("Caller is not subscription owner");
        wrapper.requestSubscriptionOwnerTransfer(subId, bob);
    }

    /// @notice Tests that only pending owner can accept transfer
    function test_subscriptionOwnershipTransfer_onlyPendingOwnerCanAccept() public {
        ChainlinkVRFCoordinatorV2_5Adapter wrapper = new ChainlinkVRFCoordinatorV2_5Adapter(admin, address(randomnessSender));

        vm.prank(alice);
        uint256 subId = wrapper.createSubscription();

        // Request transfer to bob
        vm.prank(alice);
        wrapper.requestSubscriptionOwnerTransfer(subId, bob);

        // Try to accept as charlie (not the pending owner)
        vm.prank(charlie);
        vm.expectRevert("Caller is not the pending owner");
        wrapper.acceptSubscriptionOwnerTransfer(subId);

        // Try to accept as alice (current owner, not pending owner)
        vm.prank(alice);
        vm.expectRevert("Caller is not the pending owner");
        wrapper.acceptSubscriptionOwnerTransfer(subId);
    }

    /// @notice Tests that accepting transfer without pending transfer fails
    function test_subscriptionOwnershipTransfer_noPendingTransfer() public {
        ChainlinkVRFCoordinatorV2_5Adapter wrapper = new ChainlinkVRFCoordinatorV2_5Adapter(admin, address(randomnessSender));

        vm.prank(alice);
        uint256 subId = wrapper.createSubscription();

        // Try to accept transfer without requesting it first
        vm.prank(bob);
        vm.expectRevert("No pending ownership transfer");
        wrapper.acceptSubscriptionOwnerTransfer(subId);
    }

    /// @notice Tests that requesting transfer to zero address fails
    function test_subscriptionOwnershipTransfer_zeroAddressRevert() public {
        ChainlinkVRFCoordinatorV2_5Adapter wrapper = new ChainlinkVRFCoordinatorV2_5Adapter(admin, address(randomnessSender));

        vm.prank(alice);
        uint256 subId = wrapper.createSubscription();

        // Try to request transfer to zero address
        vm.prank(alice);
        vm.expectRevert("New owner cannot be zero address");
        wrapper.requestSubscriptionOwnerTransfer(subId, address(0));
    }

    /// @notice Tests that requesting transfer to same owner fails
    function test_subscriptionOwnershipTransfer_sameOwnerRevert() public {
        ChainlinkVRFCoordinatorV2_5Adapter wrapper = new ChainlinkVRFCoordinatorV2_5Adapter(admin, address(randomnessSender));

        vm.prank(alice);
        uint256 subId = wrapper.createSubscription();

        // Try to request transfer to same owner
        vm.prank(alice);
        vm.expectRevert("New owner is the same as current owner");
        wrapper.requestSubscriptionOwnerTransfer(subId, alice);
    }

    /// @notice Tests that pending transfer is cleared when subscription is cancelled
    function test_subscriptionOwnershipTransfer_clearedOnCancellation() public {
        ChainlinkVRFCoordinatorV2_5Adapter wrapper = new ChainlinkVRFCoordinatorV2_5Adapter(admin, address(randomnessSender));

        vm.prank(alice);
        uint256 subId = wrapper.createSubscription();

        // Fund subscription
        vm.prank(alice);
        wrapper.fundSubscriptionWithNative{value: 1 ether}(subId);

        // Request ownership transfer
        vm.prank(alice);
        wrapper.requestSubscriptionOwnerTransfer(subId, bob);

        // Verify pending transfer exists
        assertTrue(wrapper.getPendingSubscriptionOwner(subId) == bob, "Bob should be pending owner");

        // Cancel subscription
        uint96 preBalance = uint96(alice.balance);
        (, uint96 subBalance,,,) = wrapper.getSubscription(subId);
        vm.prank(alice);
        wrapper.cancelSubscription(subId, alice);

        // Check that alice received the subscription balance
        assertTrue(uint96(alice.balance) >= preBalance + subBalance, "Alice should receive the subscription balance");

        // Verify pending transfer is cleared
        assertTrue(wrapper.getPendingSubscriptionOwner(subId) == address(0), "Pending owner should be cleared");
    }

    /// @notice Tests that adapter remains owner in underlying SubscriptionAPI after transfer
    function test_subscriptionOwnershipTransfer_adapterRemainsUnderlyingOwner() public {
        ChainlinkVRFCoordinatorV2_5Adapter wrapper = new ChainlinkVRFCoordinatorV2_5Adapter(admin, address(randomnessSender));

        vm.prank(alice);
        uint256 subId = wrapper.createSubscription();

        // Transfer ownership to bob
        vm.prank(alice);
        wrapper.requestSubscriptionOwnerTransfer(subId, bob);

        vm.prank(bob);
        wrapper.acceptSubscriptionOwnerTransfer(subId);

        // Verify that the wrapper is still the owner in the underlying SubscriptionAPI
        (,, address underlyingOwner,) = randomnessSender.getSubscription(subId);
        assertTrue(underlyingOwner == address(wrapper), "Wrapper should remain the owner in underlying SubscriptionAPI");

        // Verify that bob can manage the subscription through the wrapper
        vm.prank(bob);
        wrapper.addConsumer(subId, makeAddr("new-consumer"));

        // Verify management functions work (no revert)
        vm.prank(bob);
        wrapper.removeConsumer(subId, makeAddr("new-consumer"));
    }

    /// @notice Tests that multiple ownership transfers can be requested (overwriting pending)
    function test_subscriptionOwnershipTransfer_overwritePending() public {
        ChainlinkVRFCoordinatorV2_5Adapter wrapper = new ChainlinkVRFCoordinatorV2_5Adapter(admin, address(randomnessSender));

        vm.prank(alice);
        uint256 subId = wrapper.createSubscription();

        // Request transfer to bob
        vm.prank(alice);
        wrapper.requestSubscriptionOwnerTransfer(subId, bob);
        assertTrue(wrapper.getPendingSubscriptionOwner(subId) == bob, "Bob should be pending owner");

        // Request transfer to charlie (should overwrite)
        vm.prank(alice);
        wrapper.requestSubscriptionOwnerTransfer(subId, charlie);
        assertTrue(wrapper.getPendingSubscriptionOwner(subId) == charlie, "Charlie should be pending owner");

        // Bob can no longer accept (since pending was overwritten)
        vm.prank(bob);
        vm.expectRevert("Caller is not the pending owner");
        wrapper.acceptSubscriptionOwnerTransfer(subId);

        // Charlie can accept
        vm.prank(charlie);
        wrapper.acceptSubscriptionOwnerTransfer(subId);
    }
}

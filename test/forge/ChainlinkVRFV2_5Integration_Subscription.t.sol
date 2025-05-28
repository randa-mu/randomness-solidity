// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";

import {
    Deployment,
    SignatureSchemeAddressProvider,
    RandomnessSender,
    SignatureSender,
    BN254SignatureScheme
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
    SignatureSender internal signatureSender;
    RandomnessSender internal randomnessSender;

    /// @notice Sets up the deployment contracts before each test
    function setUp() public override {
        super.setUp();

        (signatureSchemeAddressProvider, bn254SignatureScheme, randomnessSender, signatureSender) = deployContracts();
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
}

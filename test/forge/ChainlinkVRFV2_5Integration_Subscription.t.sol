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

contract ChainlinkVRFV2_5Integration_SubscriptionTest is Deployment {
    SignatureSchemeAddressProvider internal signatureSchemeAddressProvider;
    BN254SignatureScheme internal bn254SignatureScheme;
    SignatureSender internal signatureSender;
    RandomnessSender internal randomnessSender;

    function setUp() public override {
        // setup base test
        super.setUp();

        (signatureSchemeAddressProvider, bn254SignatureScheme, randomnessSender, signatureSender) = deployContracts();
    }

    function test_chainlinkFulfillSignatureRequest_WithSubscription_Successfully() public {
        // check deployed randomness sender
        assertTrue(address(randomnessSender) != address(0), "RandomnessSender is not deployed");

        // deploy chainlink direct funding consumer wrapper
        address owner = admin;
        address _randomnessSender = address(randomnessSender);
        uint32 _s_wrapperGasOverhead = 100_000;

        ChainlinkVRFCoordinatorV2_5Adapter wrapper =
            new ChainlinkVRFCoordinatorV2_5Adapter(owner, _randomnessSender, _s_wrapperGasOverhead);
        // deploy chainlink subscription consumer
        vm.prank(alice);
        ChainlinkVRFSubscriptionConsumer consumer = new ChainlinkVRFSubscriptionConsumer(0, address(wrapper));

        // create subscription and save subscription id in consumer contract for future requests
        uint256 subId = consumer.createSubscription();

        // get request price
        uint32 callbackGasLimit = 400_000;
        uint256 requestPrice = wrapper.calculateRequestPriceNative(callbackGasLimit, 1);
        uint256 subscriptionFundBuffer = 1 ether;

        // fund subscription
        consumer.fundSubscriptionWithNative{value: requestPrice + subscriptionFundBuffer}(subId);

        // test add consumer from consumer contract
        vm.prank(alice);
        consumer.addConsumer(subId, makeAddr("new-consumer"));

        // check subscription
        (, uint96 nativeBalance,, address _owner, address[] memory consumers) = wrapper.getSubscription(subId);

        assertTrue(_owner == address(wrapper), "Subscription owner in RandomnessSender should be wrapper contract");
        assertTrue(consumers.length == 2, "There should be 2 consumers, wrapper contract and added consumer");
        assertTrue(nativeBalance == requestPrice + subscriptionFundBuffer, "Subscription native balance is incorrect");

        // make randomness request
        assertTrue(consumer.requestId() == 0, "requestId should be zero post deployment");

        uint256 requestId = 1;
        uint256 nonce = 1;
        vm.prank(alice); // owner
        vm.expectEmit(true, true, false, true);
        emit RandomnessSender.RandomnessRequested(requestId, nonce, address(wrapper), block.timestamp);
        consumer.requestRandomWords(callbackGasLimit);

        assertTrue(consumer.requestId() == requestId, "requestId should be zero post deployment");
        assertTrue(
            (consumer.getRandomWords(requestId)).length == 0,
            "randomness array for requestId should empty before request is fulfilled"
        );

        // fulfill randomness request
        vm.txGasPrice(100_000);
        signatureSender.fulfillSignatureRequest(requestId, validSignature);

        assertTrue(
            randomnessSender.s_withdrawableDirectFundingFeeNative() == 0,
            "There should be no one time or direct funding payment collected for this subscription funded request"
        );

        assertTrue(
            randomnessSender.s_withdrawableSubscriptionFeeNative() > 0
                && randomnessSender.s_withdrawableSubscriptionFeeNative() <= requestPrice,
            "Request price paid should be greater than zero and withdrawable by admin at this point"
        );
        assertTrue(
            (consumer.getRandomWords(requestId)).length == 1,
            "randomness array for requestId should not empty after request is fulfilled"
        );
        assertTrue((consumer.getRandomWords(requestId))[0] != 0, "randomness should not be zero");
        console.log("received randomness", (consumer.getRandomWords(requestId))[0]);
    }
}

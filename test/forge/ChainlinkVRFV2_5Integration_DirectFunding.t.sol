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

import {ChainlinkVRFDirectFundingConsumer} from
    "../../src/chainlink_compatible/mocks/ChainlinkVRFDirectFundingConsumer.sol";

import {ChainlinkVRFV2PlusWrapperAdapter} from "../../src/chainlink_compatible/ChainlinkVRFV2PlusWrapperAdapter.sol";

/// @title Chainlink VRF v2.5 Direct Funding Integration Test
/// @notice This test verifies direct funding flow with a Chainlink-compatible wrapper using randomness signatures
/// @dev Inherits setup from base Deployment and uses Foundry's testing utilities
contract ChainlinkVRFV2_5Integration_DirectFundingTest is Deployment {
    SignatureSchemeAddressProvider internal signatureSchemeAddressProvider;
    BN254SignatureScheme internal bn254SignatureScheme;
    SignatureSender internal signatureSender;
    RandomnessSender internal randomnessSender;

    /// @notice Deploys base contracts and VRF infrastructure before each test
    function setUp() public override {
        super.setUp();

        (signatureSchemeAddressProvider, bn254SignatureScheme, randomnessSender, signatureSender) = deployContracts();
    }

    /// @notice Tests a direct funding randomness request using the Chainlink-compatible wrapper
    /// @dev Funds the consumer directly with native token and verifies request/fulfillment pipeline
    function test_chainlinkFulfillSignatureRequest_WithDirectFunding_Successfully() public {
        // Ensure randomness sender is deployed
        assertTrue(address(randomnessSender) != address(0), "RandomnessSender is not deployed");

        // Deploy VRF wrapper
        address owner = admin;
        address _randomnessSender = address(randomnessSender);

        uint32 _s_wrapperGasOverhead = 100_000;

        ChainlinkVRFV2PlusWrapperAdapter wrapper = new ChainlinkVRFV2PlusWrapperAdapter(owner, _randomnessSender);

        vm.prank(owner);
        vm.expectEmit(address(wrapper));
        emit ChainlinkVRFV2PlusWrapperAdapter.WrapperGasOverheadUpdated(_s_wrapperGasOverhead);
        wrapper.setWrapperGasOverhead(_s_wrapperGasOverhead);

        // Deploy the direct funding consumer
        ChainlinkVRFDirectFundingConsumer consumer = new ChainlinkVRFDirectFundingConsumer(address(wrapper));

        // Determine request price
        uint32 callbackGasLimit = 400_000;
        uint256 requestPrice = wrapper.calculateRequestPriceNative(callbackGasLimit, 1);

        // Fund the consumer contract with native tokens
        consumer.fundContractNative{value: requestPrice + 1 ether}();

        // Check initial request ID
        assertTrue(consumer.requestId() == 0, "requestId should be zero post deployment");

        // Submit randomness request
        uint256 requestId = 1;
        uint256 nonce = 1;
        vm.expectEmit(true, true, false, true);
        emit RandomnessSender.RandomnessRequested(requestId, nonce, address(wrapper), block.timestamp);
        consumer.requestRandomWords(callbackGasLimit, true);

        // Verify request state before fulfillment
        assertTrue(consumer.requestId() == requestId, "requestId should match submitted one");
        assertTrue(
            consumer.getRandomWords(requestId).length == 0,
            "randomness array for requestId should be empty before request is fulfilled"
        );

        // Fulfill the randomness request
        vm.txGasPrice(100_000);
        signatureSender.fulfillSignatureRequest(requestId, validSignature);

        // Confirm that request fee is correctly handled as a direct funding withdrawal
        assertTrue(
            randomnessSender.s_withdrawableDirectFundingFeeNative() == requestPrice,
            "Request price paid should be withdrawable by admin at this point"
        );

        // Ensure no subscription-based deductions were made
        assertTrue(
            randomnessSender.s_withdrawableSubscriptionFeeNative() == 0,
            "There should be no subscription balance deduction for this direct funding request"
        );

        // Validate received randomness
        assertTrue(
            consumer.getRandomWords(requestId).length == 1,
            "randomness array for requestId should be populated after fulfillment"
        );
        assertTrue(consumer.getRandomWords(requestId)[0] != 0, "randomness should not be zero");

        console.log("received randomness", consumer.getRandomWords(requestId)[0]);
    }
}

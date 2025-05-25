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
import {ChainlinkVRFSubscriptionConsumer} from
    "../../src/chainlink_compatible/mocks/ChainlinkVRFSubscriptionConsumer.sol";

import {ChainlinkVRFV2PlusWrapperAdapter} from "../../src/chainlink_compatible/ChainlinkVRFV2PlusWrapperAdapter.sol";
import {ChainlinkVRFCoordinatorV2_5Adapter} from "../../src/chainlink_compatible/ChainlinkVRFCoordinatorV2_5Adapter.sol";

contract ChainlinkVRFV2_5Integration_DirectFundingTest is Deployment {
    SignatureSchemeAddressProvider internal signatureSchemeAddressProvider;
    BN254SignatureScheme internal bn254SignatureScheme;
    SignatureSender internal signatureSender;
    RandomnessSender internal randomnessSender;

    function setUp() public override {
        // setup base test
        super.setUp();

        (signatureSchemeAddressProvider, bn254SignatureScheme, randomnessSender, signatureSender) = deployContracts();
    }

    function test_chainlinkFulfillSignatureRequest_WithDirectFunding_Successfully() public {
        // check deployed randomness sender
        assertTrue(address(randomnessSender) != address(0), "RandomnessSender is not deployed");

        // deploy chainlink direct funding consumer wrapper
        address owner = admin;
        address _randomnessSender = address(randomnessSender);
        uint32 _s_wrapperGasOverhead = 100_000;

        ChainlinkVRFV2PlusWrapperAdapter wrapper =
            new ChainlinkVRFV2PlusWrapperAdapter(owner, _randomnessSender, _s_wrapperGasOverhead);
        // deploy chainlink direct funding consumer
        ChainlinkVRFDirectFundingConsumer consumer = new ChainlinkVRFDirectFundingConsumer(address(wrapper));

        // get request price
        uint32 callbackGasLimit = 400_000;
        uint256 requestPrice = wrapper.calculateRequestPriceNative(callbackGasLimit, 1);

        // fund consumer contract
        vm.prank(alice);
        consumer.fundContractNative{value: requestPrice + 1 ether}();

        // make randomness request
        assertTrue(consumer.requestId() == 0, "requestId should be zero post deployment");
        consumer.requestRandomWords(callbackGasLimit, true);
        // fulfill randomness request
    }
}

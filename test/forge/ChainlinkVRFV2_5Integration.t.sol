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

import {ChainlinkVRFDirectFundingConsumer} from
    "../../src/chainlink_compatible/mocks/ChainlinkVRFDirectFundingConsumer.sol";
import {ChainlinkVRFSubscriptionConsumer} from
    "../../src/chainlink_compatible/mocks/ChainlinkVRFSubscriptionConsumer.sol";

import {ChainlinkVRFV2PlusWrapperAdapter} from "../../src/chainlink_compatible/ChainlinkVRFV2PlusWrapperAdapter.sol";
import {ChainlinkVRFCoordinatorV2_5Adapter} from "../../src/chainlink_compatible/ChainlinkVRFCoordinatorV2_5Adapter.sol";

contract ChainlinkVRFV2_5IntegrationTest is RandomnessTest {}

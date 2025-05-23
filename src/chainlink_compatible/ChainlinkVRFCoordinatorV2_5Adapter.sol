// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "../RandomnessReceiverBase.sol";
import "./internal/ChainlinkVRFCoordinatorV2_5Stub.sol";

contract ChainlinkVRFCoordinatorV2_5Adapter is ChainlinkVRFCoordinatorV2_5Stub, RandomnessReceiverBase {}

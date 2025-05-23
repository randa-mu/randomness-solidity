// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

// import "../RandomnessReceiverBase.sol";
import {IRandomnessReceiver} from "../interfaces/IRandomnessReceiver.sol";
import {IRandomnessSender} from "../interfaces/IRandomnessSender.sol";

import "./internal/ChainlinkVRFV2PlusWrapperStub.sol";

contract ChainlinkVRFV2PlusWrapperAdapter is ChainlinkVRFV2PlusWrapperStub, IRandomnessReceiver {}

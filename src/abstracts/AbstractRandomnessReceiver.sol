// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IRandomnessReceiver} from "../interfaces/IRandomnessReceiver.sol";

abstract contract AbstractRandomnessReceiver {
    address public immutable RANDOMNESS_PROVIDER = 0x9c789bc7F2B5c6619Be1572A39F2C3d6f33001dC;

    error NotAuthorizedRandomnessProvider();

    modifier onlyRandomnessProvider(){
        if (msg.sender != RANDOMNESS_PROVIDER) revert NotAuthorizedRandomnessProvider();
        _;
    }
}
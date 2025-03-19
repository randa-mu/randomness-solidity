// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {IRandomnessReceiver} from "./interfaces/IRandomnessReceiver.sol";
import {IRandomnessSender} from "./interfaces/IRandomnessSender.sol";

abstract contract RandomnessReceiverBase is IRandomnessReceiver {
    IRandomnessSender public immutable randomnessSender;

    modifier onlyRandomnessSender() {
        require(msg.sender == address(randomnessSender), "Only randomnessSender can call");
        _;
    }

    constructor(address _randomnessSender) {
        require(_randomnessSender != address(0), "Cannot set zero address as randomness sender");
        randomnessSender = IRandomnessSender(_randomnessSender);
    }

    /**
     * @dev See {IRandomnessSender-requestRandomness}.
     */
    function requestRandomness() internal returns (uint256 requestID) {
        requestID = randomnessSender.requestRandomness();
    }

    /**
     * @dev See {IRandomnessReceiver-receiveRandomness}.
     */
    function receiveRandomness(uint256 requestID, bytes32 randomness) external onlyRandomnessSender {
        onRandomnessReceived(requestID, randomness);
    }

    /**
     * @notice Handles the reception of a generated random value for a specific request.
     * @dev This internal function is called when randomness is received for the given `requestID`.
     * It is intended to be overridden by derived contracts to implement custom behavior.
     * @param requestID The unique identifier of the randomness request.
     * @param randomness The generated random value, provided as a `bytes32` type.
     */
    function onRandomnessReceived(uint256 requestID, bytes32 randomness) internal virtual;
}

/// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {IRandomnessReceiver} from "./interfaces/IRandomnessReceiver.sol";
import {IRandomnessSender} from "./interfaces/IRandomnessSender.sol";

/// @title RandomnessReceiverBase contract
/// @author Randamu
/// @notice Abstract contract to facilitate receiving randomness from an external source.
/// @dev This contract ensures that only a designated randomness sender can provide randomness values.
abstract contract RandomnessReceiverBase is IRandomnessReceiver {
    /// @notice The contract responsible for providing randomness.
    /// @dev This is an immutable reference set at deployment.
    IRandomnessSender public immutable randomnessSender;

    /// @notice Ensures that only the designated randomness sender can call the function.
    modifier onlyRandomnessSender() {
        require(msg.sender == address(randomnessSender), "Only randomnessSender can call");
        _;
    }

    /// @notice Initializes the contract with a specified randomness sender.
    /// @dev Ensures that the provided sender address is non-zero.
    /// @param _randomnessSender The address of the randomness sender contract.
    constructor(address _randomnessSender) {
        require(_randomnessSender != address(0), "Cannot set zero address as randomness sender");
        randomnessSender = IRandomnessSender(_randomnessSender);
    }

    /// @notice Requests randomness from the designated randomness sender.
    /// @dev Calls the `requestRandomness` function on the randomness sender contract.
    /// @return requestID The unique identifier of the randomness request.
    function requestRandomness() internal returns (uint256 requestID) {
        requestID = randomnessSender.requestRandomness();
    }

    /// @notice Receives randomness for a specific request ID from the designated sender.
    /// @dev This function is restricted to calls from the designated randomness sender.
    /// @param requestID The unique identifier of the randomness request.
    /// @param randomness The generated random value as a `bytes32` type.
    function receiveRandomness(uint256 requestID, bytes32 randomness) external onlyRandomnessSender {
        onRandomnessReceived(requestID, randomness);
    }

    /// @notice Handles the reception of a generated random value for a specific request.
    /// @dev This internal function is intended to be overridden by derived contracts to implement custom behavior.
    /// @param requestID The unique identifier of the randomness request.
    /// @param randomness The generated random value, provided as a `bytes32` type.
    function onRandomnessReceived(uint256 requestID, bytes32 randomness) internal virtual;
}

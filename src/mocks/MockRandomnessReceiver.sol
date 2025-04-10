/// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {RandomnessReceiverBase} from "../RandomnessReceiverBase.sol";

/// @title MockRandomnessReceiver contract
/// @author Randamu
/// @notice A contract that requests and consumes randomness
contract MockRandomnessReceiver is RandomnessReceiverBase {
    /// @notice Stores the latest received randomness value
    bytes32 public randomness;

    /// @notice Stores the request ID of the latest randomness request
    uint256 public requestId;

    /// @notice Initializes the contract with the address of the randomness sender
    /// @param randomnessSender The address of the randomness provider
    constructor(address randomnessSender) RandomnessReceiverBase(randomnessSender) {}

    /// @notice Requests randomness from the oracle
    /// @dev Calls `requestRandomness` to get a random value, updating `requestId` with the request ID
    function rollDice() external {
        requestId = requestRandomness();
    }

    /// @notice Callback function that processes received randomness
    /// @dev Ensures the received request ID matches the stored one before updating state
    /// @param requestID The ID of the randomness request
    /// @param _randomness The random value received from the oracle
    function onRandomnessReceived(uint256 requestID, bytes32 _randomness) internal override {
        require(requestId == requestID, "Request ID mismatch");
        randomness = _randomness;
    }
}

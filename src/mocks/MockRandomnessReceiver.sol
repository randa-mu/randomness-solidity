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
    constructor(address randomnessSender, address owner) RandomnessReceiverBase(randomnessSender, owner) {}

    /// @notice Requests randomness using the direct funding option
    /// @dev Calls `_requestRandomnessPayInNative` to get a random value, updating `requestId` with the request ID
    function rollDiceWithDirectFunding(uint32 callbackGasLimit) external payable returns (uint256, uint256) {
        // create randomness request
        (uint256 requestID, uint256 requestPrice) = _requestRandomnessPayInNative(callbackGasLimit);
        // store request id
        requestId = requestID;
        return (requestID, requestPrice);
    }

    /// @notice Requests randomness using the subscription option
    /// @dev Calls `_requestRandomnessWithSubscription` to get a random value, updating `requestId` with the request ID
    function rollDiceWithSubscription(uint32 callbackGasLimit) external returns (uint256) {
        // create randomness request
        uint256 requestID = _requestRandomnessWithSubscription(callbackGasLimit);
        // store request id
        requestId = requestID;
        return requestID;
    }

    function cancelSubscription(address to) external onlyOwner {
        _cancelSubscription(to);
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

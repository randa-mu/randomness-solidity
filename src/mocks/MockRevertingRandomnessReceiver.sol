/// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {RandomnessReceiverBase} from "../RandomnessReceiverBase.sol";

/// @title MockRevertingRandomnessReceiver contract
/// @author Randamu
/// @notice A contract that requests and consumes randomness
contract MockRevertingRandomnessReceiver is RandomnessReceiverBase {
    /// @notice Stores the latest received randomness value
    bytes32 public randomness;

    /// @notice Stores the request ID of the latest randomness request
    uint256 public requestId;

    /// @notice Initializes the contract with the address of the randomness sender
    /// @param randomnessSender The address of the randomness provider
    constructor(address randomnessSender, address owner) RandomnessReceiverBase(randomnessSender, owner) {}

    /// @notice Requests randomness from the oracle
    /// @dev Calls `_requestRandomnessPayInNative` to get a random value, updating `requestId` with the request ID using the direct funding option.
    function rollDiceWithDirectFunding(uint32 callbackGasLimit) external payable returns (uint256, uint256) {
        // create randomness request
        (uint256 requestID, uint256 requestPrice) = _requestRandomnessPayInNative(callbackGasLimit);
        // store request id
        requestId = requestID;
        return (requestID, requestPrice);
    }

    /// @notice Requests randomness from the oracle
    /// @dev Calls `_requestRandomnessWithSubscription` to get a random value, updating `requestId` with the request ID using the subscription option.
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
    function onRandomnessReceived(uint256, /*requestID*/ bytes32 /*randomness*/ ) internal pure override {
        revert();
    }
}

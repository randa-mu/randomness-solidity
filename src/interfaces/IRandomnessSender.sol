// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "../libraries/TypesLib.sol";

import {ISubscription} from "./ISubscription.sol";

/// @title IRandomnessSender interface
/// @author Randamu
/// @notice Interface for randomness sender contract which sends randomness via callbacks to randomness consumer contracts.
interface IRandomnessSender is ISubscription {
    /// @notice Requests the generation of a random value.
    /// @dev Initiates a randomness request.
    /// The generated randomness will be associated with the returned `requestID`.
    /// @param callbackGasLimit How much gas you'd like to receive in your
    /// receiveBlocklock callback. Note that gasleft() inside receiveBlocklock
    /// may be slightly less than this amount because of gas used calling the function
    /// (argument decoding etc.), so you may need to request slightly more than you expect
    /// to have inside receiveBlocklock. The acceptable range is
    /// [0, maxGasLimit]
    /// @return requestID The unique identifier assigned to this randomness request.
    function requestRandomness(uint32 callbackGasLimit) external payable returns (uint256 requestID);

    /// @notice Requests the generation of a random value.
    /// @dev Initiates a randomness request.
    /// The generated randomness will be associated with the returned `requestID`.
    /// @param callbackGasLimit How much gas you'd like to receive in your
    /// receiveBlocklock callback. Note that gasleft() inside receiveBlocklock
    /// may be slightly less than this amount because of gas used calling the function
    /// (argument decoding etc.), so you may need to request slightly more than you expect
    /// to have inside receiveBlocklock. The acceptable range is
    /// [0, maxGasLimit]
    /// @param subId The subscription ID associated with the request
    /// @return requestID The unique identifier assigned to this randomness request.
    function requestRandomnessWithSubscription(uint32 callbackGasLimit, uint256 subId)
        external
        payable
        returns (uint256 requestID);

    /// @notice Calculates the estimated price in native tokens for a request based on the provided gas limit
    /// @param _callbackGasLimit The gas limit for the callback execution
    /// @return The estimated request price in native token (e.g., ETH)
    function calculateRequestPriceNative(uint32 _callbackGasLimit) external view returns (uint256);

    /// @notice Estimates the request price in native tokens using a specified gas price
    /// @param _callbackGasLimit The gas limit for the callback execution
    /// @param _requestGasPriceWei The gas price (in wei) to use for the estimation
    /// @return The estimated total request price in native token (e.g., ETH)
    function estimateRequestPriceNative(uint32 _callbackGasLimit, uint256 _requestGasPriceWei)
        external
        view
        returns (uint256);

    /// @notice Retrieves a specific request by its ID.
    /// @dev This function returns the Request struct associated with the given requestId.
    /// @param requestId The ID of the request to retrieve.
    /// @return The Request struct corresponding to the given requestId.
    function getRequest(uint256 requestId) external view returns (TypesLib.RandomnessRequest memory);

    /// @notice Sets signatureSender contract address.
    /// @param newSignatureSender The new address to set.
    function setSignatureSender(address newSignatureSender) external;

    /// @notice Retrieves all requests.
    /// @dev This function returns an array of all Request structs stored in the contract.
    /// @return An array containing all the Request structs.
    function getAllRequests() external view returns (TypesLib.RandomnessRequest[] memory);

    /// @notice Generates a message from the given request.
    /// @dev Creates a hash-based message using the `DST` and `nonce` fields of the `Request` struct.
    /// The resulting message is the hash of the encoded values, packed into a byte array.
    /// @param r The `Request` struct containing the data for generating the message.
    /// @return A byte array representing the hashed and encoded message.
    function messageFrom(TypesLib.RandomnessRequestCreationParams memory r) external pure returns (bytes memory);

    function isInFlight(uint256 requestId) external view returns (bool);

    function getConfig()
        external
        view
        returns (
            uint32 maxGasLimit,
            uint32 gasAfterPaymentCalculation,
            uint32 fulfillmentFlatFeeNativePPM,
            uint32 weiPerUnitGas,
            uint32 blsPairingCheckOverhead,
            uint8 nativePremiumPercentage,
            uint32 gasForCallExactCheck
        );
}

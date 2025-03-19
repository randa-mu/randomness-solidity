// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "../libraries/TypesLib.sol";

// todo subscription and payments
// todo we could embed the following for subscription and payments - subscriptionID, numberOfRequestTxConfirmations, callbackGasLimit, numRandomValues
// todo check for potential gaps in using uint256 as id compared to bytes32
interface IRandomnessSender {
    /**
     * @notice Requests the generation of a random value for a specified blockchain height.
     * @dev Initiates a randomness request.
     * The generated randomness will be associated with the returned `requestID`.
     * @return requestID The unique identifier assigned to this randomness request.
     */
    function requestRandomness() external returns (uint256 requestID);
    /**
     * @notice Retrieves a specific request by its ID.
     * @dev This function returns the Request struct associated with the given requestId.
     * @param requestId The ID of the request to retrieve.
     * @return The Request struct corresponding to the given requestId.
     */
    function getRequest(uint256 requestId) external view returns (TypesLib.RandomnessRequest memory);

    /**
     * @notice Sets signatureSender contract address.
     * @param newSignatureSender The new address to set.
     */
    function setSignatureSender(address newSignatureSender) external;

    /**
     * @notice Retrieves all requests.
     * @dev This function returns an array of all Request structs stored in the contract.
     * @return An array containing all the Request structs.
     */
    function getAllRequests() external view returns (TypesLib.RandomnessRequest[] memory);
    /**
     * @notice Generates a message from the given request.
     * @dev Creates a hash-based message using the `DST` and `nonce` fields of the `Request` struct.
     * The resulting message is the hash of the encoded values, packed into a byte array.
     * @param r The `Request` struct containing the data for generating the message.
     * @return A byte array representing the hashed and encoded message.
     */
    function messageFrom(TypesLib.RandomnessRequest memory r) external pure returns (bytes memory);
}

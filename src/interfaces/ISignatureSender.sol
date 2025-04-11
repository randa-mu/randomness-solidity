/// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "../libraries/TypesLib.sol";

/// @title ISignatureSender interface
/// @author Randamu
/// @notice Enables signature requests and callbacks
interface ISignatureSender {
    /// @notice Requests a digital signature for a given message using a specified signature scheme.
    /// @dev Initiates a request for signing the provided `message` under the specified `schemeID`.
    /// @param schemeID The identifier of the signature scheme to be used.
    /// @param message The message to be signed, provided as a byte array.
    /// @param condition Conditions that must be satisfied for the signature request, provided as a byte array.
    /// @return The unique request ID assigned to this signature request.
    function requestSignature(string calldata schemeID, bytes calldata message, bytes calldata condition)
        external
        returns (uint256);

    /// @notice Fulfills a signature request by providing the corresponding signature.
    /// @dev Completes the signing process for the request identified by `requestID`.
    /// @param requestID The unique identifier of the signature request being fulfilled.
    /// @param signature The generated signature, provided as a byte array.
    function fulfilSignatureRequest(uint256 requestID, bytes calldata signature) external;

    /// @notice Retries a request that previously failed during callback.
    /// @dev This function is called if a signature was generated off-chain but failed to call back into the contract.
    /// @param requestID The unique identifier for the signature request.
    function retryCallback(uint256 requestID) external;

    /// @notice Updates the signature scheme address provider contract address.
    /// @param newSignatureSchemeAddressProvider The signature address provider address to set.
    function setSignatureSchemeAddressProvider(address newSignatureSchemeAddressProvider) external;

    /// @notice Checks if a signature request is still in flight.
    /// @dev Determines whether the specified `requestID` is still pending.
    /// @param requestID The unique identifier of the signature request.
    /// @return True if the request is still in flight, otherwise false.
    function isInFlight(uint256 requestID) external view returns (bool);

    /// @notice Returns request data.
    /// @param requestID The unique identifier of the signature request.
    /// @return The corresponding SignatureRequest struct for the request ID.
    function getRequest(uint256 requestID) external view returns (TypesLib.SignatureRequest memory);

    /// @notice Returns whether a specific request errored during callback or not.
    /// @param requestID The ID of the request to check.
    /// @return Boolean indicating whether the request has errored or not.
    function hasErrored(uint256 requestID) external view returns (bool);

    /// @notice Retrieves the public key associated with the signature process.
    /// @dev Returns the public key as two elliptic curve points.
    /// @return Two pairs of coordinates representing the public key points on the elliptic curve.
    function getPublicKey() external view returns (uint256[2] memory, uint256[2] memory);

    /// @notice Retrieves the public key associated with the signature process.
    /// @dev Returns the public key as bytes.
    /// @return Bytes string representing the public key points on the elliptic curve.
    function getPublicKeyBytes() external view returns (bytes memory);

    /// @notice Returns all the fulfilled request IDs.
    /// @return A uint array representing a set containing all fulfilled request IDs.
    function getAllFulfilledRequestIds() external view returns (uint256[] memory);

    /// @notice Returns all the request IDs that are yet to be fulfilled.
    /// @return A uint array representing a set containing all request IDs that are yet to be fulfilled.
    function getAllUnfulfilledRequestIds() external view returns (uint256[] memory);

    /// @notice Returns all the request IDs where the callback reverted but a decryption key was provided.
    /// @return A uint array representing a set containing all request IDs with reverting callbacks.
    function getAllErroredRequestIds() external view returns (uint256[] memory);

    /// @notice Returns count of all the request IDs that are yet to be fulfilled.
    /// @return A uint representing a count of all request IDs that are yet to be fulfilled.
    function getCountOfUnfulfilledRequestIds() external view returns (uint256);

    /// @notice Returns the version number of the upgradeable contract.
    function version() external pure returns (string memory);
}

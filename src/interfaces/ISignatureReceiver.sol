// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

/// @title ISignatureReceiver interface
/// @author Randamu
/// @notice Interface for contracts receiving signatures via callbacks.
interface ISignatureReceiver {
    /// @notice Receives a signature for a specified request.
    /// @dev This function is intended to be called to provide a signature for the given `requestID`.
    /// @param requestID The unique identifier of the request associated with the signature.
    /// @param signature The cryptographic signature of the message, provided as a byte array.
    function receiveSignature(uint256 requestID, bytes calldata signature) external;
}

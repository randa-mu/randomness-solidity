/// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {ISignatureReceiver} from "../interfaces/ISignatureReceiver.sol";
import {ISignatureSender} from "../interfaces/ISignatureSender.sol";

/// @title SignatureReceiverBase contract
/// @author Randamu
/// @notice Abstract contract for handling signature reception and forwarding signature requests.
/// @dev Implements ISignatureReceiver and provides utilities for requesting and receiving signatures.
abstract contract SignatureReceiverBase is ISignatureReceiver {
    /// @notice The contract that manages signature requests.
    ISignatureSender public signatureSender;

    /// @notice Ensures that only the designated signature sender can invoke the function.
    modifier onlySignatureSender() {
        require(msg.sender == address(signatureSender), "Only signatureSender can call");
        _;
    }

    /// @notice Initiates a signature request for a given message under a specified signature scheme.
    /// @dev Calls the `requestSignature` function of the `signatureSender` contract, passing the provided parameters.
    /// @param schemeID The identifier of the signature scheme to be used for signing the message.
    /// @param message The message to be signed, provided as a byte array.
    /// @param condition Additional conditions that must be satisfied for the signature request, provided as a byte array.
    /// @return requestID The unique identifier assigned to the initiated signature request.
    function _requestSignature(string memory schemeID, bytes memory message, bytes memory condition)
        internal
        returns (uint256)
    {
        return signatureSender.requestSignature(schemeID, message, condition);
    }

    /// @notice Receives a signature for a previously requested message.
    /// @dev Implements {ISignatureReceiver-receiveSignature}. Ensures only the signature sender can call this function.
    /// @param requestID The unique identifier of the signature request.
    /// @param signature The cryptographic signature of the message, provided as a byte array.
    function receiveSignature(uint256 requestID, bytes calldata signature) external onlySignatureSender {
        onSignatureReceived(requestID, signature);
    }

    /// @notice Handles the reception of a digital signature for a specified request.
    /// @dev This internal function is called when a signature is received for the given `requestID`.
    /// It is intended to be overridden by derived contracts to implement custom behavior upon receipt of a signature.
    /// @param requestID The unique identifier of the signature request associated with the received signature.
    /// @param signature The cryptographic signature of the message, provided as a byte array.
    function onSignatureReceived(uint256 requestID, bytes calldata signature) internal virtual;
}

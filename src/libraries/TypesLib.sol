// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "./BLS.sol";

/// @title TypesLib
/// @author Randamu
/// @notice Library declaring custom data types used for randomness and blocklock requests
library TypesLib {
    /// @notice Signature request struct for signature request type
    struct SignatureRequest {
        bytes message; // plaintext message to hash and sign
        bytes messageHash; // hashed message to sign
        bytes condition; // optional condition, length can be zero for immediate message signing
        string schemeID; // signature scheme id, e.g., "BN254", "BLS12-381", "TESS"
        address callback; // the requester address to call back. Must implement ISignatureReceiver interface to support the required callback
        bytes signature;
        bool isFulfilled;
    }

    /// @notice  Randomness request stores details needed to verify the signature
    struct RandomnessRequest {
        uint256 subId; // must be 0 for direct funding
        uint256 directFundingFeePaid; // must be > 0 for direct funding and if subId == 0
        uint32 callbackGasLimit; // must be between 0 and maxGasLimit
        uint256 requestId;
        bytes message;
        bytes condition;
        bytes signature;
        uint256 nonce;
        address callback;
    }

    struct RandomnessRequestCreationParams {
        uint256 nonce;
        address callback;
    }
}

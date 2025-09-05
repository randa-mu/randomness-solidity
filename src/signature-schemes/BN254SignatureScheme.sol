// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {BLS} from "bls-solidity-0.1.0/BLS.sol";
import {BytesLib} from "../libraries/BytesLib.sol";

import {SignatureSchemeBase} from "./SignatureSchemeBase.sol";

/// @title BN254SignatureScheme contract
/// @author Randamu
/// @notice A contract that implements a BN254 signature scheme
contract BN254SignatureScheme is SignatureSchemeBase {
    using BytesLib for bytes32;

    /// @notice Identifier for the BN254 signature scheme
    string public constant SCHEME_ID = "BN254";

    /// @notice Domain separation tag for the BLS signature scheme
    bytes public DST;

    /// @notice Links public keys of threshold network statically to signature scheme contracts and remove from constructor of sender contracts. Admin cannot update, simply use new scheme id.
    BLS.PointG2 private publicKey;

    /// @notice Sets the DST with the current chain ID as a hex string (converted to bytes)
    constructor(bytes memory _publicKey) {
        DST = abi.encodePacked(
            "dcipher-randomness-v01-BN254G1_XMD:KECCAK-256_SVDW_RO_", bytes32(getChainId()).toHexString(), "_"
        );
        publicKey = BLS.g2Unmarshal(_publicKey);
    }

    /// @notice Retrieves the public key associated with the decryption process.
    /// @dev Returns the public key as bytes.
    /// @return Bytes string representing the public key points on the elliptic curve.
    function getPublicKeyBytes() public view returns (bytes memory) {
        return BLS.g2Marshal(publicKey);
    }

    /// @notice Verifies a signature using the given signature scheme.
    /// @param message The message that was signed. Message is a G1 point represented as bytes.
    /// @param signature The signature to verify. Signature is a G1 point represented as bytes.
    /// @param publicKey The public key of the signer. Public key is a G2 point represented as bytes.
    /// @return isValid boolean which evaluates to true if the signature is valid, false otherwise.
    function verifySignature(bytes calldata message, bytes calldata signature, bytes calldata publicKey)
        external
        view
        returns (bool isValid)
    {
        /// @dev Converts message hash bytes to G1 point
        BLS.PointG1 memory _message = BLS.g1Unmarshal(message);
        /// @dev Converts signature bytes to G1 point
        BLS.PointG1 memory _signature = BLS.g1Unmarshal(signature);
        /// @dev Converts public key bytes to G2 point
        BLS.PointG2 memory _publicKey = BLS.g2Unmarshal(publicKey);

        /// @dev Calls EVM precompile for pairing check
        (bool pairingSuccess, bool callSuccess) = BLS.verifySingle(_signature, _publicKey, _message);
        return pairingSuccess && callSuccess;
    }

    /// @notice Hashes a message to a point on the BN254 curve
    /// @param message The input message to hash
    /// @return (x, y) The coordinates of the resulting point on the curve
    function hashToPoint(bytes calldata message) public view returns (uint256, uint256) {
        BLS.PointG1 memory point = BLS.hashToPoint(DST, message);
        return (point.x, point.y);
    }

    /// @notice Hashes a message to a point on G1 and
    /// returns the point encoded as bytes
    /// @param message The input message to hash
    /// @return The encoded point in bytes format
    function hashToBytes(bytes calldata message) external view returns (bytes memory) {
        (uint256 x, uint256 y) = hashToPoint(message);
        return BLS.g1Marshal(BLS.PointG1({x: x, y: y}));
    }
}

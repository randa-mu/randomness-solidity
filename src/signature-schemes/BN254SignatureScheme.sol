// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {BLS} from "../libraries/BLS.sol";
import {ISignatureScheme} from "../interfaces/ISignatureScheme.sol";

/// @title BN254SignatureScheme contract
/// @author Randamu
/// @notice A contract that implements a BN254 signature scheme
contract BN254SignatureScheme is ISignatureScheme {
    /// @notice Identifier for the BN254 signature scheme
    string public constant SCHEME_ID = "BN254";

    /// @notice Domain separation tag for the BLS signature scheme
    bytes public DST;

    /// @notice Sets the DST with the current chain ID as a hex string (converted to bytes)
    constructor() {
        DST = abi.encodePacked(
            "dcipher-randomness-v01-BN254G1_XMD:KECCAK-256_SVDW_RO_", _toHexString(bytes32(getChainId())), "_"
        );
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

    /// @notice Returns the current blockchain chain ID.
    /// @dev Uses inline assembly to retrieve the `chainid` opcode.
    /// @return chainId The current chain ID of the network.
    function getChainId() public view returns (uint256 chainId) {
        assembly {
            chainId := chainid()
        }
    }

    /// @dev Converts bytes32 to 0x-prefixed hex string.
    /// @param data The bytes32 data to convert.
    function _toHexString(bytes32 data) internal pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory str = new bytes(2 + 64); // "0x" + 64 hex chars
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 32; i++) {
            str[2 + i * 2] = hexChars[uint8(data[i] >> 4)];
            str[2 + i * 2 + 1] = hexChars[uint8(data[i] & 0x0f)];
        }
        return string(str);
    }
}

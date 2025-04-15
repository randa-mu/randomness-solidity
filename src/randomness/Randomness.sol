// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {BLS} from "../libraries/BLS.sol";
import {FeistelShuffleOptimised} from "./FeistelShuffleOptimised.sol";
import {IRandomnessSender} from "../interfaces/IRandomnessSender.sol";
import {ISignatureSender} from "../interfaces/ISignatureSender.sol";
import {RandomnessSender} from "./RandomnessSender.sol";
import {TypesLib} from "../libraries/TypesLib.sol";
import {SignatureSender} from "../signature-requests/SignatureSender.sol";

/// @title Randomness library contract
/// @author Randamu
/// @notice Helper functions for randomness verification and usage.
library Randomness {
    /// @notice Request for randomness.
    function request(IRandomnessSender randomnessContract) public returns (uint256) {
        return randomnessContract.requestRandomness();
    }

    /// @notice Verify randomness received from offchain threshold network.
    function verify(
        address randomnessContract,
        address signatureContract,
        bytes calldata signature,
        uint256 requestID,
        address requester
    ) public view returns (bool) {
        // Message signing DST
        bytes memory DST = abi.encodePacked(
            "dcipher-randomness-v01-BN254G1_XMD:KECCAK-256_SVDW_RO_", _toHexString(bytes32(getChainId())), "_"
        );
        (uint256[2] memory x, uint256[2] memory y) = ISignatureSender(signatureContract).getPublicKey();
        BLS.PointG2 memory pk = BLS.PointG2({x: x, y: y});
        BLS.PointG1 memory _message = BLS.hashToPoint(
            DST, IRandomnessSender(randomnessContract).messageFrom(TypesLib.RandomnessRequest(requestID, requester))
        );
        BLS.PointG1 memory _signature = BLS.g1Unmarshal(signature);
        (bool pairingSuccess, bool callSuccess) = BLS.verifySingle(_signature, pk, _message);
        return pairingSuccess && callSuccess;
    }

    /// @notice Select array indices randomly
    function selectArrayIndices(uint256 lengthOfArray, uint256 countToDraw, bytes32 randomBytes)
        public
        pure
        returns (uint256[] memory)
    {
        if (lengthOfArray == 0) {
            return new uint256[](0);
        }

        uint256[] memory winners = new uint256[](countToDraw);
        if (lengthOfArray <= countToDraw) {
            for (uint256 i = 0; i < countToDraw; i++) {
                winners[i] = i;
            }
            return winners;
        }

        uint256 randomness;
        assembly {
            randomness := randomBytes
        }

        for (uint256 i = 0; i < countToDraw; i++) {
            winners[i] = FeistelShuffleOptimised.deshuffle(i, lengthOfArray, randomness, 10);
        }

        return winners;
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

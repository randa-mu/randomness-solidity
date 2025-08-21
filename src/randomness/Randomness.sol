// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {TypesLib} from "../libraries/TypesLib.sol";

import {IRandomnessSender} from "../interfaces/IRandomnessSender.sol";
import {ISignatureSender} from "../interfaces/ISignatureSender.sol";
import {ISignatureScheme} from "../interfaces/ISignatureScheme.sol";
import {ISignatureSchemeAddressProvider} from "../interfaces/ISignatureSchemeAddressProvider.sol";

import {RandomnessSender} from "./RandomnessSender.sol";
import {FeistelShuffleOptimised} from "./FeistelShuffleOptimised.sol";

/// @title Randomness library contract
/// @author Randamu
/// @notice Helper functions for randomness verification and usage.
library Randomness {
    /// @notice Verify randomness received from offchain threshold network.
    function verify(
        address randomnessContract,
        address signatureContract,
        bytes calldata signature,
        uint256 requestID,
        address requester,
        string calldata schemeID
    ) public view returns (bool) {
        ISignatureSender signatureSender = ISignatureSender(signatureContract);
        ISignatureSchemeAddressProvider signatureSchemeAddressProvider =
            signatureSender.signatureSchemeAddressProvider();
        ISignatureScheme signatureScheme =
            ISignatureScheme(signatureSchemeAddressProvider.getSignatureSchemeAddress(schemeID));

        bytes memory messagePoint = signatureScheme.hashToBytes(
            IRandomnessSender(randomnessContract).messageFrom(
                TypesLib.RandomnessRequestCreationParams(requestID, requester)
            )
        );
        bool pairingSuccess =
            signatureScheme.verifySignature(messagePoint, signature, signatureScheme.getPublicKeyBytes());
        return pairingSuccess;
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
}

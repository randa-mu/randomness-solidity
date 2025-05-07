// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {BLS} from "../libraries/BLS.sol";
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
    /// @notice Request for randomness.
    function request(IRandomnessSender randomnessContract) public returns (uint256) {
        return randomnessContract.requestRandomness();
    }

    // /// @notice Verify randomness received from offchain threshold network.
    // function verify(
    //     address randomnessContract,
    //     address signatureContract,
    //     bytes calldata signature,
    //     uint256 requestID,
    //     address requester,
    //     bytes calldata DST
    // ) public view returns (bool) {
    //     (uint256[2] memory x, uint256[2] memory y) = ISignatureSender(signatureContract).getPublicKey();
    //     BLS.PointG2 memory pk = BLS.PointG2({x: x, y: y});
    //     BLS.PointG1 memory _message = BLS.hashToPoint(
    //         DST, IRandomnessSender(randomnessContract).messageFrom(TypesLib.RandomnessRequest(requestID, requester))
    //     );
    //     BLS.PointG1 memory _signature = BLS.g1Unmarshal(signature);
    //     (bool pairingSuccess, bool callSuccess) = BLS.verifySingle(_signature, pk, _message);
    //     return pairingSuccess && callSuccess;
    // }

    // /// @notice Verify randomness received from offchain threshold network.
    // function verify(
    //     address randomnessContract,
    //     address signatureContract,
    //     bytes calldata signature,
    //     uint256 requestID,
    //     address requester
    // ) public view returns (bool) {
    //     ISignatureSender sigSender = ISignatureSender(signatureContract);

    //     // Fetch request data and public key
    //     string memory schemeID = sigSender.getRequest(requestID).schemeID;
    //     ISignatureScheme sigScheme = _getSignatureScheme(sigSender, schemeID);
    //     BLS.PointG2 memory pk = _getPublicKey(sigScheme);

    //     // Prepare message and signature
    //     bytes memory messageData = IRandomnessSender(randomnessContract).messageFrom(
    //         TypesLib.RandomnessRequest(requestID, requester)
    //     );
    //     BLS.PointG1 memory _message = BLS.hashToPoint(sigScheme.DST(), messageData);
    //     BLS.PointG1 memory _signature = BLS.g1Unmarshal(signature);

    //     // Verify signature
    //     (bool pairingSuccess, bool callSuccess) = BLS.verifySingle(_signature, pk, _message);
    //     return pairingSuccess && callSuccess;
    // }
    /// @notice Verify randomness received from offchain threshold network.
    function verify(
        address randomnessContract,
        address signatureContract,
        bytes calldata signature,
        uint64 requestID,
        address requester,
        string calldata schemeID
    ) public view returns (bool) {
        ISignatureSender signatureSender = ISignatureSender(signatureContract);
        ISignatureSchemeAddressProvider signatureSchemeAddressProvider =
            signatureSender.signatureSchemeAddressProvider();
        ISignatureScheme signatureScheme =
            ISignatureScheme(signatureSchemeAddressProvider.getSignatureSchemeAddress(schemeID));

        BLS.PointG1 memory messageHash = BLS.hashToPoint(
            signatureScheme.DST(),
            IRandomnessSender(randomnessContract).messageFrom(
                TypesLib.RandomnessRequestCreationParams(requestID, requester)
            )
        );
        BLS.PointG1 memory _signature = BLS.g1Unmarshal(signature);

        bool pairingSuccess = signatureScheme.verifySignature(
            BLS.g1Marshal(messageHash), BLS.g1Marshal(_signature), signatureScheme.getPublicKeyBytes()
        );
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

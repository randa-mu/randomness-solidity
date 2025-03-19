// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {BLS} from "../libraries/BLS.sol";
import {FeistelShuffleOptimised} from "./FeistelShuffleOptimised.sol";
import {IRandomnessSender} from "../interfaces/IRandomnessSender.sol";
import {ISignatureSender} from "../interfaces/ISignatureSender.sol";
import {RandomnessSender} from "./RandomnessSender.sol";
import {TypesLib} from "../libraries/TypesLib.sol";
import {SignatureSender} from "../signature-requests/SignatureSender.sol";

library Randomness {
    // Message signing DST
    bytes public constant DST = bytes("BLS_SIG_BN254G1_XMD:KECCAK-256_SVDW_RO_NUL_");

    function request(IRandomnessSender randomnessContract) public returns (uint256) {
        return randomnessContract.requestRandomness();
    }

    function verify(
        address randomnessContract,
        address signatureContract,
        bytes calldata signature,
        uint256 requestID,
        address requester
    ) public view returns (bool) {
        (uint256[2] memory x, uint256[2] memory y) = ISignatureSender(signatureContract).getPublicKey();
        BLS.PointG2 memory pk = BLS.PointG2({x: x, y: y});
        BLS.PointG1 memory _message = BLS.hashToPoint(
            DST, IRandomnessSender(randomnessContract).messageFrom(TypesLib.RandomnessRequest(requestID, requester))
        );
        BLS.PointG1 memory _signature = BLS.g1Unmarshal(signature);
        (bool pairingSuccess, bool callSuccess) = BLS.verifySingle(_signature, pk, _message);
        return pairingSuccess && callSuccess;
    }

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

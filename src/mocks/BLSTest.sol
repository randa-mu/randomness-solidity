// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {BLS} from "../libraries/BLS.sol";

import {Test} from "forge-std/Test.sol";

contract BLSTest is Test {
    function test__expandMsgTo96(bytes memory domain, bytes memory message)
        external
        view
        returns (bytes memory expanded, uint256 gas)
    {
        gas = gasleft();
        expanded = BLS.expandMsgTo96(domain, message);
        gas = gas - gasleft();
    }

    function test__hashToField(bytes memory domain, bytes memory message)
        external
        view
        returns (uint256[2] memory p, uint256 gas)
    {
        gas = gasleft();
        p = BLS.hashToField(domain, message);
        gas = gas - gasleft();
    }

    function test__mapToPoint(uint256 value) external view returns (uint256[2] memory p, uint256 gas) {
        gas = gasleft();
        uint256 N = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        // Skip values outside the BN254 field to avoid invalid field element errors during fuzz testing
        if (value >= N) {
            return (p, gas);
        }
        p = BLS.mapToPoint(value);
        gas = gas - gasleft();
    }

    function test__hashToPoint(bytes memory domain, bytes memory message)
        external
        view
        returns (BLS.PointG1 memory p, uint256 gas)
    {
        gas = gasleft();
        p = BLS.hashToPoint(domain, message);
        gas = gas - gasleft();
    }

    function test__verifySingle(uint256[2] memory signature, uint256[4] memory pubkey, uint256[2] memory message)
        external
        view
        returns (bool pairingSuccess, bool callSuccess, uint256 gas)
    {
        gas = gasleft();
        (pairingSuccess, callSuccess) = BLS.verifySingle(
            BLS.PointG1({x: signature[0], y: signature[1]}),
            BLS.PointG2({x: [pubkey[0], pubkey[1]], y: [pubkey[2], pubkey[3]]}),
            BLS.PointG1({x: message[0], y: message[1]})
        );
        gas = gas - gasleft();
    }

    function test__isOnCurveG1(uint256[2] memory point) external view returns (bool _isOnCurve, uint256 gas) {
        gas = gasleft();
        _isOnCurve = BLS.isOnCurveG1(BLS.PointG1({x: point[0], y: point[1]}));
        gas = gas - gasleft();
    }

    function test__isOnCurveG2(uint256[4] memory point) external view returns (bool _isOnCurve, uint256 gas) {
        gas = gasleft();
        _isOnCurve = BLS.isOnCurveG2(BLS.PointG2({x: [point[0], point[1]], y: [point[2], point[3]]}));
        gas = gas - gasleft();
    }

    function test__isValidSignature(uint256[2] memory signature) external view returns (bool isValid, uint256 gas) {
        gas = gasleft();
        isValid = BLS.isValidSignature(signature);
        gas = gas - gasleft();
    }

    function test__isValidPublicKey(uint256[4] memory publicKey) external view returns (bool isValid, uint256 gas) {
        gas = gasleft();
        isValid = BLS.isValidPublicKey(publicKey);
        gas = gas - gasleft();
    }
}

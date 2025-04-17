// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

library Constants {
    bytes32 constant SALT = bytes32(uint256(12));

    string constant RANDOMNESS_BN254_SIGNATURE_SCHEME_ID = "BN254";
    string constant DEPLOYMENT_INPUT_JSON_PATH = "Deployment_input.json";
}

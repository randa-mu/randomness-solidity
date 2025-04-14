// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

library Constants {
    address constant CREATE2_FACTORY = 0x8192aF4ce49f473fCa7e3e5a8d819B0763Def048;

    bytes32 constant SALT = bytes32(uint256(12));

    string constant RANDOMNESS_BN254_SIGNATURE_SCHEME_ID = "BN254";
    string constant DEPLOYMENT_INPUT_JSON_PATH = "Deployment_input.json";

    bool constant USE_RANDAMU_FACTORY = false;
}

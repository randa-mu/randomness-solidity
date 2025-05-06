// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {Constants} from "../libraries/Constants.sol";

import {JsonUtils} from "../utils/JsonUtils.sol";
import {EnvReader} from "../utils/EnvReader.sol";

import {BN254SignatureScheme} from "src/signature-schemes/BN254SignatureScheme.sol";
import {SignatureSchemeAddressProvider} from "src/signature-schemes/SignatureSchemeAddressProvider.sol";
import {Factory} from "src/factory/Factory.sol";

/// @title DeployBN254SignatureScheme
/// @dev Script for deploying BN254SignatureScheme contract.
contract DeployBN254SignatureScheme is JsonUtils, EnvReader {
    function run() public virtual {
        deployBN254SignatureScheme();
    }

    function deployBN254SignatureScheme() internal returns (BN254SignatureScheme bn254SignatureScheme) {
        bytes memory code = abi.encodePacked(
            type(BN254SignatureScheme).creationCode, abi.encode(getBLSPublicKey().x, getBLSPublicKey().y)
        );

        vm.broadcast();
        if (vm.envBool("USE_RANDAMU_FACTORY")) {
            address contractAddress =
                Factory(vm.envAddress("RANDAMU_CREATE2_FACTORY_CONTRACT_ADDRESS")).deploy(Constants.SALT, code);
            bn254SignatureScheme = BN254SignatureScheme(contractAddress);
        } else {
            bn254SignatureScheme =
                new BN254SignatureScheme{salt: Constants.SALT}(getBLSPublicKey().x, getBLSPublicKey().y);
        }

        console.log("Bn254SignatureScheme contract deployed at: ", address(bn254SignatureScheme));

        address signatureSchemeAddressProviderAddress =
            _readAddressFromJsonInput(Constants.DEPLOYMENT_INPUT_JSON_PATH, "signatureSchemeAddressProviderAddress");

        SignatureSchemeAddressProvider signatureSchemeAddressProvider =
            SignatureSchemeAddressProvider(signatureSchemeAddressProviderAddress);

        vm.broadcast();
        signatureSchemeAddressProvider.updateSignatureScheme(
            Constants.RANDOMNESS_BN254_SIGNATURE_SCHEME_ID, address(bn254SignatureScheme)
        );
    }
}

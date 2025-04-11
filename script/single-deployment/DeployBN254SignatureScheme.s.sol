// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {Constants} from "../libraries/Constants.sol";

import {JsonUtils} from "../utils/JsonUtils.sol";

import {MockBN254SignatureScheme} from "src/mocks/MockBN254SignatureScheme.sol";
import {SignatureSchemeAddressProvider} from "src/signature-schemes/SignatureSchemeAddressProvider.sol";
import {Factory} from "src/factory/Factory.sol";

/// @title DeploySignatureSchemeAddressProvider
/// @dev Script for deploying MockBN254SignatureScheme contract.
contract DeployBN254SignatureScheme is JsonUtils {
    function run() public virtual {
        deployBN254SignatureScheme();
    }

    function deployBN254SignatureScheme() internal returns (MockBN254SignatureScheme bn254SignatureScheme) {
        bytes memory code = type(MockBN254SignatureScheme).creationCode;

        vm.broadcast();
        if (Constants.USE_RANDAMU_FACTORY) {
            address contractAddress = Factory(Constants.CREATE2_FACTORY).deploy(Constants.SALT, code);
            bn254SignatureScheme = MockBN254SignatureScheme(contractAddress);
        } else {
            bn254SignatureScheme = new MockBN254SignatureScheme{salt: Constants.SALT}();
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

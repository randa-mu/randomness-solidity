// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {Constants} from "../libraries/Constants.sol";

import {JsonUtils} from "../utils/JsonUtils.sol";
import {SignatureUtils} from "../utils/SignatureUtils.sol";
import {EnvReader} from "../utils/EnvReader.sol";

import {SignatureSender} from "src/signature-requests/SignatureSender.sol";
import {UUPSProxy} from "src/proxy/UUPSProxy.sol";
import {Factory} from "src/factory/Factory.sol";

/// @title DeploySignatureSender
/// @dev Script for deploying or upgrading the SignatureSender contract.
/// Reads an environment variable to determine if it's an upgrade (new implementation only) or a full deployment.
contract DeploySignatureSender is JsonUtils, SignatureUtils, EnvReader {
    function run() public virtual {
        bool isUpgrade = vm.envBool("IS_UPGRADE");
        address signatureSchemeAddressProvider =
            _readAddressFromJsonInput(Constants.DEPLOYMENT_INPUT_JSON_PATH, "signatureSchemeAddressProviderAddress");
        deploySignatureSenderProxy(signatureSchemeAddressProvider, isUpgrade);
    }

    /// @notice Deploys the SignatureSender proxy contract or upgrades its implementation.
    /// @param signatureSchemeAddressProviderAddress The address of the SignatureSchemeAddressProvider contract.
    /// @param isUpgrade A flag indicating whether to perform an upgrade (true) or a full deployment (false).
    function deploySignatureSenderProxy(address signatureSchemeAddressProviderAddress, bool isUpgrade)
        internal
        returns (SignatureSender signatureSenderInstance)
    {
        address implementation = deploySignatureSenderImplementation();

        if (isUpgrade) {
            vm.broadcast();
            address proxyAddress =
                _readAddressFromJsonInput(Constants.DEPLOYMENT_INPUT_JSON_PATH, "signatureSenderProxyAddress");
            SignatureSender(proxyAddress).upgradeToAndCall(implementation, "");
            console.log("SignatureSender contract upgraded to new implementation at: ", implementation);
            signatureSenderInstance = SignatureSender(proxyAddress);
        } else {
            // Deploy a new proxy if it's a full deployment
            bytes memory code = abi.encodePacked(type(UUPSProxy).creationCode, abi.encode(implementation, ""));

            vm.broadcast();
            address contractAddress;

            if (Constants.USE_RANDAMU_FACTORY) {
                contractAddress = Factory(Constants.CREATE2_FACTORY).deploy(Constants.SALT, code);

                signatureSenderInstance = SignatureSender(contractAddress);
            } else {
                UUPSProxy proxy = new UUPSProxy{salt: Constants.SALT}(implementation, "");
                signatureSenderInstance = SignatureSender(address(proxy));

                contractAddress = address(proxy);
            }

            _writeAddressToJsonInput(
                Constants.DEPLOYMENT_INPUT_JSON_PATH, "signatureSenderProxyAddress", contractAddress
            );

            vm.broadcast();
            signatureSenderInstance.initialize(
                BLS_PUBLIC_KEY.x, BLS_PUBLIC_KEY.y, getSignerAddress(), signatureSchemeAddressProviderAddress
            );

            console.log("SignatureSender proxy contract deployed at: ", contractAddress);
        }
    }

    /// @notice Deploys the SignatureSender implementation contract.
    /// @return implementation The address of the newly deployed implementation contract.
    function deploySignatureSenderImplementation() internal returns (address implementation) {
        bytes memory code = type(SignatureSender).creationCode;

        vm.broadcast();
        if (Constants.USE_RANDAMU_FACTORY) {
            implementation = Factory(Constants.CREATE2_FACTORY).deploy(Constants.SALT, code);
        } else {
            SignatureSender signatureSender = new SignatureSender{salt: Constants.SALT}();
            implementation = address(signatureSender);
        }

        console.log("SignatureSender implementation contract deployed at: ", implementation);
    }
}

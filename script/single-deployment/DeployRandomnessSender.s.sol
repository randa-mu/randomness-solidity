// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {Constants} from "../libraries/Constants.sol";

import {JsonUtils} from "../utils/JsonUtils.sol";
import {EnvReader} from "../utils/EnvReader.sol";

import {RandomnessSender} from "src/randomness/RandomnessSender.sol";
import {UUPSProxy} from "src/proxy/UUPSProxy.sol";
import {Factory} from "src/factory/Factory.sol";

/// @title DeployRandomnessSender
/// @dev Script for deploying or upgrading the RandomnessSender contract.
/// Reads an environment variable to determine if it's an upgrade (new implementation only) or a full deployment.
contract DeployRandomnessSender is JsonUtils, EnvReader {

    /// @notice Runs the deployment script, checking the environment variable to determine whether to upgrade or deploy.
    function run() public virtual {
        bool isUpgrade = vm.envBool("IS_UPGRADE");
        address signatureSenderProxyAddress =
            _readAddressFromJsonInput(Constants.DEPLOYMENT_INPUT_JSON_PATH, "signatureSenderProxyAddress");
        deployRandomnessSenderProxy(signatureSenderProxyAddress, isUpgrade);
    }

    /// @notice Deploys the RandomnessSender proxy contract or upgrades its implementation.
    /// @param signatureSenderProxyAddress The address of the SignatureSender proxy contract.
    /// @param isUpgrade A flag indicating whether to perform an upgrade (true) or a full deployment (false).
    function deployRandomnessSenderProxy(address signatureSenderProxyAddress, bool isUpgrade)
        internal
        returns (RandomnessSender randomnessSenderInstance)
    {
        address implementation = deployRandomnessSenderImplementation();

        if (isUpgrade) {
            vm.broadcast();
            address proxyAddress =
                _readAddressFromJsonInput(Constants.DEPLOYMENT_INPUT_JSON_PATH, "randomnessSenderProxyAddress");
            RandomnessSender(proxyAddress).upgradeToAndCall(implementation, "");
            console.log("RandomnessSender contract upgraded to new implementation at: ", implementation);
            randomnessSenderInstance = RandomnessSender(proxyAddress);
        } else {
            // Deploy a new proxy if it's a full deployment
            bytes memory code = abi.encodePacked(type(UUPSProxy).creationCode, abi.encode(implementation, ""));

            vm.broadcast();
            address contractAddress;

            if (Constants.USE_RANDAMU_FACTORY) {
                contractAddress = Factory(Constants.CREATE2_FACTORY).deploy(Constants.SALT, code);

                randomnessSenderInstance = RandomnessSender(contractAddress);
            } else {
                UUPSProxy proxy = new UUPSProxy{salt: Constants.SALT}(implementation, "");
                randomnessSenderInstance = RandomnessSender(address(proxy));

                contractAddress = address(proxy);
            }

            _writeAddressToJsonInput(
                Constants.DEPLOYMENT_INPUT_JSON_PATH, "randomnessSenderProxyAddress", contractAddress
            );

            vm.broadcast();
            randomnessSenderInstance.initialize(signatureSenderProxyAddress, getSignerAddress());

            console.log("RandomnessSender proxy contract deployed at: ", contractAddress);
        }
    }

    /// @notice Deploys the RandomnessSender implementation contract.
    /// @return implementation The address of the newly deployed implementation contract.
    function deployRandomnessSenderImplementation() internal returns (address implementation) {
        bytes memory code = type(RandomnessSender).creationCode;

        vm.broadcast();
        if (Constants.USE_RANDAMU_FACTORY) {
            implementation = Factory(Constants.CREATE2_FACTORY).deploy(Constants.SALT, code);
        } else {
            RandomnessSender randomnessSender = new RandomnessSender{salt: Constants.SALT}();
            implementation = address(randomnessSender);
        }

        console.log("RandomnessSender implementation contract deployed at: ", implementation);
    }
}

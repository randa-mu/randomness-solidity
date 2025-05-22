// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {Constants} from "../libraries/Constants.sol";

import {JsonUtils} from "../utils/JsonUtils.sol";

import {MockRandomnessReceiver} from "src/mocks/MockRandomnessReceiver.sol";
import {Factory} from "src/factory/Factory.sol";

/// @title DeployRandomnessReceiver
/// @dev Script for deploying MockRandomnessReceiver contract.
contract DeployRandomnessReceiver is JsonUtils {
    function run() public virtual {
        address randomnessSenderAddr =
            _readAddressFromJsonInput(Constants.DEPLOYMENT_INPUT_JSON_PATH, "randomnessSenderProxyAddress");

        deployRandomnessReceiver(randomnessSenderAddr);
    }

    function deployRandomnessReceiver(address randomnessSenderAddr)
        internal
        returns (MockRandomnessReceiver mockRandomnessReceiver)
    {
        bytes memory code =
            abi.encodePacked(type(MockRandomnessReceiver).creationCode, abi.encode(randomnessSenderAddr));

        vm.broadcast();
        if (vm.envBool("USE_RANDAMU_FACTORY")) {
            address contractAddress =
                Factory(vm.envAddress("RANDAMU_CREATE2_FACTORY_CONTRACT_ADDRESS")).deploy(Constants.SALT, code);

            mockRandomnessReceiver = MockRandomnessReceiver(payable(contractAddress));
        } else {
            mockRandomnessReceiver = new MockRandomnessReceiver{salt: Constants.SALT}(randomnessSenderAddr);
        }

        console.log("MockRandomnessReceiver deployed at: ", address(mockRandomnessReceiver));
    }
}

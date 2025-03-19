// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {BLS} from "../src/libraries/BLS.sol";
import {TypesLib} from "../src/libraries/TypesLib.sol";

import {SignatureSender} from "../src/signature-requests/SignatureSender.sol";
import {RandomnessSender} from "../src/randomness/RandomnessSender.sol";

contract RandomnessAccessControlScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address admin = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        address newAdminAddress = 0xeBF734904A441a4112e511Fd40600098E9082897;
        address signatureSenderAddress = 0x1c86A81D3CDD897aFdcA62a9b7219a39Aef7910B;
        address randomnessSenderAddress = 0x9c789bc7F2B5c6619Be1572A39F2C3d6f33001dC;

        bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");
        bytes32 DEFAULT_ADMIN_ROLE = 0x00;

        SignatureSender signatureSender = SignatureSender(signatureSenderAddress);
        RandomnessSender randomnessSender = RandomnessSender(randomnessSenderAddress);

        // grant roles
        // signatureSender.grantRole(ADMIN_ROLE, newAdminAddress);
        // randomnessSender.grantRole(ADMIN_ROLE, newAdminAddress);

        // signatureSender.grantRole(DEFAULT_ADMIN_ROLE, newAdminAddress);
        // randomnessSender.grantRole(DEFAULT_ADMIN_ROLE, newAdminAddress);

        // revoke roles
        // signatureSender.revokeRole(ADMIN_ROLE, admin);
        // randomnessSender.revokeRole(ADMIN_ROLE, admin);

        // signatureSender.revokeRole(DEFAULT_ADMIN_ROLE, admin);
        // randomnessSender.revokeRole(DEFAULT_ADMIN_ROLE, admin);

        console.log(randomnessSender.hasRole(ADMIN_ROLE, admin));
        console.log(randomnessSender.hasRole(DEFAULT_ADMIN_ROLE, admin));
        console.log(signatureSender.hasRole(ADMIN_ROLE, admin));
        console.log(signatureSender.hasRole(DEFAULT_ADMIN_ROLE, admin));
    }
}

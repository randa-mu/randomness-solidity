// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {BLS} from "../src/libraries/BLS.sol";
import {TypesLib} from "../src/libraries/TypesLib.sol";

import {UUPSProxy} from "../src/proxy/UUPSProxy.sol";
import {SignatureSchemeAddressProvider} from "../src/signature-schemes/SignatureSchemeAddressProvider.sol";
import {SignatureSender} from "../src/signature-requests/SignatureSender.sol";
import {MockBN254SignatureScheme} from "../src/mocks/MockBN254SignatureScheme.sol";
import {RandomnessSender} from "../src/randomness/RandomnessSender.sol";
import {MockRandomnessReceiver} from "../src/mocks/MockRandomnessReceiver.sol";

contract RandomnessUpgradeScript is Script {
    string SCHEME_ID = "BN254";

    BLS.PointG2 pk = BLS.PointG2({
        x: [
            17445541620214498517833872661220947475697073327136585274784354247720096233162,
            18268991875563357240413244408004758684187086817233527689475815128036446189503
        ],
        y: [
            11401601170172090472795479479864222172123705188644469125048759621824127399516,
            8044854403167346152897273335539146380878155193886184396711544300199836788154
        ]
    });

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address signatureSenderProxyAddr = 0x1c86A81D3CDD897aFdcA62a9b7219a39Aef7910B;
        address randomnessSenderProxyAddr = 0x9c789bc7F2B5c6619Be1572A39F2C3d6f33001dC;

        // deploy implementation contracts for signature and randomness senders
        SignatureSender signatureSenderImplementation = new SignatureSender();
        console.log("\nSignatureSender implementation contract deployed at: ", address(signatureSenderImplementation));

        RandomnessSender randomnessSenderImplementation = new RandomnessSender();
        console.log("\nRandomnessSender implementation contract deployed at: ", address(randomnessSenderImplementation));

        // target proxy contracts
        UUPSProxy signatureSenderProxy = UUPSProxy(payable(signatureSenderProxyAddr));
        console.log("\nSignature Sender proxy contract deployed at: ", address(signatureSenderProxy));

        UUPSProxy randomnessSenderProxy = UUPSProxy(payable(randomnessSenderProxyAddr));
        console.log("Randomness Sender proxy contract deployed at: ", address(randomnessSenderProxy));

        // wrap proxy address in implementation ABI to support delegate calls
        SignatureSender signatureSender = SignatureSender(address(signatureSenderProxy));
        RandomnessSender randomnessSender = RandomnessSender(address(randomnessSenderProxy));

        console.log("\nSignatureSender version pre upgrade: ", signatureSender.version());
        console.log("RandomnessSender version pre upgrade: ", randomnessSender.version());

        // Perform implementation contract upgrades
        signatureSender.upgradeToAndCall(address(signatureSenderImplementation), "");
        randomnessSender.upgradeToAndCall(address(randomnessSenderImplementation), "");

        console.log("\nSignatureSender version post upgrade: ", signatureSender.version());
        console.log("RandomnessSender version post upgrade: ", randomnessSender.version());
    }
}

/**
 * # Deployment steps
 *
 * ## STEP 1. Load the variables in the .env file
 * source .env
 *
 * ## STEP 2. Deploy and verify the contract
 * forge script script/RandomnessUpgrade.s.sol:RandomnessUpgradeScript --rpc-url $CALIBRATIONNET_RPC_URL --broadcast -g 100000 -vvvv
 *
 * -g is the gas limit passed in order to prevent a common error with deploying contracts to the FEVM as per the docs in the filecoin fevm foundry kit here - https://github.com/filecoin-project/fevm-foundry-kit/tree/main
 *
 * For ethereum, add --verify with etherscan key in .env and foundry.toml files
 */

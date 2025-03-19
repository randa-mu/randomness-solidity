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

contract RandomnessDeploymentScript is Script {
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

        address admin = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

        // SignatureSchemeAddressProvider signatureSchemeAddressProvider = new SignatureSchemeAddressProvider(admin);
        // using existing SignatureSchemeAddressProvider contract on Filecoin Calibration testnet
        SignatureSchemeAddressProvider signatureSchemeAddressProvider =
            SignatureSchemeAddressProvider(0xD2b5084E68230D609AEaAe5E4cF7df9ebDd6375A);
        MockBN254SignatureScheme bn254SignatureScheme = new MockBN254SignatureScheme();
        signatureSchemeAddressProvider.updateSignatureScheme(SCHEME_ID, address(bn254SignatureScheme));

        console.log("\nSignatureSchemeAddressProvider contract deployed to: ", address(signatureSchemeAddressProvider));

        console.log("Bn254SignatureScheme contract deployed to: ", address(bn254SignatureScheme));

        // deploy implementation contracts for signature and randomness senders
        SignatureSender signatureSenderImplementation = new SignatureSender();
        console.log("\nSignatureSender implementation contract deployed at: ", address(signatureSenderImplementation));

        RandomnessSender randomnessSenderImplementation = new RandomnessSender();
        console.log("RandomnessSender implementation contract deployed at: ", address(randomnessSenderImplementation));

        // deploy proxy contracts and point them to their implementation contracts
        UUPSProxy signatureSenderProxy = new UUPSProxy(address(signatureSenderImplementation), "");
        console.log("\nSignature Sender proxy contract deployed at: ", address(signatureSenderProxy));

        UUPSProxy randomnessSenderProxy = new UUPSProxy(address(randomnessSenderImplementation), "");
        console.log("Randomness Sender proxy contract deployed at: ", address(randomnessSenderProxy));

        // wrap proxy address in implementation ABI to support delegate calls
        SignatureSender signatureSender = SignatureSender(address(signatureSenderProxy));
        RandomnessSender randomnessSender = RandomnessSender(address(randomnessSenderProxy));

        // initialize the contracts
        signatureSender.initialize(pk.x, pk.y, admin, address(signatureSchemeAddressProvider));
        randomnessSender.initialize(address(signatureSender), admin);

        MockRandomnessReceiver mockRandomnessReceiver = new MockRandomnessReceiver(address(randomnessSender));
        console.log("\nMockRandomnessReceiver deployed at: ", address(mockRandomnessReceiver));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Test, console} from "forge-std-1.10.0/Test.sol";

// helpers
import {BLS} from "bls-solidity-0.3.0/src/libraries/BLS.sol";
import {TypesLib} from "../../../src/libraries/TypesLib.sol";
import {UUPSProxy} from "../../../src/proxy/UUPSProxy.sol";
import {Base} from "./Base.t.sol";

// core contracts
import {SignatureSchemeAddressProvider} from "../../../src/signature-schemes/SignatureSchemeAddressProvider.sol";
import {SignatureSender} from "../../../src/signature-requests/SignatureSender.sol";
import {BN254SignatureScheme} from "bls-solidity-0.3.0/src/signature-schemes/BN254SignatureScheme.sol";
import {BLS12381SignatureScheme} from "bls-solidity-0.3.0/src/signature-schemes/BLS12381SignatureScheme.sol";
import {BLS12381CompressedSignatureScheme} from
    "bls-solidity-0.3.0/src/signature-schemes/BLS12381CompressedSignatureScheme.sol";

import {RandomnessSender} from "../../../src/randomness/RandomnessSender.sol";
import {Randomness} from "../../../src/randomness/Randomness.sol";

// mock contracts
import {MockRandomnessReceiver} from "../../../src/mocks/MockRandomnessReceiver.sol";

abstract contract Deployment is Base {
    string internal constant applicationNameForDST = "dcipher-randomness-v01";
    string internal constant bn254SignatureSchemeID = "BN254";
    string internal constant bls12381SignatureSchemeID = "BLS12381";
    string internal constant bls12381CompressedSignatureSchemeID = "BLS12381Compressed";
    bytes internal validPK =
        hex"204a5468e6d01b87c07655eebbb1d43913e197f53281a7d56e2b1a0beac194aa00899f6a3998ecb2f832d35025bf38bef7429005e6b591d9e0ffb10078409f220a6758eec538bb8a511eed78c922a213e4cc06743aeb10ed77f63416fe964c3505d04df1d2daeefa07790b41a9e0ab762e264798bc36340dc3a0cc5654cefa4b";
    bytes internal validPkBLS2 =
        hex"0eb3c62c162b4bf3da2df034c4ebf8f753c929a6e2424269f41558c8d3c6358a38bc199199a3cc4f3c275525f72e6ed00ea36aa928f4d6a58765ac61398baed7d1b195b71f7de3714fb0b87edf71792313a5b1650264cbfff03f78bafbd6590001d140f45a64fcf285f51f2e55ed11432e3829cd027dc2e6adb4a2fbc99e2aac0faf0aef517b525a3d5d80aa6cc41acd12c785bd8662d22ce36627e15ea5de6d3cb642be582410da7c95dc1ffc9bff902f05fff594f4956b2137cde3f172c71d";
    bytes internal validSignature =
        hex"0d1a2ccd46cb80f94b40809dbd638b44c78e456a4e06b886e8c8f300fa4073950b438ea53140bb1bc93a1c632ab4df0a07d702f34e48ecb7d31da7762a320ad5";
    bytes internal validSignatureBLS2 =
        hex"0c2e04c6d1cb77198d5a35721fc706c7f961ed191bdd1a4a153221c8926a0cf683fb19757ac1b6263278dde960f789181778bbea7e04e772293bd2fa46f97964d16c74055eccdf077c6406aa0b28f0ac6cc2ab59a76c7bc3368cf5a68b288ec8";
    bytes internal validSignatureBLS2Compressed =
        hex"ac2e04c6d1cb77198d5a35721fc706c7f961ed191bdd1a4a153221c8926a0cf683fb19757ac1b6263278dde960f78918";

    bytes internal conditions = "";
    bytes32 internal constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    function setUp() public virtual override {
        // setup base test
        super.setUp();
    }

    function deployContracts()
        internal
        returns (
            SignatureSchemeAddressProvider signatureSchemeAddressProvider,
            BN254SignatureScheme bn254SignatureScheme,
            BLS12381SignatureScheme bls12381SignatureScheme,
            BLS12381CompressedSignatureScheme bls12381CompressedSignatureScheme,
            RandomnessSender randomnessSender,
            SignatureSender signatureSender
        )
    {
        vm.startPrank(admin);

        // deploy signature scheme address provider
        signatureSchemeAddressProvider = new SignatureSchemeAddressProvider(address(0));

        // deploy bn254 signature scheme
        bn254SignatureScheme = new BN254SignatureScheme(validPK, applicationNameForDST);
        bls12381SignatureScheme = new BLS12381SignatureScheme(validPkBLS2, applicationNameForDST);
        bls12381CompressedSignatureScheme = new BLS12381CompressedSignatureScheme(validPkBLS2, applicationNameForDST);
        signatureSchemeAddressProvider.updateSignatureScheme(bn254SignatureSchemeID, address(bn254SignatureScheme));
        signatureSchemeAddressProvider.updateSignatureScheme(
            bls12381SignatureSchemeID, address(bls12381SignatureScheme)
        );
        signatureSchemeAddressProvider.updateSignatureScheme(
            bls12381CompressedSignatureSchemeID, address(bls12381CompressedSignatureScheme)
        );

        // deploy implementation contracts for signature and randomness senders
        SignatureSender signatureSenderImplementationV1 = new SignatureSender();
        RandomnessSender randomnessSenderImplementationV1 = new RandomnessSender();

        // deploy proxy contracts and point them to their implementation contracts
        UUPSProxy signatureSenderProxy = new UUPSProxy(address(signatureSenderImplementationV1), "");
        console.log("Signature Sender proxy contract deployed at: ", address(signatureSenderProxy));

        UUPSProxy randomnessSenderProxy = new UUPSProxy(address(randomnessSenderImplementationV1), "");
        console.log("Randomness Sender proxy contract deployed at: ", address(randomnessSenderProxy));

        // wrap proxy address in implementation ABI to support delegate calls
        signatureSender = SignatureSender(address(signatureSenderProxy));
        randomnessSender = RandomnessSender(address(randomnessSenderProxy));

        // initialize the contracts
        uint256 minimumContractUpgradeDelay = 2 days;
        signatureSender.initialize(admin, address(signatureSchemeAddressProvider), address(bn254SignatureScheme), minimumContractUpgradeDelay);
        randomnessSender.initialize(address(signatureSender), admin, address(bn254SignatureScheme), minimumContractUpgradeDelay);

        // set blocklockSender contract config
        uint32 maxGasLimit = 500_000;
        uint32 gasAfterPaymentCalculation = 400_000;
        uint32 fulfillmentFlatFeeNativePPM = 1_000_000;
        uint32 weiPerUnitGas = 0.003 gwei;
        uint32 blsPairingCheckOverhead = 800_000;
        uint8 nativePremiumPercentage = 10;
        uint16 gasForExactCallCheck = 5000;

        setBlocklockSenderUserBillingConfiguration(
            randomnessSender,
            maxGasLimit,
            gasAfterPaymentCalculation,
            fulfillmentFlatFeeNativePPM,
            weiPerUnitGas,
            blsPairingCheckOverhead,
            nativePremiumPercentage,
            gasForExactCallCheck
        );

        vm.stopPrank();
    }

    function deployAndFundReceiverWithSubscription(address owner, address randomnessSenderProxy, uint256 subBalance)
        internal
        returns (MockRandomnessReceiver mockRandomnessReceiver)
    {
        vm.prank(owner);
        mockRandomnessReceiver = new MockRandomnessReceiver(randomnessSenderProxy, owner);

        vm.prank(owner);
        mockRandomnessReceiver.createSubscriptionAndFundNative{value: subBalance}();
    }

    function deployRandomnessReceiver(address owner, address randomnessSenderProxy)
        internal
        returns (MockRandomnessReceiver mockRandomnessReceiver)
    {
        vm.prank(owner);
        mockRandomnessReceiver = new MockRandomnessReceiver(randomnessSenderProxy, owner);
    }

    // helper functions
    function setBlocklockSenderUserBillingConfiguration(
        RandomnessSender randomnessSender,
        uint32 maxGasLimit,
        uint32 gasAfterPaymentCalculation,
        uint32 fulfillmentFlatFeeNativePPM,
        uint32 weiPerUnitGas,
        uint32 blsPairingCheckOverhead,
        uint8 nativePremiumPercentage,
        uint32 gasForCallExactCheck
    ) internal {
        randomnessSender.setConfig(
            maxGasLimit,
            gasAfterPaymentCalculation,
            fulfillmentFlatFeeNativePPM,
            weiPerUnitGas,
            blsPairingCheckOverhead,
            nativePremiumPercentage,
            gasForCallExactCheck
        );
    }
}

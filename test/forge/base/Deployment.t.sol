// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";

// helpers
import {BLS} from "../../../src/libraries/BLS.sol";
import {TypesLib} from "../../../src/libraries/TypesLib.sol";
import {UUPSProxy} from "../../../src/proxy/UUPSProxy.sol";
import {Base} from "./Base.t.sol";

// core contracts
import {SignatureSchemeAddressProvider} from "../../../src/signature-schemes/SignatureSchemeAddressProvider.sol";
import {SignatureSender} from "../../../src/signature-requests/SignatureSender.sol";
import {BN254SignatureScheme} from "../../../src/signature-schemes/BN254SignatureScheme.sol";
import {RandomnessSender} from "../../../src/randomness/RandomnessSender.sol";
import {Randomness} from "../../../src/randomness/Randomness.sol";

// mock contracts
import {MockRandomnessReceiver} from "../../../src/mocks/MockRandomnessReceiver.sol";

abstract contract Deployment is Base {
    string internal constant bn254SignatureSchemeID = "BN254";
    bytes internal validPK =
        hex"204a5468e6d01b87c07655eebbb1d43913e197f53281a7d56e2b1a0beac194aa00899f6a3998ecb2f832d35025bf38bef7429005e6b591d9e0ffb10078409f220a6758eec538bb8a511eed78c922a213e4cc06743aeb10ed77f63416fe964c3505d04df1d2daeefa07790b41a9e0ab762e264798bc36340dc3a0cc5654cefa4b";
    bytes internal validSignature =
        hex"0d1a2ccd46cb80f94b40809dbd638b44c78e456a4e06b886e8c8f300fa4073950b438ea53140bb1bc93a1c632ab4df0a07d702f34e48ecb7d31da7762a320ad5";

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
            RandomnessSender randomnessSender,
            SignatureSender signatureSender
        )
    {
        vm.startPrank(admin);

        BLS.PointG2 memory pk = abi.decode(validPK, (BLS.PointG2));

        // deploy signature scheme address provider
        signatureSchemeAddressProvider = new SignatureSchemeAddressProvider(address(0));

        // deploy bn254 signature scheme
        bn254SignatureScheme = new BN254SignatureScheme([pk.x[1], pk.x[0]], [pk.y[1], pk.y[0]]);
        signatureSchemeAddressProvider.updateSignatureScheme(bn254SignatureSchemeID, address(bn254SignatureScheme));

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
        signatureSender.initialize(admin, address(signatureSchemeAddressProvider));
        randomnessSender.initialize(address(signatureSender), admin);

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

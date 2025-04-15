// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";

import {Constants} from "./libraries/Constants.sol";

import {RandomnessSender, DeployRandomnessSender} from "./single-deployment/DeployRandomnessSender.s.sol";
import {
    SignatureSchemeAddressProvider,
    DeploySignatureSchemeAddressProvider
} from "./single-deployment/DeploySignatureSchemeAddressProvider.s.sol";
import {SignatureSender, DeploySignatureSender} from "./single-deployment/DeploySignatureSender.s.sol";
import {
    BN254SignatureScheme, DeployBN254SignatureScheme
} from "./single-deployment/DeployBN254SignatureScheme.s.sol";

/// @title DeployAllContracts
/// @author Randamu
/// @notice A deployment contract that deploys all contracts required for
/// blocklock requests and randomness requests.
contract DeployAllContracts is
    DeployRandomnessSender,
    DeploySignatureSchemeAddressProvider,
    DeploySignatureSender,
    DeployBN254SignatureScheme
{
    function run()
        public
        override(
            DeployRandomnessSender,
            DeploySignatureSchemeAddressProvider,
            DeploySignatureSender,
            DeployBN254SignatureScheme
        )
    {
        deployAll();
    }

    /// @notice Deploys all required contracts or upgrades them based on the `isUpgrade` flag.
    /// @dev This function initializes multiple contracts and links them together as needed.
    /// @return bn254SignatureScheme The deployed instance of BN254SignatureScheme.
    /// @return randomnessSenderInstance The deployed instance of RandomnessSender.
    /// @return signatureSchemeAddressProvider The deployed instance of SignatureSchemeAddressProvider.
    /// @return signatureSenderInstance The deployed instance of SignatureSender.
    function deployAll()
        public
        returns (
            BN254SignatureScheme bn254SignatureScheme,
            RandomnessSender randomnessSenderInstance,
            SignatureSchemeAddressProvider signatureSchemeAddressProvider,
            SignatureSender signatureSenderInstance
        )
    {
        // for upgrades, run deployment script for individual contract in single-deployments
        bool isUpgrade = false;
        // signature scheme address provider
        signatureSchemeAddressProvider = deploySignatureSchemeAddressProvider();
        // signature schemes
        bn254SignatureScheme = deployBN254SignatureScheme();
        // signature sender
        signatureSenderInstance = deploySignatureSenderProxy(address(signatureSchemeAddressProvider), isUpgrade);
        // randomness sender
        randomnessSenderInstance = deployRandomnessSenderProxy(address(signatureSenderInstance), isUpgrade);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console} from "forge-std/Test.sol";

import {TypesLib, BLS} from "./Deployment.t.sol";

import {
    Deployment,
    SignatureSchemeAddressProvider,
    RandomnessSender,
    SignatureSender,
    BN254SignatureScheme,
    MockRandomnessReceiver
} from "./Deployment.t.sol";

contract RandomnessTest is Deployment {
    SignatureSchemeAddressProvider internal signatureSchemeAddressProvider;
    BN254SignatureScheme internal bn254SignatureScheme;
    SignatureSender internal signatureSender;
    RandomnessSender internal randomnessSender;
    MockRandomnessReceiver internal mockRandomnessReceiver;

    function setUp() public override {
        // setup base test
        super.setUp();

        (signatureSchemeAddressProvider, bn254SignatureScheme, randomnessSender, signatureSender) = deployContracts();

        mockRandomnessReceiver = deployAndFundReceiverWithDirectFunding(admin, address(randomnessSender), 1 ether);
    }

    function test_Deployment_Configurations() public view {
        assertTrue(randomnessSender.hasRole(ADMIN_ROLE, admin));
        assertTrue(signatureSender.hasRole(ADMIN_ROLE, admin));

        assert(address(signatureSchemeAddressProvider) != address(0));
        assert(address(bn254SignatureScheme) != address(0));
        assert(address(signatureSender) != address(0));
        assert(address(randomnessSender) != address(0));
        assert(address(mockRandomnessReceiver) != address(0));
        assert(address(signatureSender.signatureSchemeAddressProvider()) != address(0));

        console.logBytes(bn254SignatureScheme.DST());
        console.logString(string(bn254SignatureScheme.DST()));
    }
}

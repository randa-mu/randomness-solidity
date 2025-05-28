// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {console} from "forge-std/Test.sol";

import {TypesLib, BLS} from "./Deployment.t.sol";

import {Randomness} from "../../../src/randomness/Randomness.sol";

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

        mockRandomnessReceiver = deployRandomnessReceiver(alice, address(randomnessSender));
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

    function test_Update_SignatureScheme() public {
        // non-zero address with zero code
        string memory bn254_schemeID = "BN255";
        address schemeAddr = makeAddr(bn254_schemeID);
        assertTrue(schemeAddr != address(0), "schemeAddr should not be zero address");
        assertTrue(schemeAddr.code.length == 0, "schemeAddr should not have any code");
        vm.prank(admin);
        vm.expectRevert("Invalid contract address for schemeAddress");
        signatureSchemeAddressProvider.updateSignatureScheme(bn254_schemeID, schemeAddr);

        // non-zero address with non-zero code
        schemeAddr = address(bn254SignatureScheme);
        assertTrue(schemeAddr != address(0), "schemeAddr address should not be zero address");
        assertTrue(schemeAddr.code.length > 0, "schemeAddr address should have code");
        vm.prank(admin);
        signatureSchemeAddressProvider.updateSignatureScheme(bn254_schemeID, schemeAddr);
        assertTrue(signatureSchemeAddressProvider.getSignatureSchemeAddress(bn254_schemeID) == schemeAddr);

        // replacing existing scheme contract reverts
        schemeAddr = address(randomnessSender);
        vm.prank(admin);
        vm.expectRevert("Scheme already added for schemeID");
        signatureSchemeAddressProvider.updateSignatureScheme(bn254_schemeID, schemeAddr);
        assertTrue(
            signatureSchemeAddressProvider.getSignatureSchemeAddress(bn254_schemeID) != schemeAddr,
            "Scheme contract address should not have been replaced"
        );

        // zero address with zero code
        vm.prank(admin);
        vm.expectRevert("Invalid contract address for schemeAddress");
        signatureSchemeAddressProvider.updateSignatureScheme(bn254_schemeID, address(0));
    }

    // Randomness library tests
    function test_SelectArrayIndices_Zero_returnsEmpty() public pure {
        uint256[] memory expected = new uint256[](0);
        uint256[] memory actual = Randomness.selectArrayIndices(0, 1, hex"deadbeef");
        assertEq(expected, actual, "array was not empty");
    }

    function test_SelectArrayIndices_One_returnsAll() public pure {
        uint256[] memory expected = new uint256[](1);
        expected[0] = uint256(0);
        uint256[] memory actual = Randomness.selectArrayIndices(1, 1, hex"deadbeef");
        assertEq(expected, actual, "full array wasn't returned");
    }

    function test_selectArrayIndices_ReturnsCorrectCount() public pure {
        uint256 countToDraw = 10;
        uint256 arrLength = 100;
        uint256[] memory actual = Randomness.selectArrayIndices(arrLength, countToDraw, hex"deadbeef");
        assertEq(actual.length, countToDraw, "array return didn't have the right count");
        for (uint256 i = 0; i < actual.length; i++) {
            assert(i <= arrLength);
        }
    }

    function test_Randomness_SignatureVerification() public view {
        address requester = address(10);
        uint256 requestID = 1;
        bool passedVerificationCheck = Randomness.verify(
            address(randomnessSender),
            address(signatureSender),
            validSignature,
            requestID,
            requester,
            bn254SignatureSchemeID
        );
        assertTrue(passedVerificationCheck, "Signature verification failed");
        console.logBool(passedVerificationCheck);
    }
}

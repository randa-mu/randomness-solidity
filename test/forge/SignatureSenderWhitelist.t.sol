// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std-1.10.0/Test.sol";
import {SignatureSender} from "../../src/signature-requests/SignatureSender.sol";
import {UUPSProxy} from "../../src/proxy/UUPSProxy.sol";
import {TypesLib} from "../../src/libraries/TypesLib.sol";

/// @notice Minimal mock of ISignatureScheme used by SignatureSender tests.
contract MockSignatureScheme {
    // emulate hashToBytes: return keccak256(message) as bytes
    function hashToBytes(bytes calldata message) external pure returns (bytes memory) {
        bytes32 h = keccak256(message);
        return abi.encodePacked(h);
    }

    // verifySignature: for testing accept any signature that is not empty OR accept everything
    function verifySignature(bytes calldata /*messageHash*/, bytes calldata /*signature*/)
        external
        pure
        returns (bool)
    {
        return true;
    }
}

/// @notice Minimal mock of ISignatureSchemeAddressProvider used by SignatureSender tests.
contract MockSignatureSchemeAddressProvider {
    // map schemeID (string) to a contract address and supported flag
    mapping(string => address) internal addrs;
    mapping(string => bool) internal supported;

    function setScheme(string calldata schemeID, address schemeAddress, bool isSupported) external {
        addrs[schemeID] = schemeAddress;
        supported[schemeID] = isSupported;
    }

    function isSupportedScheme(string calldata schemeID) external view returns (bool) {
        return supported[schemeID];
    }

    function getSignatureSchemeAddress(string calldata schemeID) external view returns (address) {
        return addrs[schemeID];
    }
}

/// @title Tests for the whitelist part of SignatureSender
contract SignatureSenderWhitelistTest is Test {
    SignatureSender public sender;
    MockSignatureScheme public mockScheme;
    MockSignatureSchemeAddressProvider public mockProvider;

    // addresses used in tests
    // For test clarity, both owner and admin are set to the same address.
    address owner = address(0xABCD);
    address admin = address(0xABCD); // same as owner for clarity
    address whitelisted = address(0x1111);
    address notWhitelisted = address(0x2222);
    address randomCaller = address(0x3333);
    string public constant TEST_SCHEME = "TEST";

    // role constants imported from the contract to avoid drift
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SIGNATURE_REQUESTER_ROLE = keccak256("SIGNATURE_REQUESTER_ROLE");

    function setUp() public {
        // deploy mocks
        mockScheme = new MockSignatureScheme();
        mockProvider = new MockSignatureSchemeAddressProvider();

        // map TEST scheme to mock scheme in provider and mark supported
        mockProvider.setScheme(TEST_SCHEME, address(mockScheme), true);

        // deploy the SignatureSender and initialize
        SignatureSender signatureSenderImplementationV1 = new SignatureSender();
        UUPSProxy signatureSenderProxy = new UUPSProxy(address(signatureSenderImplementationV1), "");

        sender = SignatureSender(address(signatureSenderProxy));

        // call initialize as owner
        vm.prank(owner);
        sender.initialize(owner, address(mockProvider));
    }

    /// @notice Basic sanity: owner got ADMIN_ROLE in initialize
    function testOwnerHasAdminRole() public {
        bool has = sender.hasRole(ADMIN_ROLE, owner);
        assertTrue(has, "owner should have ADMIN_ROLE after initialize");
    }

    /// @notice Only admin can add to whitelist
    function testAddToWhitelistByAdmin() public {
        // admin adds 'whitelisted'
        vm.prank(admin);
        sender.addToWhitelist(whitelisted);

        bool isWL = sender.isWhitelisted(whitelisted);
        assertTrue(isWL, "address should be whitelisted after addToWhitelist");
    }

    /// @notice Non-admin cannot add to whitelist
    function testAddToWhitelistByNonAdminReverts() public {
        vm.prank(notWhitelisted);

        // expect revert due to AccessControl (no ADMIN_ROLE)
        vm.expectRevert();
        sender.addToWhitelist(whitelisted);
    }

    /// @notice removeFromWhitelist works and only admin can call it
    function testRemoveFromWhitelistByAdmin() public {
        // first add from admin
        vm.prank(admin);
        sender.addToWhitelist(whitelisted);
        assertTrue(sender.isWhitelisted(whitelisted), "precondition: whitelisted must be true");

        // now remove
        vm.prank(admin);
        sender.removeFromWhitelist(whitelisted);

        assertFalse(sender.isWhitelisted(whitelisted), "should not be whitelisted after remove");
    }

    function testRemoveFromWhitelistByNonAdminReverts() public {
        // admin adds first
        vm.prank(admin);
        sender.addToWhitelist(whitelisted);
        assertTrue(sender.isWhitelisted(whitelisted));

        // non-admin tries to remove -> revert
        vm.prank(notWhitelisted);
        vm.expectRevert();
        sender.removeFromWhitelist(whitelisted);
    }

    /// @notice Whitelisted address can call requestSignature; non-whitelisted cannot.
    function testWhitelistedCanRequestSignatureAndCreatesRequest() public {
        // admin whitelists `whitelisted`
        vm.prank(admin);
        sender.addToWhitelist(whitelisted);
        assertTrue(sender.isWhitelisted(whitelisted));

        // craft message and condition
        bytes memory message = "hello world";
        bytes memory condition = ""; // optional
        string memory schemeID = TEST_SCHEME;

        // Call requestSignature from whitelisted address
        vm.prank(whitelisted);
        uint256 requestId = sender.requestSignature(schemeID, message, condition);

        // requestId should be 1 (first request)
        assertEq(requestId, 1);

        // fetch request and assert fields
        TypesLib.SignatureRequest memory req = sender.getRequest(requestId);
        assertEq(req.callback, whitelisted, "callback should be caller");
        // message stored should equal the message we passed
        assertEq(string(req.message), string(message));
        assertEq(req.schemeID, schemeID);

        // check unfulfilled request count and in-flight status
        uint256[] memory unfulfilled = sender.getAllUnfulfilledRequestIds();
        assertEq(unfulfilled.length, 1, "there should be one unfulfilled request");
        assertTrue(sender.isInFlight(requestId), "request should be in flight");
    }

    function testNonWhitelistedCannotRequestSignature() public {
        bytes memory message = "hello";
        bytes memory condition = "";
        string memory schemeID = TEST_SCHEME;

        // notWhitelisted has no role -> expect revert by onlyWhitelistedRequester modifier
        vm.prank(notWhitelisted);
        vm.expectRevert();
        sender.requestSignature(schemeID, message, condition);
    }

    /// @notice If addToWhitelist is called twice, hasRole remains true (idempotent)
    function testAddToWhitelistIdempotent() public {
        vm.prank(admin);
        sender.addToWhitelist(whitelisted);
        assertTrue(sender.isWhitelisted(whitelisted));

        vm.prank(admin);
        // adding again shouldn't revert
        sender.addToWhitelist(whitelisted);
        assertTrue(sender.isWhitelisted(whitelisted));
    }
}

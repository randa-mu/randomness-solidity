// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {AccessControlEnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {BLS} from "../libraries/BLS.sol";
import {TypesLib} from "../libraries/TypesLib.sol";
import {BytesLib} from "../libraries/BytesLib.sol";

import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {ISignatureReceiver} from "../interfaces/ISignatureReceiver.sol";
import {ISignatureSender} from "../interfaces/ISignatureSender.sol";
import {ISignatureScheme} from "../interfaces/ISignatureScheme.sol";
import {ISignatureSchemeAddressProvider} from "../interfaces/ISignatureSchemeAddressProvider.sol";

/// @title SignatureSender contract
/// @author Randamu
/// @notice Smart Contract for Conditional Threshold Signing of messages sent within signature requests.
/// @dev Signatures are sent in callbacks to contract addresses implementing the SignatureReceiverBase abstract contract which implements the ISignatureReceiver interface.
contract SignatureSender is
    ISignatureSender,
    Multicall,
    Initializable,
    UUPSUpgradeable,
    AccessControlEnumerableUpgradeable
{
    using BytesLib for bytes;
    using EnumerableSet for EnumerableSet.UintSet;

    /// @notice Role identifier for the admin role.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Last used request ID.
    uint256 public lastRequestID = 0;

    /// @notice Mapping from request IDs to signature request structs.
    mapping(uint256 => TypesLib.SignatureRequest) public requests;

    /// @notice Address provider for signature schemes.
    ISignatureSchemeAddressProvider public signatureSchemeAddressProvider;

    /// @dev Set for storing unique fulfilled request Ids
    EnumerableSet.UintSet private fulfilledRequestIds;

    /// @dev Set for storing unique unfulfilled request Ids
    EnumerableSet.UintSet private unfulfilledRequestIds;

    /// @dev Set for storing unique request Ids with failing callbacks
    /// @dev Callbacks can fail if collection of request fee from
    ///      subscription account fails in `_handlePaymentAndCharge` function call.
    ///      We use `_callWithExactGasEvenIfTargetIsNoContract` function for callback so it works if
    ///      caller does not implement the interface.
    EnumerableSet.UintSet private erroredRequestIds;

    /// @notice Emitted when the signature scheme address provider is updated.
    event SignatureSchemeAddressProviderUpdated(address indexed newSignatureSchemeAddressProvider);

    /// @notice Emitted when a new signature request is created.
    event SignatureRequested(
        uint256 indexed requestID,
        address indexed callback,
        string schemeID,
        bytes message,
        bytes messageHashToSign,
        bytes condition,
        uint256 requestedAt
    );

    /// @notice Emitted when a signature request is fulfilled.
    event SignatureRequestFulfilled(uint256 indexed requestID, bytes signature);

    /// @notice Emitted when a signature callback fails.
    event SignatureCallbackFailed(uint256 indexed requestID);

    /// @notice Ensures that only an account with the ADMIN_ROLE can execute a function.
    modifier onlyAdmin() {
        _checkRole(ADMIN_ROLE);
        _;
    }

    /// @dev Constructor disables initializers.
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with the given parameters.
    function initialize(address owner, address _signatureSchemeAddressProvider) public initializer {
        __UUPSUpgradeable_init();
        __AccessControlEnumerable_init();

        require(_grantRole(ADMIN_ROLE, owner), "Grant role failed");
        require(_grantRole(DEFAULT_ADMIN_ROLE, owner), "Grant role reverts");
        signatureSchemeAddressProvider = ISignatureSchemeAddressProvider(_signatureSchemeAddressProvider);
    }

    // OVERRIDDEN UPGRADE FUNCTIONS
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    function _msgSender() internal view override (Context, ContextUpgradeable) returns (address) {
        return msg.sender;
    }

    function _msgData() internal pure override (Context, ContextUpgradeable) returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal pure override (Context, ContextUpgradeable) returns (uint256) {
        return 0;
    }

    /// @notice Requests a new signature.
    /// @dev See {ISignatureSender-requestSignature}.
    function requestSignature(string calldata schemeID, bytes calldata message, bytes calldata condition)
        external
        returns (uint256)
    {
        lastRequestID += 1;

        require(signatureSchemeAddressProvider.isSupportedScheme(schemeID), "Signature scheme not supported");
        require(message.isLengthWithinBounds(1, 4096), "Message failed length bounds check");
        // condition is optional
        require(condition.isLengthWithinBounds(0, 4096), "Condition failed length bounds check");
        uint256 conditionLength = condition.length;
        if (conditionLength > 0) {
            require(!condition.isAllZero(), "Condition bytes cannot be all zeros");
        }

        address schemeContractAddress = signatureSchemeAddressProvider.getSignatureSchemeAddress(schemeID);
        ISignatureScheme sigScheme = ISignatureScheme(schemeContractAddress);
        bytes memory messageHash = sigScheme.hashToBytes(message);

        requests[lastRequestID] = TypesLib.SignatureRequest({
            callback: msg.sender,
            message: message,
            messageHash: messageHash,
            condition: condition,
            schemeID: schemeID,
            signature: hex"",
            isFulfilled: false
        });

        unfulfilledRequestIds.add(lastRequestID);

        emit SignatureRequested(lastRequestID, msg.sender, schemeID, message, messageHash, condition, block.timestamp);

        return lastRequestID;
    }

    /// @notice Fulfils a unique signature request.
    /// @dev See {ISignatureSender-fulfillSignatureRequest}.
    function fulfillSignatureRequest(uint256 requestID, bytes calldata signature) external {
        require(isInFlight(requestID), "No request with specified requestID");
        TypesLib.SignatureRequest memory request = requests[requestID];

        string memory schemeID = request.schemeID;
        address schemeContractAddress = signatureSchemeAddressProvider.getSignatureSchemeAddress(schemeID);
        ISignatureScheme sigScheme = ISignatureScheme(schemeContractAddress);

        require(
            sigScheme.verifySignature(request.messageHash, signature, sigScheme.getPublicKeyBytes()),
            "Signature verification failed"
        );

        (bool success,) = request.callback.call(
            abi.encodeWithSelector(ISignatureReceiver.receiveSignature.selector, requestID, signature)
        );

        requests[requestID].isFulfilled = true;
        unfulfilledRequestIds.remove(requestID);

        if (!success) {
            erroredRequestIds.add(requestID);
            emit SignatureCallbackFailed(requestID);
        } else {
            if (hasErrored(requestID)) {
                erroredRequestIds.remove(requestID);
            }
            fulfilledRequestIds.add(requestID);
            emit SignatureRequestFulfilled(requestID, signature);
        }
    }

    /// @notice Sets the signature scheme address provider contract address.
    function setSignatureSchemeAddressProvider(address newSignatureSchemeAddressProvider) external onlyAdmin {
        signatureSchemeAddressProvider = ISignatureSchemeAddressProvider(newSignatureSchemeAddressProvider);
        emit SignatureSchemeAddressProviderUpdated(newSignatureSchemeAddressProvider);
    }

    /// @notice Checks if a request is in flight.
    /// @dev See {ISignatureSender-isInFlight}.
    function isInFlight(uint256 requestID) public view returns (bool) {
        return unfulfilledRequestIds.contains(requestID) || erroredRequestIds.contains(requestID);
    }

    /// @notice Checks if a callback for a request id reverted
    function hasErrored(uint256 requestID) public view returns (bool) {
        return erroredRequestIds.contains(requestID);
    }

    /// @notice Returns a request given a request id.
    /// @dev See {ISignatureSender-getRequestInFlight}.
    function getRequest(uint256 requestID) external view returns (TypesLib.SignatureRequest memory) {
        return requests[requestID];
    }

    /// @notice Returns all fulfilled request ids
    function getAllFulfilledRequestIds() external view returns (uint256[] memory) {
        return fulfilledRequestIds.values();
    }

    /// @notice Returns all unfulfilled request ids
    function getAllUnfulfilledRequestIds() external view returns (uint256[] memory) {
        return unfulfilledRequestIds.values();
    }

    /// @notice Returns all request ids where the last executed callback has reverted
    function getAllErroredRequestIds() external view returns (uint256[] memory) {
        return erroredRequestIds.values();
    }

    /// @notice Returns a count of the unfulfilled request ids
    function getCountOfUnfulfilledRequestIds() external view returns (uint256) {
        return unfulfilledRequestIds.length();
    }

    /// @notice Returns the version number of the upgradeable contract.
    function version() external pure returns (string memory) {
        return "0.0.1";
    }
}

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

/// @notice Smart Contract for Conditional Threshold Signing of messages sent within signature requests.
/// @notice Signatures are sent in callbacks to contract addresses implementing the SignatureReceiverBase abstract contract which implements the ISignatureReceiver interface.
/// @notice Signature requests can also be made for requests requiring immediate signing of messages as the conditions are optional.
contract SignatureSender is
    ISignatureSender,
    Multicall,
    Initializable,
    UUPSUpgradeable,
    AccessControlEnumerableUpgradeable
{
    using BytesLib for bytes;
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public lastRequestID = 0;
    BLS.PointG2 private publicKey = BLS.PointG2({x: [uint256(0), uint256(0)], y: [uint256(0), uint256(0)]});
    // mapping request ids to signature request structs
    mapping(uint256 => TypesLib.SignatureRequest) public requests;

    ISignatureSchemeAddressProvider public signatureSchemeAddressProvider;

    EnumerableSet.UintSet private fulfilledRequestIds;
    EnumerableSet.UintSet private unfulfilledRequestIds;
    EnumerableSet.UintSet private erroredRequestIds;

    event SignatureSchemeAddressProviderUpdated(address indexed newSignatureSchemeAddressProvider);
    event SignatureRequested(
        uint256 indexed requestID,
        address indexed callback,
        string schemeID,
        bytes message,
        bytes messageHashToSign,
        bytes condition,
        uint256 requestedAt
    );
    event SignatureRequestFulfilled(uint256 indexed requestID, bytes signature);
    event SignatureCallbackFailed(uint256 requestID);

    modifier onlyOwner() {
        _checkRole(ADMIN_ROLE);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        uint256[2] memory x,
        uint256[2] memory y,
        address owner,
        address _signatureSchemeAddressProvider
    ) public initializer {
        __UUPSUpgradeable_init();
        __AccessControlEnumerable_init();

        publicKey = BLS.PointG2({x: x, y: y});
        require(_grantRole(ADMIN_ROLE, owner), "Grant role failed");
        require(_grantRole(DEFAULT_ADMIN_ROLE, owner), "Grant role reverts");
        require(
            _signatureSchemeAddressProvider != address(0),
            "Cannot set zero address as signature scheme address provider"
        );
        signatureSchemeAddressProvider = ISignatureSchemeAddressProvider(_signatureSchemeAddressProvider);
    }

    // OVERRIDDEN UPGRADE FUNCTIONS
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function _msgSender() internal view override(Context, ContextUpgradeable) returns (address) {
        return msg.sender;
    }

    function _msgData() internal pure override(Context, ContextUpgradeable) returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal pure override(Context, ContextUpgradeable) returns (uint256) {
        return 0;
    }

    /**
     * @dev See {ISignatureSender-requestSignature}.
     */
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

    /**
     * @dev See {ISignatureSender-fulfilSignatureRequest}.
     */
    function fulfilSignatureRequest(uint256 requestID, bytes calldata signature) external onlyOwner {
        require(isInFlight(requestID), "No request with specified requestID");
        TypesLib.SignatureRequest memory request = requests[requestID];

        string memory schemeID = request.schemeID;

        address schemeContractAddress = signatureSchemeAddressProvider.getSignatureSchemeAddress(schemeID);
        ISignatureScheme sigScheme = ISignatureScheme(schemeContractAddress);

        require(
            sigScheme.verifySignature(request.messageHash, signature, getPublicKeyBytes()),
            "Signature verification failed"
        );

        (bool success,) = request.callback.call(
            abi.encodeWithSelector(ISignatureReceiver.receiveSignature.selector, requestID, signature)
        );

        requests[requestID].signature = signature;
        requests[requestID].isFulfilled = true;

        unfulfilledRequestIds.remove(requestID);

        if (!success) {
            erroredRequestIds.add(requestID);
            emit SignatureCallbackFailed(requestID);
        } else {
            fulfilledRequestIds.add(requestID);
            emit SignatureRequestFulfilled(requestID, signature);
        }
    }

    function retryCallback(uint256 requestID) external {
        require(hasErrored(requestID), "No request with specified requestID has errored");
        TypesLib.SignatureRequest memory request = requests[requestID];

        (bool success,) = request.callback.call(
            abi.encodeWithSelector(ISignatureReceiver.receiveSignature.selector, requestID, request.signature)
        );

        if (!success) {
            emit SignatureCallbackFailed(requestID);
        } else {
            erroredRequestIds.remove(requestID);
            fulfilledRequestIds.add(requestID);
            emit SignatureRequestFulfilled(requestID, request.signature);
        }
    }

    function setSignatureSchemeAddressProvider(address newSignatureSchemeAddressProvider) external onlyOwner {
        signatureSchemeAddressProvider = ISignatureSchemeAddressProvider(newSignatureSchemeAddressProvider);
        emit SignatureSchemeAddressProviderUpdated(newSignatureSchemeAddressProvider);
    }

    /**
     * @dev See {ISignatureSender-getPublicKey}.
     */
    function getPublicKey() public view returns (uint256[2] memory, uint256[2] memory) {
        return (publicKey.x, publicKey.y);
    }

    /**
     * @dev See {ISignatureSender-getPublicKeyBytes}.
     */
    function getPublicKeyBytes() public view returns (bytes memory) {
        return BLS.g2Marshal(publicKey);
    }

    /**
     * @dev See {ISignatureSender-isInFlight}.
     */
    function isInFlight(uint256 requestID) public view returns (bool) {
        return unfulfilledRequestIds.contains(requestID) || erroredRequestIds.contains(requestID);
    }

    function hasErrored(uint256 requestID) public view returns (bool) {
        return erroredRequestIds.contains(requestID);
    }

    /**
     * @dev See {ISignatureSender-getRequestInFlight}.
     */
    function getRequest(uint256 requestID) external view returns (TypesLib.SignatureRequest memory) {
        return requests[requestID];
    }

    function getAllFulfilledRequestIds() external view returns (uint256[] memory) {
        return fulfilledRequestIds.values();
    }

    function getAllUnfulfilledRequestIds() external view returns (uint256[] memory) {
        return unfulfilledRequestIds.values();
    }

    function getAllErroredRequestIds() external view returns (uint256[] memory) {
        return erroredRequestIds.values();
    }

    function getCountOfUnfulfilledRequestIds() external view returns (uint256) {
        return unfulfilledRequestIds.length();
    }

    /**
     * @dev Returns the version number of the upgradeable contract.
     */
    function version() external pure returns (string memory) {
        return "0.0.1";
    }
}

/// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {AccessControlEnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {TypesLib} from "../libraries/TypesLib.sol";

import {IRandomnessReceiver} from "../interfaces/IRandomnessReceiver.sol";
import {IRandomnessSender} from "../interfaces/IRandomnessSender.sol";
import {ISignatureSender} from "../interfaces/ISignatureSender.sol";

import {SignatureReceiverBase} from "../signature-requests/SignatureReceiverBase.sol";

/// @title RandomnessSender contract
/// @author Randamu
/// @notice Handles randomness requests from user's contracts and
/// forwards the randomness to them via a callback to the `receiveRandomness(...)` function.
contract RandomnessSender is
    IRandomnessSender,
    SignatureReceiverBase,
    Initializable,
    UUPSUpgradeable,
    AccessControlEnumerableUpgradeable
{
    /// @notice The domain separation tag (DST) used for randomness requests.
    string public constant DST = "randomness:0.0.1:bn254";
    /// @notice The identifier for the signature scheme used.
    string public constant SCHEME_ID = "BN254";
    /// @notice Role identifier for the contract administrator.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Internal nonce used to track randomness requests.
    uint256 public nonce = 0;

    /// @notice Mapping from randomness request ID to request details.
    mapping(uint256 => TypesLib.RandomnessRequest) private callbacks;
    /// @notice Array of all randomness requests.
    TypesLib.RandomnessRequest[] private allRequests;

    /// @notice Emitted when a randomness request is initiated.
    event RandomnessRequested(
        uint256 indexed requestID, uint256 indexed nonce, address indexed requester, uint256 requestedAt
    );
    /// @notice Emitted when a randomness callback is successfully processed.
    event RandomnessCallbackSuccess(uint256 indexed requestID, bytes32 randomness, bytes signature);
    /// @notice Emitted when the signature sender address is updated.
    event SignatureSenderUpdated(address indexed signatureSender);

    /// @notice Thrown when a randomness callback fails.
    error RandomnessCallbackFailed(uint256 requestID);

    /// @notice Ensures that only an account with the ADMIN_ROLE can execute a function.
    modifier onlyAdmin() {
        _checkRole(ADMIN_ROLE);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with a signature sender and owner.
    function initialize(address _signatureSender, address owner) public initializer {
        __UUPSUpgradeable_init();
        __AccessControlEnumerable_init();

        require(_grantRole(ADMIN_ROLE, owner), "Grant role failed");
        require(_grantRole(DEFAULT_ADMIN_ROLE, owner), "Grant role failed");

        require(_signatureSender != address(0), "Cannot set zero address as signature sender");
        signatureSender = ISignatureSender(_signatureSender);
    }

    /// @notice Authorizes contract upgrades.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /// @notice Requests randomness and returns a request ID.
    function requestRandomness() external returns (uint256 requestID) {
        nonce += 1;

        TypesLib.RandomnessRequest memory r = TypesLib.RandomnessRequest({nonce: nonce, callback: msg.sender});
        bytes memory m = messageFrom(r);
        bytes memory conditions = hex"";

        requestID = signatureSender.requestSignature(SCHEME_ID, m, conditions);

        callbacks[requestID] = r;
        allRequests.push(r);

        emit RandomnessRequested(requestID, nonce, msg.sender, block.timestamp);
    }

    /// @notice Processes a received signature and invokes the callback.
    function onSignatureReceived(uint256 requestID, bytes calldata signature) internal override {
        TypesLib.RandomnessRequest memory r = callbacks[requestID];
        require(r.nonce > 0, "Request with that requestID did not exist");

        bytes32 randomness = keccak256(signature);

        (bool success,) = r.callback.call(
            abi.encodeWithSelector(IRandomnessReceiver.receiveRandomness.selector, requestID, randomness)
        );
        if (!success) {
            revert RandomnessCallbackFailed(requestID);
        } else {
            emit RandomnessCallbackSuccess(requestID, randomness, signature);
        }
    }

    /// @notice Updates the signature sender address.
    function setSignatureSender(address newSignatureSender) external onlyAdmin {
        signatureSender = ISignatureSender(newSignatureSender);
        emit SignatureSenderUpdated(newSignatureSender);
    }

    /// @notice Checks if a request is still in flight.
    function isInFlight(uint256 requestID) external view returns (bool) {
        return signatureSender.isInFlight(requestID);
    }

    /// @notice Generates a message from a randomness request.
    function messageFrom(TypesLib.RandomnessRequest memory r) public pure returns (bytes memory) {
        return abi.encodePacked(keccak256(abi.encode(DST, r.nonce)));
    }

    /// @notice Retrieves a randomness request by ID.
    function getRequest(uint256 requestId) external view returns (TypesLib.RandomnessRequest memory) {
        return callbacks[requestId];
    }

    /// @notice Retrieves all randomness requests.
    function getAllRequests() external view returns (TypesLib.RandomnessRequest[] memory) {
        return allRequests;
    }

    /// @notice Returns the contract version.
    function version() external pure returns (string memory) {
        return "0.0.1";
    }
}

// SPDX-License-Identifier: MIT
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

contract RandomnessSender is
    IRandomnessSender,
    SignatureReceiverBase,
    Initializable,
    UUPSUpgradeable,
    AccessControlEnumerableUpgradeable
{
    // the DST is used to separate randomness being used as signatures for other things
    string public constant DST = "randomness:0.0.1:bn254";
    string public constant SCHEME_ID = "BN254";
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public nonce = 0;

    // Mapping from randomness requestID to callbacks
    mapping(uint256 => TypesLib.RandomnessRequest) private callbacks;
    // array of all requests
    TypesLib.RandomnessRequest[] private allRequests;

    event RandomnessRequested(
        uint256 indexed requestID, uint256 indexed nonce, address indexed requester, uint256 requestedAt
    );
    event RandomnessCallbackSuccess(uint256 indexed requestID, bytes32 randomness, bytes signature);
    event SignatureSenderUpdated(address indexed signatureSender);

    error RandomnessCallbackFailed(uint256 requestID);

    modifier onlyOwner() {
        _checkRole(ADMIN_ROLE);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _signatureSender, address owner) public initializer {
        __UUPSUpgradeable_init();
        __AccessControlEnumerable_init();

        require(_grantRole(ADMIN_ROLE, owner), "Grant role failed");
        require(_grantRole(DEFAULT_ADMIN_ROLE, owner), "Grant role failed");

        require(_signatureSender != address(0), "Cannot set zero address as signature sender");
        signatureSender = ISignatureSender(_signatureSender);
    }

    // OVERRIDDEN UPGRADE FUNCTIONS
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev See {IRandomnessSender-requestRandomness}.
     */
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

    /**
     * @dev See {SignatureReceiverBase-onSignatureReceived}.
     */
    function onSignatureReceived(uint256 requestID, bytes calldata signature) internal override {
        TypesLib.RandomnessRequest memory r = callbacks[requestID];
        require(r.nonce > 0, "request with that requestID did not exist");

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

    /**
     * @dev See {IRandomnessSender-setSignatureSender}.
     */
    function setSignatureSender(address newSignatureSender) external onlyOwner {
        signatureSender = ISignatureSender(newSignatureSender);
        emit SignatureSenderUpdated(newSignatureSender);
    }

    /**
     * @dev See {ISignatureSender-isInFlight}.
     */
    function isInFlight(uint256 requestID) external view returns (bool) {
        return signatureSender.isInFlight(requestID);
    }

    /**
     * @dev See {IRandomnessSender-messageFrom}.
     */
    function messageFrom(TypesLib.RandomnessRequest memory r) public pure returns (bytes memory) {
        return abi.encodePacked(keccak256(abi.encode(DST, r.nonce)));
    }

    /**
     * @dev See {IRandomnessSender-getRequest}.
     */
    function getRequest(uint256 requestId) external view returns (TypesLib.RandomnessRequest memory) {
        return callbacks[requestId];
    }

    /**
     * @dev See {IRandomnessSender-getAllRequests}.
     */
    function getAllRequests() external view returns (TypesLib.RandomnessRequest[] memory) {
        return allRequests;
    }

    /**
     * @dev Returns the version number of the upgradeable contract.
     */
    function version() external pure returns (string memory) {
        return "0.0.1";
    }
}

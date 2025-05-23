// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {RandomnessReceiverBase} from "../RandomnessReceiverBase.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
// solhint-disable-next-line no-unused-import
import {
    IVRFCoordinatorV2Plus,
    IVRFSubscriptionV2Plus
} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";

/**
 * @dev Partial implementation of Chainlink's `VRFCoordinatorV2_5` with no-ops and dummy values for the methods RandamuVRF does not need.
 */

// solhint-disable-next-line contract-name-camelcase
contract ChainlinkVRFCoordinatorV2_5Adapter is ReentrancyGuard, RandomnessReceiverBase, IVRFCoordinatorV2Plus {
    uint16 public constant MAX_REQUEST_CONFIRMATIONS = 200;
    uint32 public constant MAX_NUM_WORDS = 1;
    uint8 private constant PREMIUM_PERCENTAGE_MAX = 155;

    event WrapperFulfillmentFailed(uint256 indexed requestId, address indexed consumer);

    uint256 public lastRequestId;

    // The cost for this gas is billed to the callback contract / caller, and must therefor be included
    // in the pricing for wrapped requests.
    // s_wrapperGasOverhead reflects the gas overhead of the wrapper's fulfillRandomWords
    // function. The cost for this gas is passed to the user.
    uint32 private s_wrapperGasOverhead;

    struct Callback {
        address callbackAddress;
        uint32 callbackGasLimit;
        // Reducing requestGasPrice from uint256 to uint64 slots Callback struct
        // into a single word, thus saving an entire SSTORE and leading to 21K
        // gas cost saving. 18 ETH would be the max gas price we can process.
        // GasPrice is unlikely to be more than 14 ETH on most chains
        uint64 requestGasPrice;
    }

    mapping(uint256 => Callback) /* requestID */ /* callback */ public s_callbacks;

    constructor(address randomnessSender, uint32 _s_wrapperGasOverhead) RandomnessReceiverBase(randomnessSender) {
        s_wrapperGasOverhead = _s_wrapperGasOverhead;
    }

    function setWrapperGasOverhead(uint32 _s_wrapperGasOverhead) external onlyOwner {
        s_wrapperGasOverhead = _s_wrapperGasOverhead;
    }

    /**
     * @notice Request a set of random words.
     * @param req - a struct containing following fiels for randomness request:
     * keyHash - Corresponds to a particular oracle job which uses
     * that key for generating the VRF proof. Different keyHash's have different gas price
     * ceilings, so you can select a specific one to bound your maximum per request cost.
     * subId  - The ID of the VRF subscription. Must be funded
     * with the minimum subscription balance required for the selected keyHash.
     * requestConfirmations - How many blocks you'd like the
     * oracle to wait before responding to the request. See SECURITY CONSIDERATIONS
     * for why you may want to request more. The acceptable range is
     * [minimumRequestBlockConfirmations, 200].
     * callbackGasLimit - How much gas you'd like to receive in your
     * fulfillRandomWords callback. Note that gasleft() inside fulfillRandomWords
     * may be slightly less than this amount because of gas used calling the function
     * (argument decoding etc.), so you may need to request slightly more than you expect
     * to have inside fulfillRandomWords. The acceptable range is
     * [0, maxGasLimit]
     * numWords - The number of uint256 random values you'd like to receive
     * in your fulfillRandomWords callback. Note these numbers are expanded in a
     * secure way by the VRFCoordinator from a single random value supplied by the oracle.
     * extraArgs - Encoded extra arguments that has a boolean flag for whether payment
     * should be made in native or LINK. Payment in LINK is only available if the LINK token is available to this contract.
     * @return requestId - A unique identifier of the request. Can be used to match
     * a request to a response in fulfillRandomWords.
     */
    function requestRandomWords(VRFV2PlusClient.RandomWordsRequest calldata req)
        external
        override
        nonReentrant
        returns (uint256 requestId)
    {
        requestId = _requestRandomnessWithSubscription(req.callbackGasLimit);

        s_callbacks[requestId] = Callback({
            callbackAddress: msg.sender,
            callbackGasLimit: req.callbackGasLimit,
            requestGasPrice: uint64(tx.gasprice)
        });
        lastRequestId = requestId;

        return requestId;
    }

    function convertBytes32ToUint256Array(bytes32 randomness, uint256 count) internal pure returns (uint256[] memory) {
        uint256[] memory randomWords = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            randomWords[i] = uint256(keccak256(abi.encodePacked(randomness, i)));
        }
        return randomWords;
    }

    function onRandomnessReceived(uint256 requestID, bytes32 randomness) internal override {
        fulfillRandomWords(requestID, convertBytes32ToUint256Array(randomness, 1));
    }

    // solhint-disable-next-line chainlink-solidity/prefix-internal-functions-with-underscore
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal /*override*/ {
        Callback memory callback = s_callbacks[_requestId];
        delete s_callbacks[_requestId];

        address callbackAddress = callback.callbackAddress;
        // solhint-disable-next-line gas-custom-errors
        require(callbackAddress != address(0), "request not found"); // This should never happen

        VRFConsumerBaseV2Plus c;
        bytes memory resp = abi.encodeWithSelector(c.rawFulfillRandomWords.selector, _requestId, _randomWords);

        (bool success,) = callbackAddress.call{gas: callback.callbackGasLimit}(resp);
        if (!success) {
            emit WrapperFulfillmentFailed(_requestId, callbackAddress);
        }
    }

    function calculateRequestPriceNative(uint32 _callbackGasLimit, uint32 /*_numWords*/ )
        external
        view
        returns (uint256)
    {
        uint256 wrapperCostWei = tx.gasprice * s_wrapperGasOverhead;
        return wrapperCostWei + randomnessSender.calculateRequestPriceNative(_callbackGasLimit);
    }

    function estimateRequestPriceNative(uint32 _callbackGasLimit, uint32, /*_numWords*/ uint256 _requestGasPriceWei)
        external
        view
        returns (uint256)
    {
        uint256 wrapperCostWei = _requestGasPriceWei * s_wrapperGasOverhead;
        return wrapperCostWei + randomnessSender.estimateRequestPriceNative(_callbackGasLimit, _requestGasPriceWei);
    }

    function pendingRequestExists(uint256 subId)
        public
        view
        override (IVRFSubscriptionV2Plus, RandomnessReceiverBase)
        returns (bool)
    {
        return randomnessSender.pendingRequestExists(subId);
    }

    /**
     * @notice Add a consumer to a VRF subscription.
     * @param subId - ID of the subscription
     * @param consumer - New consumer which can use the subscription
     */
    function addConsumer(uint256 subId, address consumer) external override {
        randomnessSender.addConsumer(subId, consumer);
    }

    /**
     * @notice Remove a consumer from a VRF subscription.
     * @param subId - ID of the subscription
     * @param consumer - Consumer to remove from the subscription
     */
    function removeConsumer(uint256 subId, address consumer) external override {
        randomnessSender.removeConsumer(subId, consumer);
    }

    /**
     * @notice Cancel a subscription
     * @param subId - ID of the subscription
     * @param to - Where to send the remaining LINK to
     */
    function cancelSubscription(uint256 subId, address to) external override {
        randomnessSender.cancelSubscription(subId, to);
    }

    /**
     * @notice Accept subscription owner transfer.
     * @param subId - ID of the subscription
     * @dev will revert if original owner of subId has
     * not requested that msg.sender become the new owner.
     */
    function acceptSubscriptionOwnerTransfer(uint256 subId) external override {
        randomnessSender.acceptSubscriptionOwnerTransfer(subId);
    }

    /**
     * @notice Request subscription owner transfer.
     * @param subId - ID of the subscription
     * @param newOwner - proposed new owner of the subscription
     */
    function requestSubscriptionOwnerTransfer(uint256 subId, address newOwner) external override {
        randomnessSender.requestSubscriptionOwnerTransfer(subId, newOwner);
    }

    /**
     * @notice Create a VRF subscription.
     * @return subId - A unique subscription id.
     * @dev You can manage the consumer set dynamically with addConsumer/removeConsumer.
     * @dev Note to fund the subscription with LINK, use transferAndCall. For example
     * @dev  LINKTOKEN.transferAndCall(
     * @dev    address(COORDINATOR),
     * @dev    amount,
     * @dev    abi.encode(subId));
     * @dev Note to fund the subscription with Native, use fundSubscriptionWithNative. Be sure
     * @dev  to send Native with the call, for example:
     * @dev COORDINATOR.fundSubscriptionWithNative{value: amount}(subId);
     */
    function createSubscription() external override returns (uint256 subId) {
        subscriptionId = randomnessSender.createSubscription();
        subId = subscriptionId;
    }

    /**
     * @notice Get a VRF subscription.
     * @param subId - ID of the subscription
     * @return balance - LINK balance of the subscription in juels.
     * @return nativeBalance - native balance of the subscription in wei.
     * @return reqCount - Requests count of subscription.
     * @return owner - owner of the subscription.
     * @return consumers - list of consumer address which are able to use this subscription.
     */
    function getSubscription(uint256 subId)
        external
        view
        override
        returns (uint96 balance, uint96 nativeBalance, uint64 reqCount, address owner, address[] memory consumers)
    {
        balance = 0;
        (nativeBalance, reqCount, owner, consumers) = randomnessSender.getSubscription(subId);
    }

    /**
     * @notice Paginate through all active VRF subscriptions.
     * @param startIndex index of the subscription to start from
     * @param maxCount maximum number of subscriptions to return, 0 to return all
     * @dev the order of IDs in the list is **not guaranteed**, therefore, if making successive calls, one
     * @dev should consider keeping the blockheight constant to ensure a holistic picture of the contract state
     */
    function getActiveSubscriptionIds(uint256 startIndex, uint256 maxCount)
        external
        view
        override
        returns (uint256[] memory)
    {
        return randomnessSender.getActiveSubscriptionIds(startIndex, maxCount);
    }

    /**
     * @notice Fund a subscription with native.
     * @param subId - ID of the subscription
     * @notice This method expects msg.value to be greater than or equal to 0.
     */
    function fundSubscriptionWithNative(uint256 subId) external payable override {
        randomnessSender.fundSubscriptionWithNative(subId);
    }
}

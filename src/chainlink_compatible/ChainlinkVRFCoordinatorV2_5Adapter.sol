// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {IRandomnessReceiver} from "../interfaces/IRandomnessReceiver.sol";
import {IRandomnessSender} from "../interfaces/IRandomnessSender.sol";
import {ConfirmedOwner} from "../access/ConfirmedOwner.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
// solhint-disable-next-line no-unused-import
import {
    IVRFCoordinatorV2Plus,
    IVRFSubscriptionV2Plus
} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";

/// @dev Partial implementation of Chainlink's `VRFCoordinatorV2_5` with no-ops and dummy values for the methods RandamuVRF does not need.
// solhint-disable-next-line contract-name-camelcase
contract ChainlinkVRFCoordinatorV2_5Adapter is
    ReentrancyGuard,
    IRandomnessReceiver,
    IVRFCoordinatorV2Plus,
    ConfirmedOwner
{
    struct Callback {
        address callbackAddress;
        uint32 callbackGasLimit;
        // Reducing requestGasPrice from uint256 to uint64 slots Callback struct
        // into a single word, thus saving an entire SSTORE and leading to 21K
        // gas cost saving. 18 ETH would be the max gas price we can process.
        // GasPrice is unlikely to be more than 14 ETH on most chains
        uint64 requestGasPrice;
    }

    event WrapperFulfillmentFailed(uint256 indexed requestId, address indexed consumer);
    event WrapperGasOverheadUpdated(uint32 newWrapperGasOverhead);

    /// @notice The contract responsible for providing randomness.
    /// @dev This is an immutable reference set at deployment.
    IRandomnessSender public randomnessSender;

    // The cost for this gas is billed to the callback contract / caller, and must therefor be included
    // in the pricing for wrapped requests.
    // s_wrapperGasOverhead reflects the gas overhead of the wrapper's fulfillRandomWords
    // function. The cost for this gas is passed to the user.
    uint32 private s_wrapperGasOverhead = 100_000;
    uint32 public constant MAX_NUM_WORDS = 1;
    uint256 public lastRequestId;

    mapping(uint256 => address) private subscriptionOwners;
    mapping(uint256 => Callback) /* requestID */ /* callback */ public s_callbacks;

    /// @notice Ensures that only the designated randomness sender can call the function.
    modifier onlyRandomnessSender() {
        require(msg.sender == address(randomnessSender), "Only randomnessSender can call");
        _;
    }

    modifier onlySubscriptionOwnerOrConsumer(uint256 subId) {
        (,,, address[] memory consumers) = randomnessSender.getSubscription(subId);
        require(
            subscriptionOwners[subId] == msg.sender || _isConsumer(msg.sender, consumers),
            "Caller is not subscription owner or approved consumer"
        );
        _;
    }

    modifier onlySubscriptionOwner(uint256 subId) {
        require(subscriptionOwners[subId] == msg.sender, "Caller is not subscription owner");
        _;
    }

    constructor(address owner, address _randomnessSender) ConfirmedOwner(owner) {
        randomnessSender = IRandomnessSender(_randomnessSender);
    }

    /// @notice Checks if a given address is in the list of approved consumers.
    /// @param sender The address to check.
    /// @param consumers The list of consumer addresses.
    /// @return True if `sender` is found in `consumers`, false otherwise.
    function _isConsumer(address sender, address[] memory consumers) internal pure returns (bool) {
        for (uint256 i = 0; i < consumers.length; i++) {
            if (consumers[i] == sender) {
                return true;
            }
        }
        return false;
    }

    /// @notice Sets the gas overhead used by the wrapper for callback fulfillment.
    /// @dev Only callable by the contract owner.
    /// @param _s_wrapperGasOverhead The new gas overhead value to set.
    /// Emits a {WrapperGasOverheadUpdated} event.
    function setWrapperGasOverhead(uint32 _s_wrapperGasOverhead) external onlyOwner {
        s_wrapperGasOverhead = _s_wrapperGasOverhead;
        emit WrapperGasOverheadUpdated(s_wrapperGasOverhead);
    }

    /// @notice Request a set of random words.
    /// @param req - a struct containing following fiels for randomness request:
    /// keyHash - Corresponds to a particular oracle job which uses
    /// that key for generating the VRF proof. Different keyHash's have different gas price
    /// ceilings, so you can select a specific one to bound your maximum per request cost.
    ///
    /// subId  - The ID of the VRF subscription. Must be funded
    /// with the minimum subscription balance required for the selected keyHash.
    ///
    /// requestConfirmations - How many blocks you'd like the
    /// oracle to wait before responding to the request. See SECURITY CONSIDERATIONS
    /// for why you may want to request more. The acceptable range is
    /// [minimumRequestBlockConfirmations, 200].
    ///
    /// callbackGasLimit - How much gas you'd like to receive in your
    /// fulfillRandomWords callback. Note that gasleft() inside fulfillRandomWords
    /// may be slightly less than this amount because of gas used calling the function
    /// (argument decoding etc.), so you may need to request slightly more than you expect
    /// to have inside fulfillRandomWords. The acceptable range is
    /// [0, maxGasLimit]
    ///
    /// numWords - The number of uint256 random values you'd like to receive
    /// in your fulfillRandomWords callback. Note these numbers are expanded in a
    /// secure way by the VRFCoordinator from a single random value supplied by the oracle.
    ///
    /// extraArgs - Encoded extra arguments that has a boolean flag for whether payment
    /// should be made in native or LINK.
    /// Note: This contract does not support payments in LINK.
    /// @return requestId - A unique identifier of the request. Can be used to match
    /// a request to a response in fulfillRandomWords.
    function requestRandomWords(VRFV2PlusClient.RandomWordsRequest calldata req)
        external
        override
        nonReentrant
        onlySubscriptionOwnerOrConsumer(req.subId)
        returns (uint256 requestId)
    {
        requestId =
            randomnessSender.requestRandomnessWithSubscription(req.callbackGasLimit + s_wrapperGasOverhead, req.subId);

        s_callbacks[requestId] = Callback({
            callbackAddress: msg.sender,
            callbackGasLimit: req.callbackGasLimit,
            requestGasPrice: uint64(tx.gasprice)
        });
        lastRequestId = requestId;

        return requestId;
    }

    /// @notice Converts a bytes32 random seed into an array of pseudorandom uint256 values.
    /// @dev In this case we only return an array with a single element.
    /// @param randomness The original random seed as bytes32.
    /// @param count The number of pseudorandom uint256 values to generate.
    /// @return An array of pseudorandom uint256 values derived from the seed.
    function convertBytes32ToUint256Array(bytes32 randomness, uint256 count) internal pure returns (uint256[] memory) {
        uint256[] memory randomWords = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            randomWords[i] = uint256(keccak256(abi.encodePacked(randomness, i)));
        }
        return randomWords;
    }

    /// @notice Receives randomness for a specific request ID from the designated sender.
    /// @dev This function is restricted to calls from the designated randomness sender.
    /// @param requestID The unique identifier of the randomness request.
    /// @param randomness The generated random value as a `bytes32` type.
    function receiveRandomness(uint256 requestID, bytes32 randomness) external onlyRandomnessSender {
        fulfillRandomWords(requestID, convertBytes32ToUint256Array(randomness, 1));
    }

    /// @notice Internal function to fulfill random words by calling the consumer's callback.
    /// @dev Deletes the stored callback data after calling. Emits WrapperFulfillmentFailed if call fails.
    /// @param _requestId The VRF request ID for which the random words were generated.
    /// @param _randomWords Array of random words generated by the VRF.
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

    /// @notice Calculates the estimated price in native tokens to fulfill a randomness request.
    /// @param _callbackGasLimit The gas limit set for the callback function.
    /// _numWords The number of random words requested (unused in this implementation).
    /// @return The estimated request price in native tokens.
    function calculateRequestPriceNative(uint32 _callbackGasLimit, uint32 /*_numWords*/ )
        external
        view
        returns (uint256)
    {
        return randomnessSender.calculateRequestPriceNative(_callbackGasLimit + s_wrapperGasOverhead);
    }

    /// @notice Estimates the native token price for a randomness request at a specified gas price.
    /// @param _callbackGasLimit The gas limit set for the callback function.
    /// _numWords The number of random words requested (unused).
    /// @param _requestGasPriceWei The gas price in wei to use for the price estimation.
    /// @return The estimated price in native tokens.
    function estimateRequestPriceNative(uint32 _callbackGasLimit, uint32, /*_numWords*/ uint256 _requestGasPriceWei)
        external
        view
        returns (uint256)
    {
        return
            randomnessSender.estimateRequestPriceNative(_callbackGasLimit + s_wrapperGasOverhead, _requestGasPriceWei);
    }

    /// @notice Checks whether a pending randomness request exists for a given subscription.
    /// @param subId The subscription ID to query.
    /// @return True if there is a pending request, false otherwise.
    function pendingRequestExists(uint256 subId) public view override (IVRFSubscriptionV2Plus) returns (bool) {
        return randomnessSender.pendingRequestExists(subId);
    }

    /// @notice Add a consumer to a VRF subscription.
    /// @param subId - ID of the subscription
    /// @param consumer - New consumer which can use the subscription
    function addConsumer(uint256 subId, address consumer) external override onlySubscriptionOwner(subId) {
        randomnessSender.addConsumer(subId, consumer);
    }

    /// @notice Remove a consumer from a VRF subscription.
    /// @param subId - ID of the subscription
    /// @param consumer - Consumer to remove from the subscription
    function removeConsumer(uint256 subId, address consumer) external override onlySubscriptionOwner(subId) {
        randomnessSender.removeConsumer(subId, consumer);
    }

    /// @notice Cancel a subscription
    /// @param subId - ID of the subscription
    /// @param to - Where to send the remaining native tokens to, e.g., Ether.
    function cancelSubscription(uint256 subId, address to) external override onlySubscriptionOwner(subId) {
        randomnessSender.cancelSubscription(subId, to);
    }

    /// @notice Accept subscription owner transfer.
    /// @param subId - ID of the subscription
    /// @dev will revert if original owner of subId has
    /// not requested that msg.sender become the new owner.
    function acceptSubscriptionOwnerTransfer(uint256 subId) external override onlySubscriptionOwner(subId) {
        randomnessSender.acceptSubscriptionOwnerTransfer(subId);
    }

    /// @notice Request subscription owner transfer.
    /// @param subId - ID of the subscription
    /// @param newOwner - proposed new owner of the subscription
    function requestSubscriptionOwnerTransfer(uint256 subId, address newOwner) external override {
        randomnessSender.requestSubscriptionOwnerTransfer(subId, newOwner);
    }

    /// @notice Create a VRF subscription.
    /// @return subId - A unique subscription id.
    /// @dev You can manage the consumer set dynamically with addConsumer/removeConsumer.
    /// @dev Note to fund the subscription with Native, use fundSubscriptionWithNative. Be sure
    /// @dev  to send Native with the call, for example:
    /// @dev randomnessSender.fundSubscriptionWithNative{value: amount}(subId);
    function createSubscription() external override returns (uint256 subId) {
        subId = randomnessSender.createSubscription();
        subscriptionOwners[subId] = msg.sender;
        // add wrapper contract as a consumer as it will be msg.sender in requests
        // made to randomnessSender on behalf of chainlink vrf consumer
        randomnessSender.addConsumer(subId, address(this));
    }

    /// @notice Get a VRF subscription.
    /// @param subId - ID of the subscription
    /// @return balance - LINK balance of the subscription in juels.
    /// @return nativeBalance - native balance of the subscription in wei.
    /// @return reqCount - Requests count of subscription.
    /// @return owner - owner of the subscription.
    /// @return consumers - list of consumer address which are able to use this subscription.
    function getSubscription(uint256 subId)
        external
        view
        override
        returns (uint96 balance, uint96 nativeBalance, uint64 reqCount, address owner, address[] memory consumers)
    {
        (uint96 _nativeBalance, uint64 _reqCount, address _owner, address[] memory _consumers) =
            randomnessSender.getSubscription(subId);

        balance = 0;
        nativeBalance = _nativeBalance;
        reqCount = _reqCount;
        owner = _owner;
        consumers = _consumers;
    }

    /// @notice Paginate through all active VRF subscriptions.
    /// @param startIndex index of the subscription to start from
    /// @param maxCount maximum number of subscriptions to return, 0 to return all
    /// @dev the order of IDs in the list is **not guaranteed**, therefore, if making successive calls, one
    /// @dev should consider keeping the blockheight constant to ensure a holistic picture of the contract state
    function getActiveSubscriptionIds(uint256 startIndex, uint256 maxCount)
        external
        view
        override
        returns (uint256[] memory)
    {
        return randomnessSender.getActiveSubscriptionIds(startIndex, maxCount);
    }

    /// @notice Fund a subscription with native. Anyone can fund.
    /// @param subId - ID of the subscription
    /// @notice This method expects msg.value to be greater than or equal to 0.
    function fundSubscriptionWithNative(uint256 subId) external payable override {
        randomnessSender.fundSubscriptionWithNative{value: msg.value}(subId);
    }
}

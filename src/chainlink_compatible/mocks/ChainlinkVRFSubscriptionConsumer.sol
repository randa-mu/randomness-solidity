// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8;

///// UPDATE IMPORTS TO V2.5 /////
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/// @dev THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
/// @dev THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
/// @dev DO NOT USE THIS CODE IN PRODUCTION.
/// @dev Adopted from: https://docs.chain.link/vrf/v2-5/migration-from-v2#subscription-example-code

///// INHERIT NEW CONSUMER BASE CONTRACT /////
contract ChainlinkVRFSubscriptionConsumer is VRFConsumerBaseV2Plus {
    uint256 public requestId;
    mapping(uint256 => uint256[]) public randomWordsOf;

    ///// No need to declare a coordinator variable /////
    ///// Use the `s_vrfCoordinator` from VRFConsumerBaseV2Plus.sol /////

    ///// SUBSCRIPTION ID IS NOW UINT256 /////
    uint256 s_subscriptionId;

    /// @notice USE RANDAMU COORDINATOR ADAPTER from src/chainlink_compatible/ChainlinkVRFCoordinatorV2_5Adapter.sol in CONSTRUCTOR
    /// @param subscriptionId The subscription ID (uint256).
    /// @param _vrfCoordinator The address of the VRF Coordinator contract.
    constructor(uint256 subscriptionId, address _vrfCoordinator) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        s_subscriptionId = subscriptionId;
    }

    /// @notice Creates a new subscription and sets it as the current subscription ID.
    /// @return The new subscription ID.
    function createSubscription() external returns (uint256) {
        s_subscriptionId = s_vrfCoordinator.createSubscription();
        return s_subscriptionId;
    }

    /// @notice Adds a consumer to a subscription.
    /// @param subId The subscription ID.
    /// @param consumer The consumer contract address to add.
    function addConsumer(uint256 subId, address consumer) external onlyOwner {
        s_vrfCoordinator.addConsumer(subId, consumer);
    }

    /// @notice Sets the subscription ID to be used.
    /// @param subId The subscription ID to set.
    function setSubscription(uint256 subId) external {
        s_subscriptionId = subId;
    }

    /// @notice Returns the random words generated for a given request ID.
    /// @param _requestId The VRF request ID.
    /// @return An array of random words.
    function getRandomWords(uint256 _requestId) external view returns (uint256[] memory) {
        return randomWordsOf[_requestId];
    }

    /// @notice Funds a subscription with native tokens (ETH).
    /// @param subId The subscription ID to fund.
    function fundSubscriptionWithNative(uint256 subId) external payable {
        s_vrfCoordinator.fundSubscriptionWithNative{value: msg.value}(subId);
    }

    /// @notice Requests randomness from the VRF Coordinator.
    /// @param callbackGasLimit The gas limit for the callback.
    /// @return _requestId The VRF request ID.
    function requestRandomWords(uint32 callbackGasLimit) external onlyOwner returns (uint256 _requestId) {
        uint16 requestConfirmations = 3;
        uint32 numWords = 1;

        ///// UPDATE TO NEW V2.5 REQUEST FORMAT /////
        // To enable payment in native tokens, nativePayment is set to true.
        _requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: hex"",
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: true}))
            })
        );
        requestId = _requestId;
    }

    /// @notice Callback function used by VRF Coordinator to fulfill randomness requests.
    /// @param _requestId The VRF request ID.
    /// @param randomWords The array of random words returned by VRF.
    function fulfillRandomWords(uint256 _requestId, uint256[] calldata randomWords) internal override {
        randomWordsOf[_requestId] = randomWords;
    }
}

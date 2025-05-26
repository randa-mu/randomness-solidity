// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8;

///// UPDATE IMPORTS TO V2.5 /////
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/*

- THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
- THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
- DO NOT USE THIS CODE IN PRODUCTION.
- Adopted from: https://docs.chain.link/vrf/v2-5/migration-from-v2#subscription-example-code
*/

///// INHERIT NEW CONSUMER BASE CONTRACT /////
contract ChainlinkVRFSubscriptionConsumer is VRFConsumerBaseV2Plus {
    uint256 public requestId;
    mapping(uint256 => uint256[]) public randomWordsOf;

    ///// No need to declare a coordinator variable /////
    ///// Use the `s_vrfCoordinator` from VRFConsumerBaseV2Plus.sol /////

    ///// SUBSCRIPTION ID IS NOW UINT256 /////
    uint256 s_subscriptionId;

    ///// USE NEW CONSUMER BASE CONSTRUCTOR /////
    constructor(
        ///// UPDATE TO UINT256 /////
        uint256 subscriptionId,
        address _vrfCoordinator
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        s_subscriptionId = subscriptionId;
    }

    function createSubscription() external returns (uint256) {
        s_subscriptionId = s_vrfCoordinator.createSubscription();
        return s_subscriptionId;
    }

    function addConsumer(uint256 subId, address consumer) external onlyOwner {
        s_vrfCoordinator.addConsumer(subId, consumer);
    }

    function setSubscription(uint256 subId) external {
        s_subscriptionId = subId;
    }

    function getRandomWords(uint256 _requestId) external view returns (uint256[] memory) {
        return randomWordsOf[_requestId];
    }

    function fundSubscriptionWithNative(uint256 subId) external payable {
        s_vrfCoordinator.fundSubscriptionWithNative{value: msg.value}(subId);
    }

    function requestRandomWords(uint32 callbackGasLimit) external onlyOwner returns (uint256 _requestId) {
        uint16 requestConfirmations = 3;
        uint32 numWords = 1;

        ///// UPDATE TO NEW V2.5 REQUEST FORMAT /////
        // To enable payment in native tokens, nativePayment is set to true.
        // Use the `s_vrfCoordinator` from VRFConsumerBaseV2Plus.sol
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

    function fulfillRandomWords(uint256 _requestId, uint256[] calldata randomWords) internal override {
        randomWordsOf[_requestId] = randomWords;
    }
}

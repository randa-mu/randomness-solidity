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

*/

///// INHERIT NEW CONSUMER BASE CONTRACT /////
contract SubscriptionConsumer is VRFConsumerBaseV2Plus {
    uint256 public requestId;
    mapping(uint256 => uint256[]) public randomWordsOf;

    ///// No need to declare a coordinator variable /////
    ///// Use the `s_vrfCoordinator` from VRFConsumerBaseV2Plus.sol /////

    ///// SUBSCRIPTION ID IS NOW UINT256 /////
    uint256 s_subscriptionId;

    ///// USE NEW KEYHASH FOR VRF 2.5 GAS LANE /////
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2-5/supported-networks
    bytes32 keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    ///// USE NEW CONSUMER BASE CONSTRUCTOR /////
    constructor(
        ///// UPDATE TO UINT256 /////
        uint256 subscriptionId,
        address _vrfCoordinator
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        s_subscriptionId = subscriptionId;
    }

    function requestRandomWords() external onlyOwner returns (uint256 _requestId) {
        uint16 requestConfirmations = 3;
        uint32 callbackGasLimit = 300_000;
        uint32 numWords = 1;

        ///// UPDATE TO NEW V2.5 REQUEST FORMAT /////
        // To enable payment in native tokens, set nativePayment to true.
        // Use the `s_vrfCoordinator` from VRFConsumerBaseV2Plus.sol
        _requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        requestId = _requestId;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] calldata randomWords) internal override {
        randomWordsOf[_requestId] = randomWords;
    }
}

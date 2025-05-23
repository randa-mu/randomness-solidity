// SPDX-License-Identifier: MIT
// An example of a consumer contract that directly pays for each request.
pragma solidity ^0.8;

///// UPDATE IMPORTS TO V2.5 /////
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

import {ChainlinkVRFV2PlusWrapperConsumerBaseStub} from "../internal/ChainlinkVRFV2PlusWrapperConsumerBaseStub.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

///// INHERIT NEW WRAPPER CONSUMER BASE CONTRACT /////
contract DirectFundingConsumer is ChainlinkVRFV2PlusWrapperConsumerBaseStub, ConfirmedOwner {
    uint256 public requestId;
    mapping(uint256 => uint256[]) public randomWordsOf;

    ///// USE NEW WRAPPER CONSUMER BASE CONSTRUCTOR /////
    constructor(address wrapperAddress)
        ConfirmedOwner(msg.sender)
        VRFV2PlusWrapperConsumerBase(wrapperAddress) ///// ONLY PASS IN WRAPPER ADDRESS /////
    {}

    function requestRandomWords(bool /*enableNativePayment*/ ) external onlyOwner returns (uint256) {
        /// @notice Request parameters
        uint16 requestConfirmations = 3;
        uint32 callbackGasLimit = 300_000;
        uint32 numWords = 1;
        bool enableNativePayment = true; // Randamu only accepts native payment

        ///// UPDATE TO NEW V2.5 REQUEST FORMAT: ADD EXTRA ARGS /////
        bytes memory extraArgs =
            VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: enableNativePayment}));
        uint256 _requestId;
        uint256 reqPrice;

        ///// USE THIS FUNCTION TO PAY IN NATIVE TOKENS /////
        (_requestId, reqPrice) = requestRandomnessPayInNative(
            callbackGasLimit,
            requestConfirmations,
            numWords,
            extraArgs ///// PASS IN EXTRA ARGS /////
        );

        requestId = _requestId;
        return _requestId;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        randomWordsOf[_requestId] = _randomWords;
    }
}

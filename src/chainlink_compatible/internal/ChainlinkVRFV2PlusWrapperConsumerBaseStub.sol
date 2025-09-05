// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVRFV2PlusWrapper} from "chainlink-2.24.0/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol";

/// @dev Partial implementation of Chainlink's `VRFV2PlusWrapperConsumerBase` without the option to fund requests with LINK tokens.
/// @dev Only native tokens are supported, e.g., Ether.
/// @notice Interface for contracts using VRF randomness through the VRF V2 wrapper
/// ********************************************************************************
/// @dev PURPOSE
/// @dev Create VRF V2+ requests without the need for subscription management. Rather than creating
/// @dev and funding a VRF V2+ subscription, a user can use this wrapper to create one off requests,
/// @dev paying up front rather than at fulfillment.
/// @dev Since the price is determined using the gas price of the request transaction rather than
/// @dev the fulfillment transaction, the wrapper charges an additional premium on callback gas
/// @dev usage, in addition to some extra overhead costs associated with the VRFV2Wrapper contract.
/// ********************************************************************************
/// @dev USAGE
/// @dev Calling contracts must inherit from VRFV2PlusWrapperConsumerBase. The consumer must be funded
/// @dev with enough ether to make the request, otherwise requests will revert. To request randomness,
/// @dev call the 'requestRandomWords' function with the desired VRF parameters. This function handles
/// @dev paying for the request based on the current pricing.
/// @dev Consumers must implement the fulfillRandomWords function, which will be called during
/// @dev fulfillment with the randomness result.
abstract contract ChainlinkVRFV2PlusWrapperConsumerBaseStub {
    error OnlyVRFWrapperCanFulfill(address have, address want);

    IVRFV2PlusWrapper public immutable i_vrfV2PlusWrapper;

    /// @param _vrfV2PlusWrapper is the address of the VRFV2Wrapper contract
    constructor(address _vrfV2PlusWrapper) {
        IVRFV2PlusWrapper vrfV2PlusWrapper = IVRFV2PlusWrapper(_vrfV2PlusWrapper);
        i_vrfV2PlusWrapper = vrfV2PlusWrapper;
    }

    // solhint-disable-next-line chainlink-solidity/prefix-internal-functions-with-underscore
    function requestRandomnessPayInNative(
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        uint32 _numWords,
        bytes memory extraArgs
    ) internal returns (uint256 requestId, uint256 requestPrice) {
        requestPrice = i_vrfV2PlusWrapper.calculateRequestPriceNative(_callbackGasLimit, _numWords);
        return (
            i_vrfV2PlusWrapper.requestRandomWordsInNative{value: requestPrice}(
                _callbackGasLimit, _requestConfirmations, _numWords, extraArgs
            ),
            requestPrice
        );
    }

    /// @notice fulfillRandomWords handles the VRF V2 wrapper response. The consuming contract must
    /// implement it.
    /// @param _requestId is the VRF V2 request ID.
    /// @param _randomWords is the randomness result.
    // solhint-disable-next-line chainlink-solidity/prefix-internal-functions-with-underscore
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal virtual;

    function rawFulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) external {
        address vrfWrapperAddr = address(i_vrfV2PlusWrapper);
        if (msg.sender != vrfWrapperAddr) {
            revert OnlyVRFWrapperCanFulfill(msg.sender, vrfWrapperAddr);
        }
        fulfillRandomWords(_requestId, _randomWords);
    }

    /// @notice getBalance returns the native balance of the consumer contract
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

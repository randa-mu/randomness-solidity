// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {IRandomnessReceiver} from "../interfaces/IRandomnessReceiver.sol";
import {IRandomnessSender} from "../interfaces/IRandomnessSender.sol";
import {IVRFV2PlusWrapper} from "./internal/IVRFV2PlusWrapper.sol";
import {ConfirmedOwner} from "../access/ConfirmedOwner.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ITypeAndVersion} from "@chainlink/contracts/src/v0.8/shared/interfaces/ITypeAndVersion.sol";
import {VRFV2PlusWrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";

/// @dev Partial implementation of Chainlink's `VRFV2PlusWrapper` with no-ops and dummy values for the methods RandamuVRF does not need.
/// @notice A wrapper for VRFCoordinatorV2 that provides an interface better suited to one-off
/// @notice requests for randomness.
// solhint-disable-next-line max-states-count
contract ChainlinkVRFV2PlusWrapperAdapter is
    ReentrancyGuard,
    IRandomnessReceiver,
    ITypeAndVersion,
    IVRFV2PlusWrapper,
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

    // s_maxNumWords is the max number of words that can be requested in a single wrapped VRF request.
    uint8 internal constant s_maxNumWords = 1;

    // The cost for this gas is billed to the callback contract / caller, and must therefor be included
    // in the pricing for wrapped requests.
    // s_wrapperGasOverhead reflects the gas overhead of the wrapper's fulfillRandomWords
    // function. The cost for this gas is passed to the user.
    uint32 private s_wrapperGasOverhead = 100_000;
    uint256 public lastRequestId;

    mapping(uint256 => Callback) /* requestID */ /* callback */ public s_callbacks;

    /// @notice Ensures that only the designated randomness sender can call the function.
    modifier onlyRandomnessSender() {
        require(msg.sender == address(randomnessSender), "Only randomnessSender can call");
        _;
    }

    constructor(address owner, address _randomnessSender) ConfirmedOwner(owner) {
        randomnessSender = IRandomnessSender(_randomnessSender);
    }

    /// @notice getConfig returns the current VRFV2Wrapper configuration.
    /// @return fallbackWeiPerUnitLink is the backup LINK exchange rate used when the LINK/NATIVE feed
    ///         is stale.
    ///
    /// @return stalenessSeconds is the number of seconds before we consider the feed price to be stale
    ///         and fallback to fallbackWeiPerUnitLink.
    /// @return fulfillmentFlatFeeNativePPM is the flat fee in millionths of native that VRFCoordinatorV2Plus
    ///         charges for native payment.
    /// @return fulfillmentFlatFeeLinkDiscountPPM is the flat fee discount in millionths of native that VRFCoordinatorV2Plus
    ///         charges for link payment.
    /// @return wrapperGasOverhead reflects the gas overhead of the wrapper's fulfillRandomWords
    ///         function. The cost for this gas is passed to the user.
    /// @return coordinatorGasOverheadNative reflects the gas overhead of the coordinator's
    ///         fulfillRandomWords function for native payment.
    /// @return coordinatorGasOverheadLink reflects the gas overhead of the coordinator's
    ///         fulfillRandomWords function for link payment.
    /// @return coordinatorGasOverheadPerWord reflects the gas overhead per word of the coordinator's
    ///         fulfillRandomWords function.
    ///
    /// @return wrapperNativePremiumPercentage is the premium ratio in percentage for native payment. For example, a value of 0
    ///         indicates no premium. A value of 15 indicates a 15 percent premium.
    ///
    /// @return wrapperLinkPremiumPercentage is the premium ratio in percentage for link payment. For example, a value of 0
    ///         indicates no premium. A value of 15 indicates a 15 percent premium.
    ///
    /// @return keyHash is the key hash to use when requesting randomness. Fees are paid based on
    ///         current gas fees, so this should be set to the highest gas lane on the network.
    /// @return maxNumWords is the max number of words that can be requested in a single wrapped VRF
    ///        request.
    function getConfig()
        external
        view
        returns (
            int256 fallbackWeiPerUnitLink,
            uint32 stalenessSeconds,
            uint32 fulfillmentFlatFeeNativePPM,
            uint32 fulfillmentFlatFeeLinkDiscountPPM,
            uint32 wrapperGasOverhead,
            uint32 coordinatorGasOverheadNative,
            uint32 coordinatorGasOverheadLink,
            uint16 coordinatorGasOverheadPerWord,
            uint8 wrapperNativePremiumPercentage,
            uint8 wrapperLinkPremiumPercentage,
            bytes32 keyHash,
            uint8 maxNumWords
        )
    {
        (,, uint32 _fulfillmentFlatFeeNativePPM,,, uint8 nativePremiumPercentage,) = randomnessSender.getConfig();
        return (
            0, // s_fallbackWeiPerUnitLink,
            0, // s_stalenessSeconds,
            _fulfillmentFlatFeeNativePPM,
            0,
            0,
            0,
            0,
            0,
            nativePremiumPercentage,
            0,
            bytes32(0),
            s_maxNumWords
        );
    }

    /// @notice Sets the gas overhead used by the wrapper for callback fulfillment.
    /// @dev Only callable by the contract owner.
    /// @param _s_wrapperGasOverhead The new gas overhead value to set.
    /// Emits a {WrapperGasOverheadUpdated} event.
    function setWrapperGasOverhead(uint32 _s_wrapperGasOverhead) external onlyOwner {
        s_wrapperGasOverhead = _s_wrapperGasOverhead;
        emit WrapperGasOverheadUpdated(s_wrapperGasOverhead);
    }

    /// @notice Calculates the native token price for a request based on the callback gas limit.
    /// @param _callbackGasLimit The gas limit for the callback function.
    /// _numWords Number of random words requested (unused in this implementation).
    /// @return The price in native tokens required for the request.
    function calculateRequestPriceNative(uint32 _callbackGasLimit, uint32 /*_numWords*/ )
        external
        view
        override
        returns (uint256)
    {
        return randomnessSender.calculateRequestPriceNative(_callbackGasLimit + s_wrapperGasOverhead);
    }

    /// @notice Estimates the native token price for a request with a specific gas price.
    /// @param _callbackGasLimit The gas limit for the callback function.
    /// _numWords Number of random words requested (unused in this implementation).
    /// @param _requestGasPriceWei The gas price (in wei) to use for estimation.
    /// @return The estimated price in native tokens required for the request.
    function estimateRequestPriceNative(uint32 _callbackGasLimit, uint32, /*_numWords*/ uint256 _requestGasPriceWei)
        external
        view
        override
        returns (uint256)
    {
        return
            randomnessSender.estimateRequestPriceNative(_callbackGasLimit + s_wrapperGasOverhead, _requestGasPriceWei);
    }

    /// @notice Requests random words paid in native token.
    /// @param _callbackGasLimit The gas limit for the callback function.
    /// _requestConfirmations Number of confirmations the oracle should wait (unused here).
    /// _numWords Number of random words requested (unused here).
    /// extraArgs Extra encoded arguments (unused here).
    /// @return requestId The unique ID for this randomness request.
    function requestRandomWordsInNative(
        uint32 _callbackGasLimit,
        uint16, /*_requestConfirmations*/
        uint32, /*_numWords*/
        bytes calldata /*extraArgs*/
    ) external payable override nonReentrant returns (uint256 requestId) {
        requestId = randomnessSender.requestRandomness{value: msg.value}(_callbackGasLimit + s_wrapperGasOverhead);

        s_callbacks[requestId] = Callback({
            callbackAddress: msg.sender,
            callbackGasLimit: _callbackGasLimit,
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

    /// @notice Receives randomness from the authorized sender and triggers fulfillment.
    /// @dev Only callable by the designated randomness sender.
    /// @param requestID The unique ID of the randomness request.
    /// @param randomness The random value received, as bytes32.
    function receiveRandomness(uint256 requestID, bytes32 randomness) external onlyRandomnessSender {
        fulfillRandomWords(requestID, convertBytes32ToUint256Array(randomness, 1));
    }

    /// @notice Internal function to fulfill randomness requests by calling the consumer's callback.
    /// @param _requestId The ID of the randomness request.
    /// @param _randomWords The array of random words to pass to the consumer.
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal {
        Callback memory callback = s_callbacks[_requestId];
        delete s_callbacks[_requestId];

        address callbackAddress = callback.callbackAddress;
        require(callbackAddress != address(0), "request not found"); // This should never happen

        VRFV2PlusWrapperConsumerBase c;
        bytes memory resp = abi.encodeWithSelector(c.rawFulfillRandomWords.selector, _requestId, _randomWords);

        (bool success,) = callbackAddress.call{gas: callback.callbackGasLimit}(resp);
        if (!success) {
            emit WrapperFulfillmentFailed(_requestId, callbackAddress);
        }
    }

    /// @notice Returns the type and version of the wrapper contract.
    /// @return A string identifying the contract version.
    function typeAndVersion() external pure virtual override returns (string memory) {
        return "VRFV2PlusWrapper 1.0.0";
    }
}

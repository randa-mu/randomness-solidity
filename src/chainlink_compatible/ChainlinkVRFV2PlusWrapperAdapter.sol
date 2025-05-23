// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {ITypeAndVersion} from "@chainlink/contracts/src/v0.8/shared/interfaces/ITypeAndVersion.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {IVRFV2PlusWrapper} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol";
import {VRFV2PlusWrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";

/**
 * @dev Partial implementation of Chainlink's `VRFV2PlusWrapper` with no-ops and dummy values for the methods RandamuVRF does not need.
 */

/**
 * @notice A wrapper for VRFCoordinatorV2 that provides an interface better suited to one-off
 * @notice requests for randomness.
 */
// solhint-disable-next-line max-states-count
contract ChainlinkVRFV2PlusWrapperAdapter is ConfirmedOwner, ITypeAndVersion, VRFConsumerBaseV2Plus, IVRFV2PlusWrapper {
    event WrapperFulfillmentFailed(uint256 indexed requestId, address indexed consumer);

    uint256 private constant GAS_FOR_CALL_EXACT_CHECK = 5_000;
    uint16 private constant EXPECTED_MIN_LENGTH = 36;

    // solhint-disable-next-line chainlink-solidity/prefix-immutable-variables-with-i
    uint256 public immutable SUBSCRIPTION_ID;
    LinkTokenInterface internal immutable i_link;
    AggregatorV3Interface internal immutable i_link_native_feed;

    event FulfillmentTxSizeSet(uint32 size);
    event ConfigSet(
        uint32 wrapperGasOverhead,
        uint32 coordinatorGasOverheadNative,
        uint32 coordinatorGasOverheadLink,
        uint16 coordinatorGasOverheadPerWord,
        uint8 coordinatorNativePremiumPercentage,
        uint8 coordinatorLinkPremiumPercentage,
        bytes32 keyHash,
        uint8 maxNumWords,
        uint32 stalenessSeconds,
        int256 fallbackWeiPerUnitLink,
        uint32 fulfillmentFlatFeeNativePPM,
        uint32 fulfillmentFlatFeeLinkDiscountPPM
    );
    event FallbackWeiPerUnitLinkUsed(uint256 requestId, int256 fallbackWeiPerUnitLink);
    event Withdrawn(address indexed to, uint256 amount);
    event NativeWithdrawn(address indexed to, uint256 amount);
    event Enabled();
    event Disabled();

    error LinkAlreadySet();
    error LinkDiscountTooHigh(uint32 flatFeeLinkDiscountPPM, uint32 flatFeeNativePPM);
    error InvalidPremiumPercentage(uint8 premiumPercentage, uint8 max);
    error FailedToTransferLink();
    error IncorrectExtraArgsLength(uint16 expectedMinimumLength, uint16 actualLength);
    error NativePaymentInOnTokenTransfer();
    error LINKPaymentInRequestRandomWordsInNative();
    error SubscriptionIdMissing();

    // s_maxNumWords is the max number of words that can be requested in a single wrapped VRF request.
    uint8 internal s_maxNumWords;

    // lastRequestId is the request ID of the most recent VRF V2 request made by this wrapper. This
    // should only be relied on within the same transaction the request was made.
    uint256 public override lastRequestId;

    // todo add overhead for wrappers fulfillRandomWords logic
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

    constructor(address _coordinator) VRFConsumerBaseV2Plus(_coordinator) {}

    /**
     * @notice getConfig returns the current VRFV2Wrapper configuration.
     *
     * @return fallbackWeiPerUnitLink is the backup LINK exchange rate used when the LINK/NATIVE feed
     *         is stale.
     *
     * @return stalenessSeconds is the number of seconds before we consider the feed price to be stale
     *         and fallback to fallbackWeiPerUnitLink.
     *
     * @return fulfillmentFlatFeeNativePPM is the flat fee in millionths of native that VRFCoordinatorV2Plus
     *         charges for native payment.
     *
     * @return fulfillmentFlatFeeLinkDiscountPPM is the flat fee discount in millionths of native that VRFCoordinatorV2Plus
     *         charges for link payment.
     *
     * @return wrapperGasOverhead reflects the gas overhead of the wrapper's fulfillRandomWords
     *         function. The cost for this gas is passed to the user.
     *
     * @return coordinatorGasOverheadNative reflects the gas overhead of the coordinator's
     *         fulfillRandomWords function for native payment.
     *
     * @return coordinatorGasOverheadLink reflects the gas overhead of the coordinator's
     *         fulfillRandomWords function for link payment.
     *
     * @return coordinatorGasOverheadPerWord reflects the gas overhead per word of the coordinator's
     *         fulfillRandomWords function.
     *
     * @return wrapperNativePremiumPercentage is the premium ratio in percentage for native payment. For example, a value of 0
     *         indicates no premium. A value of 15 indicates a 15 percent premium.
     *
     * @return wrapperLinkPremiumPercentage is the premium ratio in percentage for link payment. For example, a value of 0
     *         indicates no premium. A value of 15 indicates a 15 percent premium.
     *
     * @return keyHash is the key hash to use when requesting randomness. Fees are paid based on
     *         current gas fees, so this should be set to the highest gas lane on the network.
     *
     * @return maxNumWords is the max number of words that can be requested in a single wrapped VRF
     *         request.
     */
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
        return (
            s_fallbackWeiPerUnitLink,
            s_stalenessSeconds,
            s_fulfillmentFlatFeeNativePPM,
            s_fulfillmentFlatFeeLinkDiscountPPM,
            s_wrapperGasOverhead,
            s_coordinatorGasOverheadNative,
            s_coordinatorGasOverheadLink,
            s_coordinatorGasOverheadPerWord,
            s_coordinatorNativePremiumPercentage,
            s_coordinatorLinkPremiumPercentage,
            s_keyHash,
            s_maxNumWords
        );
    }

    function calculateRequestPriceNative(uint32 _callbackGasLimit, uint32 _numWords)
        external
        view
        override
        onlyConfiguredNotDisabled
        returns (uint256)
    {
        return _calculateRequestPriceNative(_callbackGasLimit, _numWords, tx.gasprice);
    }

    function estimateRequestPriceNative(uint32 _callbackGasLimit, uint32 _numWords, uint256 _requestGasPriceWei)
        external
        view
        override
        onlyConfiguredNotDisabled
        returns (uint256)
    {
        return _calculateRequestPriceNative(_callbackGasLimit, _numWords, _requestGasPriceWei);
    }

    function _calculateRequestPriceNative(uint256 _gas, uint32 _numWords, uint256 _requestGasPrice)
        internal
        view
        returns (uint256)
    {
        // costWei is the base fee denominated in wei (native)
        // (wei/gas) * gas
        uint256 wrapperCostWei = _requestGasPrice * s_wrapperGasOverhead;

        // coordinatorCostWei takes into account the L1 posting costs of the VRF fulfillment transaction, if we are on an L2.
        // (wei/gas) * gas + l1wei
        uint256 coordinatorCostWei =
            _requestGasPrice * (_gas + _getCoordinatorGasOverhead(_numWords, true)) + _getL1CostWei();

        // coordinatorCostWithPremiumAndFlatFeeWei is the coordinator cost with the percentage premium and flat fee applied
        // coordinator cost * premium multiplier + flat fee
        uint256 coordinatorCostWithPremiumAndFlatFeeWei = (
            (coordinatorCostWei * (s_coordinatorNativePremiumPercentage + 100)) / 100
        ) + (1e12 * uint256(s_fulfillmentFlatFeeNativePPM));

        return wrapperCostWei + coordinatorCostWithPremiumAndFlatFeeWei;
    }

    function requestRandomWordsInNative(
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        uint32 _numWords,
        bytes calldata extraArgs
    ) external payable override onlyConfiguredNotDisabled returns (uint256 requestId) {
        checkPaymentMode(extraArgs, false);

        uint32 eip150Overhead = _getEIP150Overhead(_callbackGasLimit);
        uint256 price = _calculateRequestPriceNative(_callbackGasLimit, _numWords, tx.gasprice);
        // solhint-disable-next-line gas-custom-errors
        require(msg.value >= price, "fee too low");
        // solhint-disable-next-line gas-custom-errors
        require(_numWords <= s_maxNumWords, "numWords too high");
        VRFV2PlusClient.RandomWordsRequest memory req = VRFV2PlusClient.RandomWordsRequest({
            keyHash: s_keyHash,
            subId: SUBSCRIPTION_ID,
            requestConfirmations: _requestConfirmations,
            callbackGasLimit: _callbackGasLimit + eip150Overhead + s_wrapperGasOverhead,
            numWords: _numWords,
            extraArgs: extraArgs
        });
        requestId = s_vrfCoordinator.requestRandomWords(req);
        s_callbacks[requestId] = Callback({
            callbackAddress: msg.sender,
            callbackGasLimit: _callbackGasLimit,
            requestGasPrice: uint64(tx.gasprice)
        });

        return requestId;
    }

    // solhint-disable-next-line chainlink-solidity/prefix-internal-functions-with-underscore
    function fulfillRandomWords(uint256 _requestId, uint256[] calldata _randomWords) internal override {
        Callback memory callback = s_callbacks[_requestId];
        delete s_callbacks[_requestId];

        address callbackAddress = callback.callbackAddress;
        // solhint-disable-next-line gas-custom-errors
        require(callbackAddress != address(0), "request not found"); // This should never happen

        VRFV2PlusWrapperConsumerBase c;
        bytes memory resp = abi.encodeWithSelector(c.rawFulfillRandomWords.selector, _requestId, _randomWords);

        bool success = _callWithExactGas(callback.callbackGasLimit, callbackAddress, resp);
        if (!success) {
            emit WrapperFulfillmentFailed(_requestId, callbackAddress);
        }
    }

    function typeAndVersion() external pure virtual override returns (string memory) {
        return "VRFV2PlusWrapper 1.0.0";
    }
}

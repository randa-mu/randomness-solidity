// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "../RandomnessReceiverBase.sol";

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {BlockhashStoreInterface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/BlockhashStoreInterface.sol";
import {
    VRFConsumerBaseV2Plus,
    IVRFMigratableConsumerV2Plus
} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {SubscriptionAPI} from "@chainlink/contracts/src/v0.8/vrf/dev/SubscriptionAPI.sol";
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
contract ChainlinkVRFCoordinatorV2_5Adapter is RandomnessReceiverBase, IVRFCoordinatorV2Plus {
    uint16 public constant MAX_REQUEST_CONFIRMATIONS = 200;
    uint32 public constant MAX_NUM_WORDS = 1;
    uint8 private constant PREMIUM_PERCENTAGE_MAX = 155;

    event WrapperFulfillmentFailed(uint256 indexed requestId, address indexed consumer);

    // todo set overhead constant for this wrappers fulfillRandomWords logic
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

    //     error InvalidRequestConfirmations(uint16 have, uint16 min, uint16 max);
    //     error GasLimitTooBig(uint32 have, uint32 want);
    //     error NumWordsTooBig(uint32 have, uint32 want);
    //     error MsgDataTooBig(uint256 have, uint32 max);
    //     error ProvingKeyAlreadyRegistered(bytes32 keyHash);
    //     error NoSuchProvingKey(bytes32 keyHash);
    //     error InvalidLinkWeiPrice(int256 linkWei);
    //     error LinkDiscountTooHigh(uint32 flatFeeLinkDiscountPPM, uint32 flatFeeNativePPM);
    //     error InvalidPremiumPercentage(uint8 premiumPercentage, uint8 max);
    //     error NoCorrespondingRequest();
    //     error IncorrectCommitment();
    //     error BlockhashNotInStore(uint256 blockNum);
    //     error PaymentTooLarge();
    //     error InvalidExtraArgsTag();
    //     error GasPriceExceeded(uint256 gasPrice, uint256 maxGas);

    //     struct ProvingKey {
    //         bool exists; // proving key exists
    //         uint64 maxGas; // gas lane max gas price for fulfilling requests
    //     }

    //     mapping(bytes32 => ProvingKey) /* keyHash */ /* provingKey */ public s_provingKeys;
    //     bytes32[] public s_provingKeyHashes;
    //     mapping(uint256 => bytes32) /* requestID */ /* commitment */ public s_requestCommitments;

    //     event ProvingKeyRegistered(bytes32 keyHash, uint64 maxGas);
    //     event ProvingKeyDeregistered(bytes32 keyHash, uint64 maxGas);

    //     event RandomWordsRequested(
    //         bytes32 indexed keyHash,
    //         uint256 requestId,
    //         uint256 preSeed,
    //         uint256 indexed subId,
    //         uint16 minimumRequestConfirmations,
    //         uint32 callbackGasLimit,
    //         uint32 numWords,
    //         bytes extraArgs,
    //         address indexed sender
    //     );

    //     event RandomWordsFulfilled(
    //         uint256 indexed requestId,
    //         uint256 outputSeed,
    //         uint256 indexed subId,
    //         uint96 payment,
    //         bool nativePayment,
    //         bool success,
    //         bool onlyPremium
    //     );

    //     event L1GasFee(uint256 fee);

    //     int256 public s_fallbackWeiPerUnitLink;

    //     event ConfigSet(
    //         uint16 minimumRequestConfirmations,
    //         uint32 maxGasLimit,
    //         uint32 stalenessSeconds,
    //         uint32 gasAfterPaymentCalculation,
    //         int256 fallbackWeiPerUnitLink,
    //         uint32 fulfillmentFlatFeeNativePPM,
    //         uint32 fulfillmentFlatFeeLinkDiscountPPM,
    //         uint8 nativePremiumPercentage,
    //         uint8 linkPremiumPercentage
    //     );

    //     event FallbackWeiPerUnitLinkUsed(uint256 requestId, int256 fallbackWeiPerUnitLink);

    //     constructor() {
    //         // BLOCKHASH_STORE = BlockhashStoreInterface(blockhashStore);
    //     }

    constructor(address randomnessSender) RandomnessReceiverBase(randomnessSender) {}

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
        returns (
            // nonReentrant
            uint256 requestId
        )
    {
        requestId = _requestRandomnessWithSubscription(req.callbackGasLimit);

        s_callbacks[requestId] = Callback({
            callbackAddress: msg.sender,
            callbackGasLimit: req.callbackGasLimit,
            requestGasPrice: uint64(tx.gasprice)
        });

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

    // todo add overhead for adapter wrapper here with higher callback gas limit??

    function calculateRequestPriceNative(uint32 _callbackGasLimit, uint32 _numWords) external view returns (uint256) {
        return randomnessSender.calculateRequestPriceNative(_callbackGasLimit);
    }

    function estimateRequestPriceNative(uint32 _callbackGasLimit, uint32 _numWords, uint256 _requestGasPriceWei)
        external
        view
        returns (uint256)
    {
        return randomnessSender.estimateRequestPriceNative(_callbackGasLimit, _requestGasPriceWei);
    }

    function pendingRequestExists(uint256 subId) public view override returns (bool) {
        return randomnessSender.pendingRequestExists(subId);
    }
}

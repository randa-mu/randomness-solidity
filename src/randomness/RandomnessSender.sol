/// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {AccessControlEnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {TypesLib} from "../libraries/TypesLib.sol";
import {CallWithExactGas} from "../libraries/CallWithExactGas.sol";

import {IRandomnessReceiver} from "../interfaces/IRandomnessReceiver.sol";
import {IRandomnessSender} from "../interfaces/IRandomnessSender.sol";
import {ISignatureSender} from "../interfaces/ISignatureSender.sol";

import {SignatureReceiverBase} from "../signature-requests/SignatureReceiverBase.sol";
import {FeeCollector} from "../fee-collector/FeeCollector.sol";

/// @title RandomnessSender contract
/// @author Randamu
/// @notice Handles randomness requests from user's contracts and
/// forwards the randomness to them via a callback to the `receiveRandomness(...)` function.
contract RandomnessSender is
    IRandomnessSender,
    SignatureReceiverBase,
    FeeCollector,
    Initializable,
    UUPSUpgradeable,
    AccessControlEnumerableUpgradeable
{
    using CallWithExactGas for bytes;

    /// @notice The identifier for the signature scheme used.
    string public constant SCHEME_ID = "BN254";
    /// @notice Role identifier for the contract administrator.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Internal nonce used to track randomness requests.
    uint256 public nonce = 0;

    /// @notice Mapping from randomness request ID to request details.
    mapping(uint256 => TypesLib.RandomnessRequest) private callbacks;
    /// @notice Array of all randomness requests.
    TypesLib.RandomnessRequest[] private allRequests;

    /// @notice Emitted when a randomness request is initiated.
    event RandomnessRequested(
        uint256 indexed requestID, uint256 indexed nonce, address indexed requester, uint256 requestedAt
    );
    /// @notice Emitted when a randomness callback is successfully processed.
    event RandomnessCallbackSuccess(uint256 indexed requestID, bytes32 randomness, bytes signature);
    /// @notice Emitted when the signature sender address is updated.
    event SignatureSenderUpdated(address indexed signatureSender);
    /// @notice Emitted when a randomness callback fails.
    event RandomnessCallbackFailed(uint256 indexed requestID);

    /// @notice Ensures that only an account with the ADMIN_ROLE can execute a function.
    modifier onlyAdmin() {
        _checkRole(ADMIN_ROLE);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with a signature sender and owner.
    function initialize(address _signatureSender, address owner) public initializer {
        __UUPSUpgradeable_init();
        __AccessControlEnumerable_init();

        require(_grantRole(ADMIN_ROLE, owner), "Grant role failed");
        require(_grantRole(DEFAULT_ADMIN_ROLE, owner), "Grant role failed");

        require(_signatureSender != address(0), "Cannot set zero address as signature sender");
        signatureSender = ISignatureSender(_signatureSender);
    }

    /// @notice Authorizes contract upgrades.
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {}

    /// @notice Requests randomness with a callback gas limit but without a subscription id and returns a request ID.
    /// @dev Used for direct funding requests where subscription id == 0.
    function requestRandomness(uint32 callbackGasLimit)
        external
        payable
        onlyConfiguredNotDisabled
        returns (uint256 requestID)
    {
        requestID = requestRandomnessWithSubscription(callbackGasLimit, 0);
    }

    /// @notice Requests randomness with a callback gas limit and subscription id and returns a request ID.
    function requestRandomnessWithSubscription(uint32 callbackGasLimit, uint256 subId)
        public
        payable
        onlyConfiguredNotDisabled
        returns (uint256 requestID)
    {
        require(subId != 0 || msg.value > 0, "Direct funding required for request fulfillment callback");

        /// @dev subId must be zero for direct funding or non zero for active subscription
        _validateCallbackGasLimitAndUpdateSubscription(callbackGasLimit, subId);

        nonce += 1;

        TypesLib.RandomnessRequest memory r = TypesLib.RandomnessRequest({
            nonce: nonce,
            callback: msg.sender,
            subId: subId,
            callbackGasLimit: callbackGasLimit,
            directFundingFeePaid: msg.value,
            requestId: 0,
            message: hex"",
            condition: hex"",
            signature: hex""
        });

        bytes memory m = messageFrom(TypesLib.RandomnessRequestCreationParams({nonce: nonce, callback: msg.sender}));

        bytes memory condition = hex"";

        requestID = _requestSignature(SCHEME_ID, m, condition);

        r.requestId = requestID;
        r.message = m;
        r.condition = condition;

        callbacks[requestID] = r;
        allRequests.push(r);

        emit RandomnessRequested(requestID, nonce, msg.sender, block.timestamp);
    }

    /// @notice Validates the subscription (if subId > 0) and the _callbackGasLimit
    /// @notice and updates the subscription for a given consumer.
    /// @dev This function checks the validity of the subscription and updates the subscription's state.
    /// @dev If the subscription ID is greater than zero, it ensures that the consumer has an active subscription.
    /// @dev If the subscription ID is zero, it processes a new subscription by calculating the necessary fees.
    /// @param _callbackGasLimit The gas limit for the callback function.
    /// @param _subId The subscription ID. If greater than zero, it indicates an existing subscription, otherwise, a new subscription is created.
    function _validateCallbackGasLimitAndUpdateSubscription(uint32 _callbackGasLimit, uint256 _subId) internal {
        // No lower bound on the requested gas limit. A user could request 0 callback gas limit
        // but the overhead added covers bls pairing check operations and decryption as part of the callback
        // and any other added logic in consumer contract might lead to out of gas revert.
        require(_callbackGasLimit <= s_config.maxGasLimit, "Callback gasLimit too high");

        if (_subId > 0) {
            address owner = s_subscriptionConfigs[_subId].owner;
            _requireValidSubscription(owner);
            // Its important to ensure that the consumer is in fact who they say they
            // are, otherwise they could use someone else's subscription balance.
            mapping(uint256 => ConsumerConfig) storage consumerConfigs = s_consumers[msg.sender];

            ConsumerConfig memory consumerConfig = consumerConfigs[_subId];
            require(consumerConfig.active, "No active subscription for caller");

            ++consumerConfig.nonce;
            ++consumerConfig.pendingReqCount;
            consumerConfigs[_subId] = consumerConfig;
        } else {
            uint256 price = _calculateRequestPriceNative(_callbackGasLimit, tx.gasprice);

            require(msg.value >= price, "Fee too low");
        }
    }

    /// @notice Processes a received signature and invokes the callback.
    function onSignatureReceived(uint256 requestID, bytes calldata signature) internal override {
        uint256 startGas = gasleft();

        TypesLib.RandomnessRequest storage request = callbacks[requestID];
        require(request.nonce > 0, "No request for request id");

        bytes32 randomness = keccak256(signature);

        bytes memory callbackCallData =
            abi.encodeWithSelector(IRandomnessReceiver.receiveRandomness.selector, requestID, randomness);

        (bool success,) = callbackCallData._callWithExactGasEvenIfTargetIsNoContract(
            request.callback, request.callbackGasLimit, s_config.gasForCallExactCheck
        );
        if (success) {
            request.signature = signature;
            emit RandomnessCallbackSuccess(requestID, randomness, signature);
        } else {
            emit RandomnessCallbackFailed(requestID);
        }

        _handlePaymentAndCharge(requestID, startGas);
    }

    /// @notice Estimates the total request price in native tokens based on the provided callback gas limit and requested gas price in wei
    /// @param _callbackGasLimit The gas limit allocated for the callback execution
    /// @param _requestGasPriceWei The gas price in wei for the request
    /// @return The estimated total price for the request in native tokens (wei)
    /// @dev This function calls the internal `_calculateRequestPriceNative` function, passing in the provided callback gas limit and requested gas price in wei
    ///      to estimate the total request price. It overrides the function from both `BlocklockFeeCollector` and `IBlocklockSender` contracts to provide the price estimation.
    function estimateRequestPriceNative(uint32 _callbackGasLimit, uint256 _requestGasPriceWei)
        external
        view
        override (FeeCollector, IRandomnessSender)
        returns (uint256)
    {
        return _calculateRequestPriceNative(_callbackGasLimit, _requestGasPriceWei);
    }

    /// @notice Calculates the total request price in native tokens, considering the provided callback gas limit and the current gas price
    /// @param _callbackGasLimit The gas limit allocated for the callback execution
    /// @return The total price for the request in native tokens (wei)
    /// @dev This function calls the internal `_calculateRequestPriceNative` function, passing in the provided callback gas limit and the current
    ///      transaction gas price (`tx.gasprice`) to calculate the total request price. It overrides the function from both `BlocklockFeeCollector`
    ///      and `IBlocklockSender` contracts to provide the request price calculation.
    function calculateRequestPriceNative(uint32 _callbackGasLimit)
        public
        view
        override (FeeCollector, IRandomnessSender)
        returns (uint256)
    {
        return _calculateRequestPriceNative(_callbackGasLimit, tx.gasprice);
    }

    /// @notice Handles the payment and charges for a request based on the subscription or direct funding.
    /// @dev This function calculates the payment for a given request, either based on a subscription or direct funding.
    /// @dev It updates the subscription and consumer state and
    ///     charges the appropriate amount based on the gas usage and payment parameters.
    /// @param requestId The ID of the request to handle payment for.
    /// @param startGas The amount of gas used at the start of the transaction,
    ///     used for calculating payment based on gas consumption.
    function _handlePaymentAndCharge(uint256 requestId, uint256 startGas) internal override {
        TypesLib.RandomnessRequest memory request = getRequest(requestId);

        if (request.subId > 0) {
            ++s_subscriptions[request.subId].reqCount;
            --s_consumers[request.callback][request.subId].pendingReqCount;

            uint96 payment = _calculatePaymentAmountNative(startGas, tx.gasprice);
            _chargePayment(payment, request.subId);
        } else {
            _chargePayment(uint96(request.directFundingFeePaid), request.subId);
        }
    }

    /// @notice disable this contract so that new requests will be rejected. When disabled, new requests
    /// @notice will revert but existing requests can still be fulfilled.
    function disable() external override onlyAdmin {
        s_disabled = true;

        emit Disabled();
    }

    /// @notice Enables the contract, allowing new requests to be accepted.
    /// @dev Can only be called by an admin.
    function enable() external override onlyAdmin {
        s_disabled = false;
        emit Enabled();
    }

    /// @notice Sets the configuration parameters for the contract
    /// @param maxGasLimit The maximum gas limit allowed for requests
    /// @param gasAfterPaymentCalculation The gas used after the payment calculation
    /// @param fulfillmentFlatFeeNativePPM The flat fee for fulfillment in native tokens, in parts per million (PPM)
    /// 1 PPM = 0.0001%, so: 1,000,000 PPM = 100%, 10,000 PPM = 1%, 500 PPM = 0.05%
    /// @param weiPerUnitGas Wei per unit of gas for callback gas measurements
    /// @param blsPairingCheckOverhead Gas overhead for bls pairing checks for signature and decryption key verification
    /// @param nativePremiumPercentage The percentage premium applied to the native token cost
    /// @param gasForCallExactCheck Gas required for exact EXTCODESIZE call and additional operations in CallWithExactGas library
    /// @dev Only the contract admin can call this function. It validates that the `nativePremiumPercentage` is not greater than a predefined maximum value
    /// (`PREMIUM_PERCENTAGE_MAX`). After validation, it updates the contract's configuration and emits an event `ConfigSet` with the new configuration.
    /// @dev Emits a `ConfigSet` event after successfully setting the new configuration values.
    function setConfig(
        uint32 maxGasLimit,
        uint32 gasAfterPaymentCalculation,
        uint32 fulfillmentFlatFeeNativePPM,
        uint32 weiPerUnitGas,
        uint32 blsPairingCheckOverhead,
        uint8 nativePremiumPercentage,
        uint32 gasForCallExactCheck
    ) external override onlyAdmin {
        require(PREMIUM_PERCENTAGE_MAX > nativePremiumPercentage, "Invalid Premium Percentage");

        s_config = Config({
            maxGasLimit: maxGasLimit,
            gasAfterPaymentCalculation: gasAfterPaymentCalculation,
            fulfillmentFlatFeeNativePPM: fulfillmentFlatFeeNativePPM,
            weiPerUnitGas: weiPerUnitGas,
            blsPairingCheckOverhead: blsPairingCheckOverhead,
            nativePremiumPercentage: nativePremiumPercentage,
            gasForCallExactCheck: gasForCallExactCheck
        });

        s_configured = true;

        emit ConfigSet(
            maxGasLimit,
            gasAfterPaymentCalculation,
            fulfillmentFlatFeeNativePPM,
            weiPerUnitGas,
            blsPairingCheckOverhead,
            nativePremiumPercentage,
            gasForCallExactCheck
        );
    }

    /// @notice Retrieves the current configuration parameters for the contract
    /// @return maxGasLimit The maximum gas limit allowed for requests
    /// @return gasAfterPaymentCalculation The gas used after the payment calculation
    /// @return fulfillmentFlatFeeNativePPM The flat fee for fulfillment in native tokens, in parts per million (PPM)
    /// @return weiPerUnitGas Wei per unit of gas for callback gas measurements
    /// @return blsPairingCheckOverhead Gas overhead for bls pairing checks for signature and decryption key verification
    /// @return nativePremiumPercentage The percentage premium applied to the native token cost
    /// @return gasForCallExactCheck Gas required for exact EXTCODESIZE call and additional operations in CallWithExactGas library.
    /// @dev This function returns the key configuration values from the contract's settings. These values
    /// are important for calculating request costs and applying the appropriate fees.
    function getConfig()
        external
        view
        returns (
            uint32 maxGasLimit,
            uint32 gasAfterPaymentCalculation,
            uint32 fulfillmentFlatFeeNativePPM,
            uint32 weiPerUnitGas,
            uint32 blsPairingCheckOverhead,
            uint8 nativePremiumPercentage,
            uint32 gasForCallExactCheck
        )
    {
        return (
            s_config.maxGasLimit,
            s_config.gasAfterPaymentCalculation,
            s_config.fulfillmentFlatFeeNativePPM,
            s_config.weiPerUnitGas,
            s_config.blsPairingCheckOverhead,
            s_config.nativePremiumPercentage,
            s_config.gasForCallExactCheck
        );
    }

    /// @notice Owner cancel subscription, sends remaining native tokens directly to the subscription owner.
    /// @param subId subscription id
    /// @dev notably can be called even if there are pending requests, outstanding ones may fail onchain
    function ownerCancelSubscription(uint256 subId) external override onlyAdmin {
        address subOwner = s_subscriptionConfigs[subId].owner;
        _requireValidSubscription(subOwner);
        _cancelSubscriptionHelper(subId, subOwner);
    }

    /// @notice Withdraw native tokens earned through fulfilling requests.
    /// @param recipient The address to send the funds to.
    function withdrawSubscriptionFeesNative(address payable recipient) external override nonReentrant onlyAdmin {
        uint96 amount = s_withdrawableSubscriptionFeeNative;
        _requireSufficientBalance(amount > 0);
        // Prevent re-entrancy by updating state before transfer.
        s_withdrawableSubscriptionFeeNative = 0;
        // For subscription fees, we also deduct amount from s_totalNativeBalance
        // s_totalNativeBalance tracks the total native sent to/from
        // this contract through fundSubscription, cancelSubscription.
        s_totalNativeBalance -= amount;
        _mustSendNative(recipient, amount);
    }

    function withdrawDirectFundingFeesNative(address payable recipient) external override nonReentrant onlyAdmin {
        uint96 amount = s_withdrawableDirectFundingFeeNative;
        _requireSufficientBalance(amount > 0);
        // Prevent re-entrancy by updating state before transfer.
        s_withdrawableDirectFundingFeeNative = 0;

        _mustSendNative(recipient, amount);
    }

    /// @notice Updates the signature sender address.
    function setSignatureSender(address newSignatureSender) external onlyAdmin {
        signatureSender = ISignatureSender(newSignatureSender);
        emit SignatureSenderUpdated(newSignatureSender);
    }

    /// @notice Checks if a request is still in flight.
    function isInFlight(uint256 requestID) external view returns (bool) {
        return signatureSender.isInFlight(requestID);
    }

    /// @notice Generates a message from a randomness request.
    function messageFrom(TypesLib.RandomnessRequestCreationParams memory r) public pure returns (bytes memory) {
        return abi.encodePacked(keccak256(abi.encode(r.nonce)));
    }

    /// @notice Retrieves a randomness request by ID.
    function getRequest(uint256 requestId) public view returns (TypesLib.RandomnessRequest memory) {
        return callbacks[requestId];
    }

    /// @notice Retrieves all randomness requests.
    function getAllRequests() external view returns (TypesLib.RandomnessRequest[] memory) {
        return allRequests;
    }

    /// @notice Returns the contract version.
    function version() external pure returns (string memory) {
        return "0.0.1";
    }
}

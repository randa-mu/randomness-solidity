/// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {IRandomnessReceiver} from "./interfaces/IRandomnessReceiver.sol";
import {IRandomnessSender} from "./interfaces/IRandomnessSender.sol";

import {ConfirmedOwner} from "./access/ConfirmedOwner.sol";

/// @title RandomnessReceiverBase contract
/// @author Randamu
/// @notice Abstract contract to facilitate receiving randomness from an external source.
/// @dev This contract ensures that only a designated randomness sender can provide randomness values.
abstract contract RandomnessReceiverBase is IRandomnessReceiver, ConfirmedOwner {
    /// @notice The contract responsible for providing randomness.
    /// @dev This is an immutable reference set at deployment.
    IRandomnessSender public randomnessSender;

    /// @notice Event to log direct transfer of native tokens to the contract
    event Received(address, uint256);

    /// @notice Event to log deposits of native tokens
    event Funded(address indexed sender, uint256 amount);

    /// @notice Event to log withdrawals of native tokens
    event Withdrawn(address indexed recipient, uint256 amount);

    /// @notice Event logged when a new subscription id is set
    event NewSubscriptionId(uint256 indexed subscriptionId);

    /// @notice The subscription ID used for conditional encryption.
    /// @dev Used in interactions with IRandomnessSender for subscription management, e.g.,
    /// @dev funding and consumer contract address registration.
    uint256 public subscriptionId;

    /// @notice Ensures that only the designated randomness sender can call the function.
    modifier onlyRandomnessSender() {
        require(msg.sender == address(randomnessSender), "Only randomnessSender can call");
        _;
    }

    /// @notice Initializes the contract with a specified randomness sender.
    /// @dev Ensures that the provided sender address is non-zero.
    /// @param _randomnessSender The address of the randomness sender contract.
    constructor(address _randomnessSender, address owner) ConfirmedOwner(owner) {
        randomnessSender = IRandomnessSender(_randomnessSender);
    }

    /// @notice Sets the Randamu subscription ID used for conditional encryption oracle services.
    /// @dev Only callable by the contract owner.
    /// @param subId The new subscription ID to be set.
    function setSubId(uint256 subId) external onlyOwner {
        subscriptionId = subId;
        emit NewSubscriptionId(subId);
    }

    /// @notice Sets the address of the IRandomnessSender contract.
    /// @dev Only the contract owner can call this function.
    /// @param _randomnessSender The address of the deployed IRandomnessSender contract.
    function setRandomnessSender(address _randomnessSender) external onlyOwner {
        require(_randomnessSender != address(0), "Cannot set zero address as sender");
        randomnessSender = IRandomnessSender(_randomnessSender);
    }

    /// @notice Adds a list of consumer addresses to the Randamu subscription.
    /// @dev Requires the subscription ID to be set before calling.
    /// @param consumers An array of addresses to be added as authorized consumers.
    function updateSubscription(address[] calldata consumers) external onlyOwner {
        require(subscriptionId != 0, "subID not set");
        for (uint256 i = 0; i < consumers.length; i++) {
            randomnessSender.addConsumer(subscriptionId, consumers[i]);
        }
    }

    /// @notice Creates and funds a new Randamu subscription using native currency.
    /// @dev Only callable by the contract owner. If a subscription already exists, it will not be recreated.
    /// @dev The ETH value sent in the transaction (`msg.value`) will be used to fund the subscription.
    function createSubscriptionAndFundNative() external payable onlyOwner {
        subscriptionId = _subscribe();
        randomnessSender.fundSubscriptionWithNative{value: msg.value}(subscriptionId);
    }

    /// @notice Tops up the Randamu subscription using native currency (e.g., ETH).
    /// @dev Requires a valid subscription ID to be set before calling.
    /// @dev The amount to top up should be sent along with the transaction as `msg.value`.
    function topUpSubscriptionNative() external payable {
        require(subscriptionId != 0, "sub not set");
        randomnessSender.fundSubscriptionWithNative{value: msg.value}(subscriptionId);
    }

    /// @notice getBalance returns the native balance of the consumer contract.
    /// @notice For direct funding requests, the contract needs to hold native tokens to
    /// sufficient enough to cover the cost of the request.
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function _requestRandomnessPayInNative(uint32 callbackGasLimit)
        internal
        returns (uint256 requestId, uint256 requestPrice)
    {
        requestPrice = randomnessSender.calculateRequestPriceNative(callbackGasLimit);

        require(msg.value >= requestPrice, "Insufficient ETH");

        requestId = randomnessSender.requestRandomness{value: msg.value}(callbackGasLimit);
    }

    function _requestRandomnessWithSubscription(uint32 callbackGasLimit) internal returns (uint256 requestId) {
        return randomnessSender.requestRandomnessWithSubscription(callbackGasLimit, subscriptionId);
    }

    /// @notice Receives randomness for a specific request ID from the designated sender.
    /// @dev This function is restricted to calls from the designated randomness sender.
    /// @param requestID The unique identifier of the randomness request.
    /// @param randomness The generated random value as a `bytes32` type.
    function receiveRandomness(uint256 requestID, bytes32 randomness) external onlyRandomnessSender {
        onRandomnessReceived(requestID, randomness);
    }

    /// @notice Handles the reception of a generated random value for a specific request.
    /// @dev This internal function is intended to be overridden by derived contracts to implement custom behavior.
    /// @param requestID The unique identifier of the randomness request.
    /// @param randomness The generated random value, provided as a `bytes32` type.
    function onRandomnessReceived(uint256 requestID, bytes32 randomness) internal virtual;

    /// @notice Creates a new Randamu subscription if none exists and registers this contract as a consumer.
    /// @dev Internal helper that initializes the subscription only once.
    /// @return subId The subscription ID that was created or already exists.
    function _subscribe() internal returns (uint256 subId) {
        require(subscriptionId == 0, "SubscriptionId is not zero");
        subId = randomnessSender.createSubscription();
        randomnessSender.addConsumer(subId, address(this));
    }

    /// @notice Cancels an existing Randamu subscription if one exists.
    /// @dev Internal helper that cancels the subscription.
    /// @param to The recipient addresss that will receive the subscription balance.
    function _cancelSubscription(address to) internal {
        require(subscriptionId != 0, "SubscriptionId is zero");
        randomnessSender.cancelSubscription(subscriptionId, to);
    }

    function _removeConsumer(address consumer) internal {
        require(subscriptionId != 0, "SubscriptionId is zero");
        randomnessSender.removeConsumer(subscriptionId, consumer);
    }

    function isInFlight(uint256 requestId) public view returns (bool) {
        return randomnessSender.isInFlight(requestId);
    }

    function pendingRequestExists(uint256 subId) public view virtual returns (bool) {
        return randomnessSender.pendingRequestExists(subId);
    }
}

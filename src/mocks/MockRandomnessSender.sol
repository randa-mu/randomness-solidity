/// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {IRandomnessReceiver} from "src/interfaces/IRandomnessReceiver.sol";
import {IRandomnessSender} from "src/interfaces/IRandomnessSender.sol";
import {TypesLib} from "src/libraries/TypesLib.sol";

/// @title MockRandomnessSender contract
/// @author Randamu
/// @notice Mock implementation of RandomnessSender for testing purposes
/// @dev This contract provides controllable randomness for testing smart contracts
contract MockRandomnessSender {
    /// @notice Internal nonce used to track randomness requests.
    uint256 public nonce = 0;

    /// @notice Mapping from randomness request ID to request details.
    mapping(uint256 => TypesLib.RandomnessRequest) private callbacks;
    
    /// @notice Array of all randomness requests.
    TypesLib.RandomnessRequest[] private allRequests;
    
    /// @notice Array to track pending request IDs
    uint256[] private pendingRequestIds;
    
    /// @notice Mapping to store pre-set randomness values for specific request IDs
    mapping(uint256 => bytes32) private presetRandomness;
    
    /// @notice Mapping to track subscription balances (subId => balance in wei)
    mapping(uint256 => uint256) private subscriptionBalances;
    
    /// @notice Mapping to track subscription owners (subId => owner address)
    mapping(uint256 => address) private subscriptionOwners;
    
    /// @notice Mapping to track subscription consumers (subId => consumer address => is authorized)
    mapping(uint256 => mapping(address => bool)) private subscriptionConsumers;
    
    /// @notice Counter for generating unique subscription IDs
    uint256 private nextSubId = 1;
    
    /// @notice Default randomness value to use when no preset value is available
    bytes32 public defaultRandomness = keccak256("MOCK_RANDOMNESS");
    
    /// @notice Whether to auto-fulfill requests immediately
    bool public autoFulfill = false;
    
    /// @notice Gas price for cost calculations (can be set for testing)
    uint256 public mockGasPrice = 20 gwei;
    
    /// @notice Mock configuration for fee calculations
    struct MockConfig {
        uint32 maxGasLimit;
        uint32 gasAfterPaymentCalculation;
        uint32 fulfillmentFlatFeeNativePPM;
        uint32 weiPerUnitGas;
        uint32 blsPairingCheckOverhead;
        uint8 nativePremiumPercentage;
        uint32 gasForCallExactCheck;
    }
    
    MockConfig public mockConfig = MockConfig({
        maxGasLimit: 2500000,
        gasAfterPaymentCalculation: 33285,
        fulfillmentFlatFeeNativePPM: 500,
        weiPerUnitGas: 1000000000, // 1 gwei
        blsPairingCheckOverhead: 113000,
        nativePremiumPercentage: 10,
        gasForCallExactCheck: 5000
    });

    /// @notice Emitted when a randomness request is initiated.
    event RandomnessRequested(
        uint256 indexed requestID, uint256 indexed nonce, address indexed requester, uint256 requestedAt
    );
    
    /// @notice Emitted when a randomness callback is successfully processed.
    event RandomnessCallbackSuccess(uint256 indexed requestID, bytes32 randomness, bytes signature);
    
    /// @notice Emitted when a randomness callback fails.
    event RandomnessCallbackFailed(uint256 indexed requestID);
    
    /// @notice Emitted when a subscription is funded with native tokens.
    event SubscriptionFunded(uint256 indexed subId, uint256 oldBalance, uint256 newBalance);
    
    /// @notice Emitted when a subscription is created.
    event SubscriptionCreated(uint256 indexed subId, address indexed owner);
    
    /// @notice Emitted when a consumer is added to a subscription.
    event SubscriptionConsumerAdded(uint256 indexed subId, address indexed consumer);
    
    /// @notice Emitted when a consumer is removed from a subscription.
    event SubscriptionConsumerRemoved(uint256 indexed subId, address indexed consumer);

    /// @notice Requests randomness with a callback gas limit but without a subscription id and returns a request ID.
    function requestRandomness(uint32 callbackGasLimit)
        external
        payable
        returns (uint256 requestID)
    {
        return requestRandomnessWithSubscription(callbackGasLimit, 0);
    }

    /// @notice Requests randomness with a callback gas limit and subscription id and returns a request ID.
    function requestRandomnessWithSubscription(uint32 callbackGasLimit, uint256 subId)
        public
        payable
        returns (uint256 requestID)
    {
        require(callbackGasLimit <= mockConfig.maxGasLimit, "Callback gasLimit too high");
        
        // For subscription requests, verify the caller is authorized
        if (subId != 0) {
            require(subscriptionOwners[subId] != address(0), "Subscription does not exist");
            require(
                subscriptionOwners[subId] == msg.sender || subscriptionConsumers[subId][msg.sender], 
                "Not authorized to use this subscription"
            );
        }

        nonce += 1;
        requestID = nonce; // Simple request ID assignment for mock

        TypesLib.RandomnessRequest memory request = TypesLib.RandomnessRequest({
            nonce: nonce,
            callback: msg.sender,
            subId: subId,
            callbackGasLimit: callbackGasLimit,
            directFundingFeePaid: msg.value,
            requestId: requestID,
            message: abi.encodePacked(keccak256(abi.encode(nonce))),
            condition: "",
            signature: ""
        });

        callbacks[requestID] = request;
        allRequests.push(request);
        pendingRequestIds.push(requestID);

        emit RandomnessRequested(requestID, nonce, msg.sender, block.timestamp);

        // Auto-fulfill if enabled
        if (autoFulfill) {
            _fulfillRequest(requestID);
        }

        return requestID;
    }

    /// @notice Create a subscription.
    /// @return subId - A unique subscription id.
    /// @dev You can manage the consumer set dynamically with addConsumer/removeConsumer.
    /// @dev Note to fund the subscription with Native, use fundSubscriptionWithNative. Be sure
    /// @dev  to send Native with the call, for example:
    /// @dev COORDINATOR.fundSubscriptionWithNative{value: amount}(subId);
    function createSubscription() external returns (uint256 subId) {
        subId = nextSubId;
        nextSubId++;
        
        subscriptionOwners[subId] = msg.sender;
        
        emit SubscriptionCreated(subId, msg.sender);
        
        return subId;
    }

    /// @notice Add a consumer to a subscription.
    /// @param subId - ID of the subscription
    /// @param consumer - New consumer which can use the subscription
    function addConsumer(uint256 subId, address consumer) external {
        require(subscriptionOwners[subId] == msg.sender, "Only subscription owner can add consumers");
        require(consumer != address(0), "Invalid consumer address");
        require(!subscriptionConsumers[subId][consumer], "Consumer already added");
        
        subscriptionConsumers[subId][consumer] = true;
        
        emit SubscriptionConsumerAdded(subId, consumer);
    }

    /// @notice Remove a consumer from a subscription.
    /// @param subId - ID of the subscription
    /// @param consumer - Consumer to remove from the subscription
    function removeConsumer(uint256 subId, address consumer) external {
        require(subscriptionOwners[subId] == msg.sender, "Only subscription owner can remove consumers");
        require(subscriptionConsumers[subId][consumer], "Consumer not found");
        
        subscriptionConsumers[subId][consumer] = false;
        
        emit SubscriptionConsumerRemoved(subId, consumer);
    }

    /// @notice Fund a subscription with native.
    /// @param subId - ID of the subscription
    /// @notice This method expects msg.value to be greater than or equal to 0.
    function fundSubscriptionWithNative(uint256 subId) external payable {
        require(subId > 0, "Invalid subscription ID");
        require(subscriptionOwners[subId] != address(0), "Subscription does not exist");
        
        uint256 oldBalance = subscriptionBalances[subId];
        subscriptionBalances[subId] += msg.value;
        
        emit SubscriptionFunded(subId, oldBalance, subscriptionBalances[subId]);
    }

    /// @notice Provide specific randomness value for a request ID and fulfill it
    /// @param requestID The ID of the randomness request to fulfill
    /// @param randomness The specific randomness value to provide
    function provideRandomness(uint256 requestID, bytes32 randomness) external {
        _fulfillRequestWithValue(requestID, randomness);
    }

    /// @notice Manually fulfill a randomness request (for testing scenarios)
    function fulfillRequest(uint256 requestID) external {
        _fulfillRequest(requestID);
    }

    /// @notice Manually fulfill a randomness request with specific randomness value
    function fulfillRequestWithRandomness(uint256 requestID, bytes32 randomness) external {
        _fulfillRequestWithValue(requestID, randomness);
    }

    /// @notice Internal function to fulfill a request
    function _fulfillRequest(uint256 requestID) internal {
        bytes32 randomness = presetRandomness[requestID];
        if (randomness == 0) {
            // Generate pseudo-random value based on request ID and block data
            randomness = keccak256(abi.encodePacked(requestID, block.timestamp, block.prevrandao, defaultRandomness));
        }
        _fulfillRequestWithValue(requestID, randomness);
    }

    /// @notice Internal function to fulfill a request with a specific value
    function _fulfillRequestWithValue(uint256 requestID, bytes32 randomness) internal {
        TypesLib.RandomnessRequest storage request = callbacks[requestID];
        require(request.nonce > 0, "No request for request id");
        require(request.signature.length == 0, "Request already fulfilled");

        // For subscription requests, optionally deduct the cost from subscription balance
        // (In a real implementation, you'd calculate and deduct the actual cost)
        if (request.subId > 0) {
            uint256 estimatedCost = calculateRequestPriceNative(request.callbackGasLimit);
            // Only deduct if there's sufficient balance (in mock, we're lenient)
            if (subscriptionBalances[request.subId] >= estimatedCost) {
                _deductFromSubscription(request.subId, estimatedCost);
            }
        }

        // Mock signature
        bytes memory signature = abi.encodePacked(randomness);
        request.signature = signature;

        // Remove from pending requests
        _removePendingRequest(requestID);

        // Attempt callback
        bytes memory callbackCallData =
            abi.encodeWithSelector(IRandomnessReceiver.receiveRandomness.selector, requestID, randomness);

        (bool success,) = request.callback.call{gas: request.callbackGasLimit}(callbackCallData);
        
        if (success) {
            emit RandomnessCallbackSuccess(requestID, randomness, signature);
        } else {
            emit RandomnessCallbackFailed(requestID);
        }
    }

    /// @notice Set preset randomness for a specific request ID (for deterministic testing)
    function setRandomnessForRequest(uint256 requestID, bytes32 randomness) external {
        presetRandomness[requestID] = randomness;
    }

    /// @notice Set default randomness value
    function setDefaultRandomness(bytes32 randomness) external {
        defaultRandomness = randomness;
    }

    /// @notice Set whether to auto-fulfill requests
    function setAutoFulfill(bool _autoFulfill) external {
        autoFulfill = _autoFulfill;
    }

    /// @notice Set mock gas price for fee calculations
    function setMockGasPrice(uint256 _gasPrice) external {
        mockGasPrice = _gasPrice;
    }

    /// @notice Estimates the total request price in native tokens based on the provided callback gas limit and requested gas price in wei
    function estimateRequestPriceNative(uint32 _callbackGasLimit, uint256 _requestGasPriceWei)
        external
        view
        returns (uint256)
    {
        return _calculateMockPrice(_callbackGasLimit, _requestGasPriceWei);
    }

    /// @notice Calculates the total request price in native tokens, considering the provided callback gas limit and the current gas price
    function calculateRequestPriceNative(uint32 _callbackGasLimit)
        public
        view
        returns (uint256)
    {
        return _calculateMockPrice(_callbackGasLimit, mockGasPrice);
    }

    /// @notice Internal function to calculate mock pricing
    function _calculateMockPrice(uint32 _callbackGasLimit, uint256 _gasPrice) internal view returns (uint256) {
        // Simplified pricing calculation for mock
        uint256 gasUsed = _callbackGasLimit + mockConfig.gasAfterPaymentCalculation + mockConfig.blsPairingCheckOverhead;
        uint256 baseCost = gasUsed * _gasPrice;
        uint256 flatFee = (baseCost * mockConfig.fulfillmentFlatFeeNativePPM) / 1000000;
        uint256 premium = (baseCost * mockConfig.nativePremiumPercentage) / 100;
        return baseCost + flatFee + premium;
    }

    /// @notice Retrieves a randomness request by ID.
    function getRequest(uint256 requestId) external view returns (TypesLib.RandomnessRequest memory) {
        return callbacks[requestId];
    }

    /// @notice Retrieves all randomness requests.
    function getAllRequests() external view returns (TypesLib.RandomnessRequest[] memory) {
        return allRequests;
    }

    /// @notice Retrieves all pending (unfulfilled) request IDs
    function getPendingRequestIds() external view returns (uint256[] memory) {
        return pendingRequestIds;
    }

    /// @notice Get subscription balance
    /// @param subId - ID of the subscription
    /// @return balance The current balance of the subscription in wei
    function getSubscriptionBalance(uint256 subId) external view returns (uint256 balance) {
        return subscriptionBalances[subId];
    }

    /// @notice Get subscription owner
    /// @param subId - ID of the subscription
    /// @return owner The owner address of the subscription
    function getSubscriptionOwner(uint256 subId) external view returns (address owner) {
        return subscriptionOwners[subId];
    }

    /// @notice Check if an address is a consumer of a subscription
    /// @param subId - ID of the subscription
    /// @param consumer - Address to check
    /// @return isConsumer Whether the address is an authorized consumer
    function isSubscriptionConsumer(uint256 subId, address consumer) external view returns (bool isConsumer) {
        return subscriptionConsumers[subId][consumer];
    }

    /// @notice Check if a subscription exists
    /// @param subId - ID of the subscription
    /// @return exists Whether the subscription exists
    function subscriptionExists(uint256 subId) external view returns (bool exists) {
        return subscriptionOwners[subId] != address(0);
    }

    /// @notice Deduct cost from subscription (internal helper for testing)
    /// @param subId - ID of the subscription
    /// @param amount - Amount to deduct in wei
    function _deductFromSubscription(uint256 subId, uint256 amount) internal {
        require(subscriptionBalances[subId] >= amount, "Insufficient subscription balance");
        subscriptionBalances[subId] -= amount;
    }

    /// @notice Get count of pending requests
    function getPendingRequestCount() external view returns (uint256) {
        return pendingRequestIds.length;
    }

    /// @notice Checks if a request is still in flight (not yet fulfilled)
    function isInFlight(uint256 requestID) external view returns (bool) {
        TypesLib.RandomnessRequest memory request = callbacks[requestID];
        return request.nonce > 0 && request.signature.length == 0;
    }

    /// @notice Generates a message from a randomness request (for compatibility)
    function messageFrom(TypesLib.RandomnessRequestCreationParams memory r) external pure returns (bytes memory) {
        return abi.encodePacked(keccak256(abi.encode(r.nonce)));
    }

    /// @notice Returns the contract version.
    function version() external pure returns (string memory) {
        return "0.0.1-mock";
    }

    /// @notice Update mock configuration for testing different fee scenarios
    function setMockConfig(
        uint32 maxGasLimit,
        uint32 gasAfterPaymentCalculation,
        uint32 fulfillmentFlatFeeNativePPM,
        uint32 weiPerUnitGas,
        uint32 blsPairingCheckOverhead,
        uint8 nativePremiumPercentage,
        uint32 gasForCallExactCheck
    ) external {
        mockConfig = MockConfig({
            maxGasLimit: maxGasLimit,
            gasAfterPaymentCalculation: gasAfterPaymentCalculation,
            fulfillmentFlatFeeNativePPM: fulfillmentFlatFeeNativePPM,
            weiPerUnitGas: weiPerUnitGas,
            blsPairingCheckOverhead: blsPairingCheckOverhead,
            nativePremiumPercentage: nativePremiumPercentage,
            gasForCallExactCheck: gasForCallExactCheck
        });
    }

    /// @notice Get current mock configuration
    function getMockConfig() external view returns (MockConfig memory) {
        return mockConfig;
    }

    /// @notice Force fail a specific request (for testing failure scenarios)
    function forceFailRequest(uint256 requestID) external {
        TypesLib.RandomnessRequest storage request = callbacks[requestID];
        require(request.nonce > 0, "No request for request id");
        
        // Remove from pending requests
        _removePendingRequest(requestID);
        
        emit RandomnessCallbackFailed(requestID);
        
        // Mark as fulfilled with empty signature to prevent re-processing
        request.signature = "failed";
    }

    /// @notice Internal function to remove a request ID from pending requests array
    function _removePendingRequest(uint256 requestID) internal {
        for (uint256 i = 0; i < pendingRequestIds.length; i++) {
            if (pendingRequestIds[i] == requestID) {
                // Move the last element to the current position and pop
                pendingRequestIds[i] = pendingRequestIds[pendingRequestIds.length - 1];
                pendingRequestIds.pop();
                break;
            }
        }
    }

    /// @notice Reset the mock state (for testing)
    function reset() external {
        nonce = 0;
        // Clear pending requests array
        delete pendingRequestIds;
        // Note: mappings and arrays would need manual clearing in a real scenario
        // For testing, you might want to deploy a fresh contract instead
    }

    /// @notice Allow contract to receive Ether
    receive() external payable {}
}
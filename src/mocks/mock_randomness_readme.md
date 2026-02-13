# MockRandomnessSender

A comprehensive mock implementation of the Randamu RandomnessSender for testing smart contracts that require verifiable randomness.

## Overview

MockRandomnessSender provides a controllable randomness service that mimics the behavior of the Randamu protocol while allowing developers to specify exact randomness values for deterministic testing scenarios.

## Key Features

### 🎯 **Controllable Randomness**
- Set specific randomness values for testing favorable/unfavorable outcomes
- Auto-fulfill requests or manually control fulfillment timing
- Preset randomness values for specific request IDs

### 💰 **Dual Payment Models**
- **Direct Payment**: Pay per request with native tokens
- **Subscription Model**: Create subscriptions, fund them, and manage authorized consumers

### 🔧 **Testing Utilities**
- Force request failures for error handling tests
- Configurable gas pricing and fee calculations
- Reset functionality for clean test states
- Comprehensive request tracking and querying

## Core Functions

### Randomness Requests

#### Direct Payment Requests
```solidity
// Request randomness with direct payment
uint256 requestId = mockRandomnessSender.requestRandomness{value: 1 ether}(callbackGasLimit);
```

#### Subscription Requests
```solidity
// Request randomness using a subscription
uint256 requestId = mockRandomnessSender.requestRandomnessWithSubscription(callbackGasLimit, subId);
```

### Subscription Management

#### Creating and Funding Subscriptions
```solidity
// Create a new subscription
uint256 subId = mockRandomnessSender.createSubscription();

// Fund the subscription
mockRandomnessSender.fundSubscriptionWithNative{value: 1 ether}(subId);
```

#### Consumer Management
```solidity
// Add authorized consumers
mockRandomnessSender.addConsumer(subId, consumerContract);

// Remove consumers
mockRandomnessSender.removeConsumer(subId, consumerContract);

// Check consumer authorization
bool isAuthorized = mockRandomnessSender.isSubscriptionConsumer(subId, consumerContract);
```

### Controlled Fulfillment

#### Manual Fulfillment with Custom Randomness
```solidity
// Provide specific randomness value for testing
mockRandomnessSender.provideRandomness(requestId, favorableRandomness);

// Fulfill with auto-generated randomness
mockRandomnessSender.fulfillRequest(requestId);
```

#### Preset Randomness Values
```solidity
// Set randomness value before request is made
mockRandomnessSender.setRandomnessForRequest(requestId, predeterminedValue);

// Set default randomness for all auto-fulfilled requests
mockRandomnessSender.setDefaultRandomness(defaultValue);
```

## Configuration Options

### Auto-Fulfillment Control
```solidity
// Enable/disable automatic request fulfillment
mockRandomnessSender.setAutoFulfill(false); // Manual control
mockRandomnessSender.setAutoFulfill(true);  // Auto-fulfill (default)
```

### Gas Price Configuration
```solidity
// Set mock gas price for fee calculations
mockRandomnessSender.setMockGasPrice(25 gwei);

// Calculate request costs
uint256 cost = mockRandomnessSender.calculateRequestPriceNative(callbackGasLimit);
```

### Mock Configuration
```solidity
// Update fee calculation parameters
mockRandomnessSender.setMockConfig(
    maxGasLimit,
    gasAfterPaymentCalculation,
    fulfillmentFlatFeeNativePPM,
    weiPerUnitGas,
    blsPairingCheckOverhead,
    nativePremiumPercentage,
    gasForCallExactCheck
);
```

## Testing Utilities

### Request Tracking
```solidity
// Get all requests
TypesLib.RandomnessRequest[] memory allRequests = mockRandomnessSender.getAllRequests();

// Get pending (unfulfilled) request IDs
uint256[] memory pending = mockRandomnessSender.getPendingRequestIds();

// Check if a request is still pending
bool inFlight = mockRandomnessSender.isInFlight(requestId);

// Get specific request details
TypesLib.RandomnessRequest memory request = mockRandomnessSender.getRequest(requestId);
```

### Subscription Queries
```solidity
// Check subscription balance
uint256 balance = mockRandomnessSender.getSubscriptionBalance(subId);

// Get subscription owner
address owner = mockRandomnessSender.getSubscriptionOwner(subId);

// Verify subscription exists
bool exists = mockRandomnessSender.subscriptionExists(subId);
```

### Error Testing
```solidity
// Force a request to fail for error handling tests
mockRandomnessSender.forceFailRequest(requestId);

// Reset all state for clean tests
mockRandomnessSender.reset();
```

## Events

The contract emits comprehensive events for monitoring and testing:

```solidity
event RandomnessRequested(uint256 indexed requestID, uint256 indexed nonce, address indexed requester, uint256 requestedAt);
event RandomnessCallbackSuccess(uint256 indexed requestID, bytes32 randomness, bytes signature);
event RandomnessCallbackFailed(uint256 indexed requestID);
event SubscriptionCreated(uint256 indexed subId, address indexed owner);
event SubscriptionFunded(uint256 indexed subId, uint256 oldBalance, uint256 newBalance);
event SubscriptionConsumerAdded(uint256 indexed subId, address indexed consumer);
event SubscriptionConsumerRemoved(uint256 indexed subId, address indexed consumer);
```

## Complete Testing Example

```solidity
// Setup
MockRandomnessSender mockRandomness = new MockRandomnessSender();
mockRandomness.setAutoFulfill(false); // Manual control for testing

// Create and fund subscription
uint256 subId = mockRandomness.createSubscription();
mockRandomness.fundSubscriptionWithNative{value: 1 ether}(subId);
mockRandomness.addConsumer(subId, address(this));

// Test favorable outcome
uint256 requestId1 = mockRandomness.requestRandomnessWithSubscription(200000, subId);
bytes32 favorableRandomness = bytes32(uint256(1)); // Always wins
mockRandomness.provideRandomness(requestId1, favorableRandomness);

// Test unfavorable outcome
uint256 requestId2 = mockRandomness.requestRandomnessWithSubscription(200000, subId);
bytes32 unfavorableRandomness = bytes32(uint256(0)); // Always loses
mockRandomness.provideRandomness(requestId2, unfavorableRandomness);

// Test failure handling
uint256 requestId3 = mockRandomness.requestRandomnessWithSubscription(200000, subId);
mockRandomness.forceFailRequest(requestId3);
```

## Access Control

- **Subscription Owners**: Can add/remove consumers and fund subscriptions
- **Authorized Consumers**: Can make requests using the subscription
- **Anyone**: Can create subscriptions, make direct payment requests, and call testing utilities

## Notes

- This is a **testing-only** contract - not suitable for production use
- Subscription balance deduction is lenient (won't fail if insufficient funds)
- All testing utilities are publicly accessible for maximum flexibility
- Contract accepts Ether via the `receive()` function

Perfect for testing randomness-dependent smart contracts with full control over outcomes and edge cases!
# randomness-solidity
[![Solidity ^0.8.x](https://img.shields.io/badge/Solidity-%5E0.8.x-blue)](https://soliditylang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Foundry Tests](https://img.shields.io/badge/Tested%20with-Foundry-red)](https://book.getfoundry.sh/)

A Solidity library for generating on-chain randomness from the [dcipher threshold network](https://dcipher.network). Designed for developers who need flexible, verifiable, and secure on-chain randomness solutions.


## Overview
In decentralized applications, unpredictable random values are essential for ensuring fairness and preventing manipulation. Secure randomness ensures that outcomes are both **unbiased** and **unpredictable**, making it impossible for any single participant to influence the result. This is particularly critical in use cases such as NFT trait generation, decentralized governance, lotteries, and other scenarios where fairness is a core requirement.

This repository provides a Solidity-based library for requesting on-chain randomness powered by the **dcipher threshold network**. Random values are generated through supported threshold signature schemes, which guarantees that the output is publicly verifiable, tamper-resistant, and unpredictable until revealed. This cryptographic foundation ensures that smart contracts relying on randomness can operate in a secure and trust-minimized manner.

The library is designed with modularity and simplicity in mind, allowing developers to easily integrate it into their existing smart contract projects. Its extensible architecture makes it suitable for a wide range of applications that require robust on-chain randomness.

### Features
Powered by the dcipher threshold network and its threshold-based cryptographic schemes, this randomness library offers:

- **Verifiable & Trustless**: Not just decentralized, unpredictable, but also publicly verifiable trustless randomness.
- **Unpredictable**: Using highly unpredictable and diverse inputs for a hash function.
- **Modular Design**: Choose from multiple randomness & signature schemes.


## Smart Contracts    

### Randomness
Provides functionality to generate and verify randomness based on conditional threshold signatures from the dcipher network.   
- ✨ `RandomnessReceiverBase.sol` - An abstract contract that developers **must implement** to request and receive randomness within their own smart contracts.
- `RandomnessSender.sol` - Handles the processing and management of randomness requests using the conditional signing mechanism provided by the dcipher threshold network. 

### Signature  
Because randomness is derived from conditional threshold signatures produced by the dcipher network, this library also includes contracts for requesting and processing signature requests using a defined schema. 
- `SignatureSchemeAddressProvider.sol` - Maintains the list of supported signature schemes (e.g., BLS).
- `SignatureReceiverBase.sol` - An abstract contract for requesting and receiving threshold signatures from the dcipher network. 
- `SignatureSender.sol` - Core contract for managing conditional threshold signing of messages using the dcipher network.

> 💡 **Note:** You only need to extend `RandomnessReceiverBase.sol` to customize randomness requests. All other required contracts are already deployed on supported networks.



## Quick Start

### Installation
To get started, install the randomness-solidity library in your smart contract project using your preferred development tool.

#### Hardhat (npm)

```bash
npm install randomness-solidity
```  

#### Foundry 

```bash
forge install randa-mu/randomness-solidity
```

### Usage 

#### Build
```sh
npm run build
```

#### Test
```sh
npm run test
```

### Supported Networks

| Contract        |  Description | Address | 
|-----------------|---------|---------|
| **RandomnessSender Proxy** | A lightweight proxy contract that enables upgradeability for the `BlocklockSender` implementation. It delegates all calls to the underlying implementation and serves as the primary interface for user interaction. | <br> - Base Sepolia: [0xf4e080Db4765C856c0af43e4A8C4e31aA3b48779](https://sepolia.basescan.org/address/0xf4e080Db4765C856c0af43e4A8C4e31aA3b48779) <br> - Polygon PoS: [0xf4e080Db4765C856c0af43e4A8C4e31aA3b48779](https://polygonscan.com/address/0xf4e080Db4765C856c0af43e4A8C4e31aA3b48779) <br> - Optimism Sepolia: [0xf4e080Db4765C856c0af43e4A8C4e31aA3b48779](https://sepolia-optimism.etherscan.io/address/0xf4e080Db4765C856c0af43e4A8C4e31aA3b48779) <br> - Arbitrum Sepolia: [0xf4e080Db4765C856c0af43e4A8C4e31aA3b48779](https://sepolia.arbiscan.io/address/0xf4e080Db4765C856c0af43e4A8C4e31aA3b48779) <br> - Avalanche (C-Chain) Testnet: [0xf4e080Db4765C856c0af43e4A8C4e31aA3b48779](https://testnet.snowtrace.io/address/0xf4e080Db4765C856c0af43e4A8C4e31aA3b48779) <br> - Sei Testnet: [0xf4e080Db4765C856c0af43e4A8C4e31aA3b48779](https://seitrace.com/address/0xf4e080Db4765C856c0af43e4A8C4e31aA3b48779?chain=atlantic-2) <br>- Filecoin Mainnet: [0xDD6FdE56432Cd3c868FEC7F1430F741967Fb0de8](https://filfox.info/en/address/0xDD6FdE56432Cd3c868FEC7F1430F741967Fb0de8) <br>- Filecoin Calibration Testnet: [0x94C5774DEa83a921244BF362a98c12A5aAD18c87](https://calibration.filfox.info/en/address/0x94C5774DEa83a921244BF362a98c12A5aAD18c87) <br> - Furnace Testnet: [0xbf6b0Ed504bf595021a634e5d7161DD20ea42f18](https://blockscout.firepit.network/address/0xbf6b0Ed504bf595021a634e5d7161DD20ea42f18) | 
| RandomnessSender Implementation | Handles conditional encryption requests, callbacks, and fee collection. | <br> - Base Sepolia: [0xe26EB6390F9068Dc5D113DBA5A6831143D426DAB](https://sepolia.basescan.org/address/0xe26EB6390F9068Dc5D113DBA5A6831143D426DAB) <br> - Polygon PoS: [0xe26EB6390F9068Dc5D113DBA5A6831143D426DAB](https://polygonscan.com/address/0xe26EB6390F9068Dc5D113DBA5A6831143D426DAB) <br> - Optimism Sepolia: [0xe26EB6390F9068Dc5D113DBA5A6831143D426DAB](https://sepolia-optimism.etherscan.io/address/0xe26EB6390F9068Dc5D113DBA5A6831143D426DAB) <br> - Arbitrum Sepolia: [0xe26EB6390F9068Dc5D113DBA5A6831143D426DAB](https://sepolia.arbiscan.io/address/0xe26EB6390F9068Dc5D113DBA5A6831143D426DAB) <br> - Avalanche (C-Chain) Testnet: [0xe26EB6390F9068Dc5D113DBA5A6831143D426DAB](https://testnet.snowtrace.io/address/0xe26EB6390F9068Dc5D113DBA5A6831143D426DAB) <br> - Sei Testnet: [0xe26EB6390F9068Dc5D113DBA5A6831143D426DAB](https://seitrace.com/address/0xe26EB6390F9068Dc5D113DBA5A6831143D426DAB?chain=atlantic-2) <br>- Filecoin Mainnet: [0x03ea800bcD11aF907508Fbfb7BC122AfDDAcE99f](https://filfox.info/en/address/0x03ea800bcD11aF907508Fbfb7BC122AfDDAcE99f) <br>- Filecoin Calibration Testnet: [0xe6fB2eBF9aB76C5053428106750835d98cDDC058](https://calibration.filfox.info/en/address/0xe6fB2eBF9aB76C5053428106750835d98cDDC058) <br> - Furnace Testnet: [0xaaEf76DC51579aCdD847c94ECdd2E851fE91f833](https://blockscout.firepit.network/address/0xaaEf76DC51579aCdD847c94ECdd2E851fE91f833) | 
| SignatureSender Proxy | Upgradeable proxy for DecryptionSender. | <br> - Base Sepolia: [0x7C58c2EC510BcA7db09dc4039115F0CcEBA2e8B8](https://sepolia.basescan.org/address/0x7C58c2EC510BcA7db09dc4039115F0CcEBA2e8B8) <br> - Polygon PoS: [0x7C58c2EC510BcA7db09dc4039115F0CcEBA2e8B8](https://polygonscan.com/address/0x7C58c2EC510BcA7db09dc4039115F0CcEBA2e8B8) <br> - Optimism Sepolia: [0x7C58c2EC510BcA7db09dc4039115F0CcEBA2e8B8](https://sepolia-optimism.etherscan.io/address/0x7C58c2EC510BcA7db09dc4039115F0CcEBA2e8B8) <br> - Arbitrum Sepolia: [0x7C58c2EC510BcA7db09dc4039115F0CcEBA2e8B8](https://sepolia.arbiscan.io/address/0x7C58c2EC510BcA7db09dc4039115F0CcEBA2e8B8) <br> - Avalanche (C-Chain) Testnet: [0x7C58c2EC510BcA7db09dc4039115F0CcEBA2e8B8](https://testnet.snowtrace.io/address/0x7C58c2EC510BcA7db09dc4039115F0CcEBA2e8B8) <br> - Sei Testnet: [0x7C58c2EC510BcA7db09dc4039115F0CcEBA2e8B8](https://seitrace.com/address/0x7C58c2EC510BcA7db09dc4039115F0CcEBA2e8B8?chain=atlantic-2) <br>- Filecoin Mainnet: [0x01065df04A698B3Eb1b195b3952a098A97659Aba](https://filfox.info/en/address/0x01065df04A698B3Eb1b195b3952a098A97659Aba)<br>- Filecoin Calibration Testnet:[0xad16eeC3A1dc1F3335A04578C088EEa09c9dc05A](https://calibration.filfox.info/en/address/0xad16eeC3A1dc1F3335A04578C088EEa09c9dc05A) <br> - Furnace Testnet: [0xdddDB36316E395FdcF6F1A5D323Ea4165070eF5f](https://blockscout.firepit.network/address/0xdddDB36316E395FdcF6F1A5D323Ea4165070eF5f) | 
| SignatureSender Implementation | Contract used by offchain oracle to fulfill conditional encryption requests. | <br> - Base Sepolia: [0x7be613b1c7245058A7C92B6C2FaD8fde6016b630](https://sepolia.basescan.org/address/0x7be613b1c7245058A7C92B6C2FaD8fde6016b630) <br> - Polygon PoS: [0x7be613b1c7245058A7C92B6C2FaD8fde6016b630](https://polygonscan.com/address/0x7be613b1c7245058A7C92B6C2FaD8fde6016b630) <br> - Optimism Sepolia: [0x7be613b1c7245058A7C92B6C2FaD8fde6016b630](https://sepolia-optimism.etherscan.io/address/0x7be613b1c7245058A7C92B6C2FaD8fde6016b630) <br> - Arbitrum Sepolia: [0x7be613b1c7245058A7C92B6C2FaD8fde6016b630](https://sepolia.arbiscan.io/address/0x7be613b1c7245058A7C92B6C2FaD8fde6016b630) <br> - Avalanche (C-Chain) Testnet: [0x7be613b1c7245058A7C92B6C2FaD8fde6016b630](https://testnet.snowtrace.io/address/0x7be613b1c7245058A7C92B6C2FaD8fde6016b630) <br> - Sei Testnet: [0x7be613b1c7245058A7C92B6C2FaD8fde6016b630](https://seitrace.com/address/0x7be613b1c7245058A7C92B6C2FaD8fde6016b630?chain=atlantic-2) <br>- Filecoin Mainnet: [0x8d5fC647A864C522C2BB5Ba58A25715ED8778104](https://filfox.info/en/address/0x8d5fC647A864C522C2BB5Ba58A25715ED8778104)<br>- Filecoin Calibration Testnet: [0x6227e53F12B7bdCB55664ae100707169a77F207F](https://calibration.filfox.info/en/address/0x6227e53F12B7bdCB55664ae100707169a77F207F) <br> - Furnace Testnet: [0x80bF678c154F09479B4BC07B0906A9ef8Ac561Ad](https://blockscout.firepit.network/address/0x80bF678c154F09479B4BC07B0906A9ef8Ac561Ad) | 
| SignatureSchemeAddressProvider | Stores contract addresses for signature schemes. | <br> - Base Sepolia: [0xaF85d5C7F8225FcF9Fe007B928A22d55cbA1947F](https://sepolia.basescan.org/address/0xaF85d5C7F8225FcF9Fe007B928A22d55cbA1947F) <br> - Polygon PoS: [0xaF85d5C7F8225FcF9Fe007B928A22d55cbA1947F](https://polygonscan.com/address/0xaF85d5C7F8225FcF9Fe007B928A22d55cbA1947F) <br> - Optimism Sepolia: [0xaF85d5C7F8225FcF9Fe007B928A22d55cbA1947F](https://sepolia-optimism.etherscan.io/address/0xaF85d5C7F8225FcF9Fe007B928A22d55cbA1947F) <br> - Arbitrum Sepolia: [0xaF85d5C7F8225FcF9Fe007B928A22d55cbA1947F](https://sepolia.arbiscan.io/address/0xaF85d5C7F8225FcF9Fe007B928A22d55cbA1947F) <br> - Avalanche (C-Chain) Testnet: [0xaF85d5C7F8225FcF9Fe007B928A22d55cbA1947F](https://testnet.snowtrace.io/address/0xaF85d5C7F8225FcF9Fe007B928A22d55cbA1947F) <br> - Sei Testnet: [0xaF85d5C7F8225FcF9Fe007B928A22d55cbA1947F](https://seitrace.com/address/0xaF85d5C7F8225FcF9Fe007B928A22d55cbA1947F?chain=atlantic-2) <br>- Filecoin Mainnet: [0xF0E404d9F74ef1283350C0BC9628928fbA9D4d6c](https://filfox.info/en/address/0xF0E404d9F74ef1283350C0BC9628928fbA9D4d6c) <br>- Filecoin Calibration Testnet: [0xD1AD99F76E3FE4978B022d78c31BBC58f5c56548](https://calibration.filfox.info/en/address/0xD1AD99F76E3FE4978B022d78c31BBC58f5c56548) <br> - Furnace Testnet: [0xee496cCc37cf5d9a180fFd88670b62722fea0153](https://blockscout.firepit.network/address/0xee496cCc37cf5d9a180fFd88670b62722fea0153) | 
| BN254SignatureScheme | BN254 pairing-based signature verifier. | <br> - Base Sepolia: [0xF66afD0B5F7A65CddDe885128456EB0BdC85EA94](https://sepolia.basescan.org/address/0xF66afD0B5F7A65CddDe885128456EB0BdC85EA94) <br> - Polygon PoS: [0xF66afD0B5F7A65CddDe885128456EB0BdC85EA94](https://polygonscan.com/address/0xF66afD0B5F7A65CddDe885128456EB0BdC85EA94) <br> - Optimism Sepolia: [0xF66afD0B5F7A65CddDe885128456EB0BdC85EA94](https://sepolia-optimism.etherscan.io/address/0xF66afD0B5F7A65CddDe885128456EB0BdC85EA94) <br> - Arbitrum Sepolia: [0xF66afD0B5F7A65CddDe885128456EB0BdC85EA94](https://sepolia.arbiscan.io/address/0xF66afD0B5F7A65CddDe885128456EB0BdC85EA94) <br> - Avalanche (C-Chain) Testnet: [0xF66afD0B5F7A65CddDe885128456EB0BdC85EA94](https://testnet.snowtrace.io/address/0xF66afD0B5F7A65CddDe885128456EB0BdC85EA94) <br> - Sei Testnet: [0xF66afD0B5F7A65CddDe885128456EB0BdC85EA94](https://seitrace.com/address/0xF66afD0B5F7A65CddDe885128456EB0BdC85EA94?chain=atlantic-2) <br> - Filecoin Mainnet: [0xC1F5c6eA56496f47F9734B667d605Db5EA321f79](https://filfox.info/en/address/0xC1F5c6eA56496f47F9734B667d605Db5EA321f79) <br> - Filecoin Calibration Testnet: [0xA61E77A5210cDe8aEdcBFF2FD423093b6FdFCC00](https://calibration.filfox.info/en/address/0xA61E77A5210cDe8aEdcBFF2FD423093b6FdFCC00) <br> - Furnace Testnet: [0xda537C42c0Ce3D1c89e961c931f1c8903cBb824c](https://blockscout.firepit.network/address/0xda537C42c0Ce3D1c89e961c931f1c8903cBb824c) | 


### How to use the Solidity interaface

1. **Import the library**

    Start by importing the `RandomnessReceiverBase.sol` abstract contract into your smart contract. This contract provides the interface for making randomness requests and handling callbacks

    ```solidity
    // Import the abstract RandomnessReceiverBase contract for creating randomness requests and handling randomness callbacks
    import { RandomnessReceiverBase } from "randomness-solidity/src/RandomnessReceiverBase.sol";
    ```

2. **Extend the  `RandomnessReceiverBase` contract**

   To use the library, your contract must inherit from `RandomnessReceiverBase` and specify the deployed `RandomnessSender` (proxy) contract address from your desired [network](#supported-networks) in the constructor. 

    ```solidity
    contract DiceRoller is RandomnessReceiverBase {
        /// @notice Stores the latest received randomness value
        bytes32 public randomness;

        /// @notice Stores the request ID of the latest randomness request
        uint256 public requestId;

        /// @notice Initializes the contract with the address of the randomness sender
        /// @param randomnessSender The address of the randomness provider
        constructor(address randomnessSender) RandomnessReceiverBase(randomnessSender) {}
        ...
    }
    ```

3. **Request Randomness**

    Requests can be paid for in two ways, either direct funding or subscription. 

    For both payment options, the [RandomnessReceiverBase](/src/RandomnessReceiverBase.sol) contract provides two functions for making requests:
    - Direct Funding: `_requestRandomnessPayInNative(uint32 callbackGasLimit)` 
    - Subscription: `_requestRandomnessWithSubscription(uint32 callbackGasLimit)`.

    To estimate the price of a randomness request, you can use the `calculateRequestPriceNative()` function in the `RandomnessSender` contract (ensure that a buffer is added to the returned estimate to accomodate network gas price fluctuations between blocks):

    ```solidity
    function calculateRequestPriceNative(uint32 _callbackGasLimit)
        public
        view
        override (FeeCollector, IRandomnessSender)
        returns (uint256)
    {
        return _calculateRequestPriceNative(_callbackGasLimit, tx.gasprice);
    }
    ```

    In this example, we will be showing how to use both funding options to roll a dice. Both functions return the request id (and request price for the direct funding option).

    To recap, using the internal `_requestRandomnessPayInNative()` and `_requestRandomnessWithSubscription()` functions derived from `RandomnessReceiverBase`, we can send randomness requests to the dcipher network using the direct funding and subscription payment options respectively. These requests are forwarded through the deployed `RandomnessSender` contract on a supported network. 

    When calling `_requestRandomnessPayInNative()`, we need to fund the request via `msg.value` which should cover the estimated price for the request. It is advised to add a buffer to cover fluctuations in network gas price to avoid delays in processing the request. 

    Both functions return a `requestId`, which should be stored and can be used to verify the response when the randomness is delivered through a callback from `RandomnessSender`. For the subscription payment option, the `_requestRandomnessWithSubscription()` function, uses the `subscriptionId` variable set in `RandomnessReceiverBase`.

    ```solidity
    function rollDiceWithDirectFunding(uint32 callbackGasLimit) external payable returns (uint256, uint256) {
        // create randomness request using direct funding
        (uint256 requestID, uint256 requestPrice) = _requestRandomnessPayInNative(callbackGasLimit);
        // store request id
        requestId = requestID;
        return (requestID, requestPrice);
    }

    function rollDiceWithSubscription(uint32 callbackGasLimit) external payable returns (uint256) {
        // create randomness request using subscription
        uint256 requestID = _requestRandomnessWithSubscription(callbackGasLimit);
        // store request id
        requestId = requestID;
        return requestID;
    }
    ```

4. **Handle the Randomness Callback**

    When the dcipher network fulfills the request, the `onRandomnessReceived` callback will be triggered with the generated random value which is **automatically verified** with the specifed threshold signature scheme . You must override this function to handle the response.
    
    ```solidity
    /**
     * @dev Callback function that is called when randomness is received.
     * @param requestID The ID of the randomness request that was made.
     * @param _randomness The random value received.
     *
     * This function verifies that the received `requestID` matches the one that
     * was previously stored. If they match, it updates the `randomness` state variable
     * with the newly received random value.
     */
    function onRandomnessReceived(uint64 requestID, bytes32 _randomness) internal override {
        require(requestId == requestID, "Request ID mismatch");
        randomness = _randomness;
    }
    ```

### Example Contract
```solidity
/// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {RandomnessReceiverBase} from "../RandomnessReceiverBase.sol";

/// @title MockRandomnessReceiver contract
/// @author Randamu
/// @notice A contract that requests and consumes randomness
contract MockRandomnessReceiver is RandomnessReceiverBase {
    /// @notice Stores the latest received randomness value
    bytes32 public randomness;

    /// @notice Stores the request ID of the latest randomness request
    uint256 public requestId;

    /// @notice Initializes the contract with the address of the randomness sender
    /// @param randomnessSender The address of the randomness provider
    constructor(address randomnessSender, address owner) RandomnessReceiverBase(randomnessSender, owner) {}

    /// @notice Requests randomness using the direct funding option
    /// @dev Calls `_requestRandomnessPayInNative` to get a random value, updating `requestId` with the request ID
    function rollDiceWithDirectFunding(uint32 callbackGasLimit) external payable returns (uint256, uint256) {
        // create randomness request
        (uint256 requestID, uint256 requestPrice) = _requestRandomnessPayInNative(callbackGasLimit);
        // store request id
        requestId = requestID;
        return (requestID, requestPrice);
    }

    /// @notice Requests randomness using the subscription option
    /// @dev Calls `_requestRandomnessWithSubscription` to get a random value, updating `requestId` with the request ID
    function rollDiceWithSubscription(uint32 callbackGasLimit) external returns (uint256) {
        // create randomness request
        uint256 requestID = _requestRandomnessWithSubscription(callbackGasLimit);
        // store request id
        requestId = requestID;
        return requestID;
    }

    function cancelSubscription(address to) external onlyOwner {
        _cancelSubscription(to);
    }

    /// @notice Callback function that processes received randomness
    /// @dev Ensures the received request ID matches the stored one before updating state
    /// @param requestID The ID of the randomness request
    /// @param _randomness The random value received from the oracle
    function onRandomnessReceived(uint256 requestID, bytes32 _randomness) internal override {
        require(requestId == requestID, "Request ID mismatch");
        randomness = _randomness;
    }
}
```

#### Sharing Subscription Accounts 

To share a subscription account, the smart contract that owns the subscription must call the `updateSubscription()` function in `RandomnessSender` to approve other contracts to use its created `subscriptionId`.

```solidity
/// @notice Adds a list of consumer addresses to the Randamu subscription.
/// @dev Requires the subscription ID to be set before calling.
/// @param consumers An array of addresses to be added as authorized consumers.
function updateSubscription(address[] calldata consumers) external onlyOwner {
    require(subscriptionId != 0, "subID not set");
    for (uint256 i = 0; i < consumers.length; i++) {
        randomnessSender.addConsumer(subscriptionId, consumers[i]);
    }
```

After calling `updateSubscription` all approved contracts can then call the `setSubId` function and start making subscription conditional encryption requests using the shared (funded) subscription account. 

```solidity
/// @notice Sets the Randamu subscription ID used for conditional encryption oracle services.
/// @dev Only callable by the contract owner.
/// @param subId The new subscription ID to be set.
function setSubId(uint256 subId) external onlyOwner {
    subscriptionId = subId;
    emit NewSubscriptionId(subId);
}
```

Please note that all approved contracts must also implement `RandomnessReceiverBase.sol`.


## API Documentation

### RandomnessReceiverBase.sol
| Function  | Return | Description |
|----------|------------|------------|
| `_requestRandomnessPayInNative(uint32 callbackGasLimit)` | `uint256 requestID, uint256 requestPrice` |Requests the generation of a random value from the dcipher network |
| `_requestRandomnessWithSubscription(uint32 callbackGasLimit)` | `uint256 requestID` |Requests the generation of a random value from the dcipher network |
| `onRandomnessReceived(uint256 requestID, bytes32 randomness)` | n/a |	Callback function to be implemented by the inheriting contract. Called when the randomness is delivered.  |

### RandomnessSender.sol
| Function | Return | Description |
|----------|-------------|------------|
| `isInFlight(uint256 requestID)` | `bool` | Returns `true` if the specified randomness request is still pending. |
| `getRequest(uint256 requestID)` | `TypesLib.RandomnessRequest`  | Returns the details of the randomness request associated with the given request ID. The `RandomnessRequest` object (struct) contains the following variables for each request: `uint256 nonce; address callback;` |
| `getAllRequests()` | `TypesLib.RandomnessRequest[]` | Retrieves a list of all randomness requests submitted to the contract. |

### SignatureSender.sol
| Function | Return | Description |
|----------|-------------|------------|
| `isInFlight(uint256 requestID)` | `bool` | Returns true if the specified signature request is still pending.|
| `getRequest(uint256 requestID)` | `TypesLib.SignatureRequest` | Returns the details of the signature request associated with the given request ID.|
| `getPublicKey()` | `uint256[2] memory, uint256[2] memory` | Returns the public key components used in the signature verification process.|

### Randomness.sol
| Function | Return | Description |
|----------|-------------|------------|
|`function verify(address randomnessContract, address signatureContract, bytes calldata signature, uint256 requestID, address requester, string calldata schemeID)`  | `bool` | Verifies that the provided randomness is valid and was properly generated by the dcipher network for the given request.|

## License
This library is licensed under the MIT License which can be accessed [here](./LICENSE).

## Contributing  
Contributions are welcome! If you find a bug, have a feature request, or want to improve the code, feel free to open an issue or submit a pull request.

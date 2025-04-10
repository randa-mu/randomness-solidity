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
- **Modular Design**: Choose from multiple randomness  & signature schemes.


## Smart Contracts    

### Randomness
Provides functionality to generate and verify randomness based on conditional threshold signatures from the dcipher network.   
- ✨ `RandomnessReceiverBase.sol` - An abstract contract that developers **must implement** to request and receive randomness within their own smart contracts.
- `RandomnessSender.sol` - Handles the processing and management of randomness requests using the conditional signing mechanism provided by the dcipher threshold network. 

### Signature  
Because randomness is derived from conditional threshold signatures produced by the dcipher network, this library also includes contracts for requesting and processing signature requests using a defined schema. 
- `SignatureSchemeAddressProvider.sol` - Maintains the list of supported signature schemes (e.g., BLS).
- `SignatureReceiverBase.sol` - An abstract contract for requesting and receiving threshold signatures from the dcipher network. 
- `SignatureRequest.sol` - Core contract for managing conditional threshold signing of messages using the dcipher network.

> 💡 **Note:** You only need to extend `RandomnessReceiverBase.sol` to customize randomness requests. All other required contracts are already deployed on supported networks.

### Supported Networks

#### Filecoin Calibnet

| Contract                        | Address                                                                                                                             |
|---------------------------------|-------------------------------------------------------------------------------------------------------------------------------------|
| **RandomnessSender Proxy**      | [0x9c789bc7F2B5c6619Be1572A39F2C3d6f33001dC](https://calibration.filfox.info/en/address/0x9c789bc7F2B5c6619Be1572A39F2C3d6f33001dC) |
| RandomnessSender Implementation | [0xF684f13850932bC7B51bd6bFF9236FB19E55F2B1](https://calibration.filfox.info/en/address/0xF684f13850932bC7B51bd6bFF9236FB19E55F2B1) |
| SignatureSender Proxy           | [0x1c86A81D3CDD897aFdcA62a9b7219a39Aef7910B](https://calibration.filfox.info/en/address/0x1c86A81D3CDD897aFdcA62a9b7219a39Aef7910B) | 
| SignatureSender Implementation  | [0x1790de5a9fBA748DCAf05e3a1755Cf1DD6b9B0F8](https://calibration.filfox.info/en/address/0x1790de5a9fBA748DCAf05e3a1755Cf1DD6b9B0F8) |
| SignatureSchemeAddressProvider  | [0xD2b5084E68230D609AEaAe5E4cF7df9ebDd6375A](https://calibration.filfox.info/en/address/0xD2b5084E68230D609AEaAe5E4cF7df9ebDd6375A) |
| MockBN254SignatureScheme        | [0xE5aedc08Cf2B5650Cd84CE6DcaDC3763bAa8770B](https://calibration.filfox.info/en/address/0xE5aedc08Cf2B5650Cd84CE6DcaDC3763bAa8770B) |
| MockRandomnessReceiver          | [0x82345Cad6c5D11509F89281875269381d0673cd2](https://calibration.filfox.info/en/address/0x82345Cad6c5D11509F89281875269381d0673cd2) |

#### Base Sepolia

| Contract                        | Address                                                                                                                       | 
|---------------------------------|-------------------------------------------------------------------------------------------------------------------------------|
| **RandomnessSender Proxy**      | [0x31e01BCA94b787D3B4a16C378Bd5D200686dEb99](https://sepolia.basescan.org/address/0x31e01BCA94b787D3B4a16C378Bd5D200686dEb99) |
| RandomnessSender Implementation | [0xA4baaF6eF2a7B39b766027262ABA518ED43F365f](https://sepolia.basescan.org/address/0xA4baaF6eF2a7B39b766027262ABA518ED43F365f) |
| SignatureSender Proxy           | [0xace52a14d892393B8d38A51c2aa2E6d85a619c58](https://sepolia.basescan.org/address/0xace52a14d892393B8d38A51c2aa2E6d85a619c58) |
| SignatureSender Implementation  | [0xdbF8A47E90009a639859E72213449531663eFDeC](https://sepolia.basescan.org/address/0xdbF8A47E90009a639859E72213449531663eFDeC) |
| SignatureSchemeAddressProvider  | [0xB27E28956301eDB95d35181fAc7743E5378F5D50](https://sepolia.basescan.org/address/0xB27E28956301eDB95d35181fAc7743E5378F5D50) |
| BN254SignatureScheme            | [0xa03c70AC664F66e9eee5bA2497627133DBF02D8d](https://sepolia.basescan.org/address/0xa03c70AC664F66e9eee5bA2497627133DBF02D8d) |
| MockRandomnessReceiver          | [0x93B465392F8B4993Db724690A3b527Ec035d3a9F](https://sepolia.basescan.org/address/0x93B465392F8B4993Db724690A3b527Ec035d3a9F) |

#### Polygon PoS

| Contract                        | Address                                                                                                                  | 
|---------------------------------|--------------------------------------------------------------------------------------------------------------------------|
| **RandomnessSender Proxy**      | [0x31e01BCA94b787D3B4a16C378Bd5D200686dEb99](https://polygonscan.com/address/0x31e01BCA94b787D3B4a16C378Bd5D200686dEb99) |
| RandomnessSender Implementation | [0xA4baaF6eF2a7B39b766027262ABA518ED43F365f](https://polygonscan.com/address/0xA4baaF6eF2a7B39b766027262ABA518ED43F365f) |
| SignatureSender Proxy           | [0xace52a14d892393B8d38A51c2aa2E6d85a619c58](https://polygonscan.com/address/0xace52a14d892393B8d38A51c2aa2E6d85a619c58) |
| SignatureSender Implementation  | [0xdbF8A47E90009a639859E72213449531663eFDeC](https://polygonscan.com/address/0xdbF8A47E90009a639859E72213449531663eFDeC) |
| SignatureSchemeAddressProvider  | [0xB27E28956301eDB95d35181fAc7743E5378F5D50](https://polygonscan.com/address/0xB27E28956301eDB95d35181fAc7743E5378F5D50) |
| BN254SignatureScheme            | [0xa03c70AC664F66e9eee5bA2497627133DBF02D8d](https://polygonscan.com/address/0xa03c70AC664F66e9eee5bA2497627133DBF02D8d) |
| MockRandomnessReceiver          | [0x93B465392F8B4993Db724690A3b527Ec035d3a9F](https://polygonscan.com/address/0x93B465392F8B4993Db724690A3b527Ec035d3a9F) |

## Quick Start

### Installation
To get started, install the randomness-solidity library in your smart contract project using your preferred development tool.

**Hardhat (npm)**
```bash
npm install randomness-solidity
```  
**Foundry**
```bash
forge install randa-mu/randomness-solidity
```

### How to use

1. **Import the library**

    Start by importing the `RandomnessReceiverBase.sol` abstract contract into your smart contract. This contract provides the interface for making randomness requests and handling callbacks

    ```solidity
    // Import the abstract RandomnessReceiverBase contract for creating randomness requests and handling randomness callbacks
    import { RandomnessReceiverBase } from "randomness-solidity/src/RandomnessReceiverBase.sol";
    ```

2. **Extend the  `RandomnessReceiverBase` contract**

   To use the library, your contract must inherit from `RandomnessReceiverBase` and specify the deployed `RandomnessSender` contract address from your desired [network](#support-network) in the constructor. 

    ```solidity
    contract DiceRoller is RandomnessReceiverBase {
        constructor(address randomnessSender) RandomnessReceiverBase(randomnessSender) {}
        ...
    }
    ```

3. **Request Randomness**

    Use the `requestRandomness()` function to send a randomness request to the dcipher network. This request will be forwarded to the pre-deployed `RandomnessSender` contract.

    The function returns a `requestId`, which should be stored to verify the response when randomness is delivered.

    ```solidity
    /**
     * @dev Requests randomness.
     *
     * This function calls the `requestRandomness` method to request a random value.
     * The `requestId` is updated with the ID returned from the randomness request.
     */
    function rollDice() external {
        requestId = requestRandomness();
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
    function onRandomnessReceived(uint256 requestID, bytes32 _randomness) internal override {
        require(requestId == requestID, "Request ID mismatch");
        randomness = _randomness;
    }
    ```

### Example Contract
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import { RandomnessReceiverBase } from "randomness-solidity/src/RandomnessReceiverBase.sol";

contract DiceRoller is RandomnessReceiverBase {
    bytes32 public diceNumber;
    uint256 public requestId;

    constructor(address randomnessSender) RandomnessReceiverBase(randomnessSender) {}

    function rollDice() external {
        requestId = requestRandomness();
    }

    function onRandomnessReceived(uint256 requestID, bytes32 _randomness) internal override {
        require(requestId == requestID, "Request ID mismatch");
        diceNumber = _randomness;
    }
}
```

## API Documentation

### RandomnessReceiverBase.sol
| Function  | Return | Description |
|----------|------------|------------|
| `requestRandomness()` | `uint256 requestID` |Requests the generation of a random value from the dcipher network | 
| `onRandomnessReceived(uint256 requestID, bytes32 randomness)` | n/a |	Callback function to be implemented by the inheriting contract. Called when the randomness is delivered.  |
 
### RandomnessSender.sol
| Function | Return | Description |
|----------|-------------|------------|
| `isInFlight(uint256 requestID)` | `bool` | Returns `true` if the specified randomness request is still pending. |
| `getRequest(uint256 requestId)` | `TypesLib.RandomnessRequest`  | Returns the details of the randomness request associated with the given request ID.  |
| `getAllRequests()` | `TypesLib.RandomnessRequest[]` | Retrieves all randomness requests submitted to the contract.|

### SignatureSender.sol
| Function | Return | Description |
|----------|-------------|------------|
| `isInFlight(uint256 requestID)` | `bool` | Returns true if the specified signature request is still pending.|
| `getRequest(uint256 requestID)` | `TypesLib.SignatureRequest` | Returns the details of the signature request associated with the given request ID.|
| `getPublicKey()` | `uint256[2] memory, uint256[2] memory` | Returns the public key components used in the signature verification process.|

### SignatureSender.sol
| Function | Return | Description |
|----------|-------------|------------|
|`function verify(address randomnessContract, address signatureContract, bytes calldata signature uint256 requestID, address requester)`  | `bool` | Verifies that the provided randomness is valid and was properly generated by the dcipher network for the given request.|

## License
This library is licensed under the MIT License which can be accessed [here](./LICENSE).

## Contributing  
Contributions are welcome! If you find a bug, have a feature request, or want to improve the code, feel free to open an issue or submit a pull request.

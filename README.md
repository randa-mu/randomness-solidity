## randomness-solidity

This repository contains the Solidity-based smart contracts library that facilitates Randamu's on-chain randomness requests.

By leveraging this library, smart contract developers can leverage on verifiable randomness on-chain that is tamper-proof and bias resistant.

This library is designed with modularity and simplicity in mind, allowing developers to extend and integrate it into their existing projects easily.


### Smart Contract Addresses

| Contract        | Address | Network          |
|-----------------|---------|------------------|
| SignatureSender Proxy |  0x1c86A81D3CDD897aFdcA62a9b7219a39Aef7910B  | Filecoin Calibration Testnet |
| SignatureSender Implementation | 0x1790de5a9fBA748DCAf05e3a1755Cf1DD6b9B0F8   | Filecoin Calibration Testnet |
| RandomnessSender Proxy |  0x9c789bc7F2B5c6619Be1572A39F2C3d6f33001dC  | Filecoin Calibration Testnet |
| RandomnessSender Implementation |  0xF684f13850932bC7B51bd6bFF9236FB19E55F2B1  | Filecoin Calibration Testnet |
| SignatureSchemeAddressProvider |  0xD2b5084E68230D609AEaAe5E4cF7df9ebDd6375A  | Filecoin Calibration Testnet |
| MockBN254SignatureScheme | 0xE5aedc08Cf2B5650Cd84CE6DcaDC3763bAa8770B   | Filecoin Calibration Testnet |
| MockRandomnessReceiver |  0x6e7B9Ccb146f6547172E5cef237BBc222EC4D676  | Filecoin Calibration Testnet |


### Using the Solidity Interfaces

#### Installation

##### Hardhat (npm)

```sh
$ npm install randomness-solidity
```

##### Foundry 
```sh
$ forge install randa-mu/randomness-solidity
```

#### Importing

To use this library in your project, import the required files into your contract and use the proxy contract address for RandomnessSender in the constructor as the randomnessSender address parameter:

```solidity
// Import the abstract RandomnessReceiverBase contract for creating randomness requests and handling randomness callbacks
import {RandomnessReceiverBase} from "../RandomnessReceiverBase.sol";
```

#### Example Usage

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {RandomnessReceiverBase} from "../RandomnessReceiverBase.sol";

contract MockRandomnessReceiver is RandomnessReceiverBase {
    bytes32 public randomness;
    uint256 public requestId;

    constructor(address randomnessSender) RandomnessReceiverBase(randomnessSender) {}

    /**
     * @dev Requests randomness.
     *
     * This function calls the `requestRandomness` method to request a random value.
     * The `requestId` is updated with the ID returned from the randomness request.
     */
    function rollDice() external {
        requestId = requestRandomness();
    }

    /**
     * @dev Callback function that is called when randomness is received.
     * @param requestID The ID of the randomness request that was made.
     * @param _randomness The random value received.
     *
     * This function verifies that the received `requestID` matches the one that
     * was previously stored. If they match, it updates the `randomness` state variable
     * with the newly received random value.
     *
     * Reverts if the `requestID` does not match the stored `requestId`, ensuring that
     * the randomness is received in response to a valid request.
     */
    function onRandomnessReceived(uint256 requestID, bytes32 _randomness) internal override {
        require(requestId == requestID, "Request ID mismatch");
        randomness = _randomness;
    }
}
```

### How It Works

* Randomness Request: The `requestRandomness` function allows the receiver smart contract to request randomness via the `RandomnessSender` contract.
* Callback Handling: The inherited `onRandomnessReceived` function allows the smart contract developer implement custom logic to handle the received randomness from Randamu's threshold network.

### Licensing

This library is licensed under the MIT License which can be accessed [here](LICENSE).

### Contributing

Contributions are welcome! If you find a bug, have a feature request, or want to improve the code, feel free to open an issue or submit a pull request.

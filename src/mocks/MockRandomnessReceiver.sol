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
     * This function calls the `requestRandomness` method to request a random value
     * from an oracle service, which will be available at the given chain height.
     * The `requestId` is updated with the ID returned from the randomness request.
     */
    function rollDice() external {
        requestId = requestRandomness();
    }

    /**
     * @dev Callback function that is called when randomness is received from the oracle.
     * @param requestID The ID of the randomness request that was made.
     * @param _randomness The random value received from the oracle.
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

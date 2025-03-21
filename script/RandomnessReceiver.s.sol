// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {MockRandomnessReceiver} from "../src/mocks/MockRandomnessReceiver.sol";

contract RandomnessReceiverScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address admin = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        address randomnessSenderAddr = 0x9c789bc7F2B5c6619Be1572A39F2C3d6f33001dC;

        MockRandomnessReceiver mockRandomnessReceiver = new MockRandomnessReceiver(randomnessSenderAddr);
        console.log("\nMockRandomnessReceiver deployed at: ", address(mockRandomnessReceiver));
    }
}

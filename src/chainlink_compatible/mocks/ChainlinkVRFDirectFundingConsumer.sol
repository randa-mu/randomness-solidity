// SPDX-License-Identifier: MIT
// An example of a consumer contract that directly pays for each request.
pragma solidity ^0.8;

///// UPDATE IMPORTS TO V2.5 /////
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

import {ChainlinkVRFV2PlusWrapperConsumerBaseStub} from "../internal/ChainlinkVRFV2PlusWrapperConsumerBaseStub.sol";

/// @dev THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
/// @dev THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
/// @dev DO NOT USE THIS CODE IN PRODUCTION.
/// @dev Adopted from: https://docs.chain.link/vrf/v2-5/migration-from-v2#direct-funding-example-code

///// INHERIT NEW WRAPPER CONSUMER BASE CONTRACT /////
contract ChainlinkVRFDirectFundingConsumer is ChainlinkVRFV2PlusWrapperConsumerBaseStub, ConfirmedOwner {
    /// @notice Event to log direct transfer of native tokens to the contract
    event Received(address, uint256);

    /// @notice Event to log deposits of native tokens
    event Funded(address indexed sender, uint256 amount);

    /// @notice Event to log withdrawals of native tokens
    event Withdrawn(address indexed recipient, uint256 amount);

    uint256 public requestId;
    mapping(uint256 => uint256[]) public randomWordsOf;

    /// @notice USE RANDAMU WRAPPER from src/chainlink_compatible/ChainlinkVRFV2PlusWrapperAdapter.sol IN CONSTRUCTOR
    constructor(address wrapperAddress)
        ConfirmedOwner(msg.sender)
        ChainlinkVRFV2PlusWrapperConsumerBaseStub(wrapperAddress) ///// ONLY PASS IN WRAPPER ADDRESS /////
    {}

    function requestRandomWords(uint32 callbackGasLimit, bool /*enableNativePayment*/ )
        external
        onlyOwner
        returns (uint256)
    {
        /// @notice Request parameters
        uint16 requestConfirmations = 3;
        uint32 numWords = 1;
        bool enableNativePayment = true; // Randamu only accepts native payment

        ///// UPDATE TO NEW V2.5 REQUEST FORMAT: ADD EXTRA ARGS /////
        bytes memory extraArgs =
            VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: enableNativePayment}));

        uint256 _requestId;
        uint256 reqPrice;

        ///// USE THIS FUNCTION TO PAY IN NATIVE TOKENS /////
        (_requestId, reqPrice) = requestRandomnessPayInNative(
            callbackGasLimit,
            requestConfirmations,
            numWords,
            extraArgs ///// PASS IN EXTRA ARGS /////
        );

        requestId = _requestId;
        return _requestId;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        randomWordsOf[_requestId] = _randomWords;
    }

    function getRandomWords(uint256 _requestId) external view returns (uint256[] memory) {
        return randomWordsOf[_requestId];
    }

    /// @notice Function to fund the contract with native tokens for direct funding requests.
    function fundContractNative() external payable {
        require(msg.value > 0, "You must send some ETH");
        emit Funded(msg.sender, msg.value);
    }

    /// @notice Function to withdraw native tokens from the contract.
    /// @dev Only callable by contract owner.
    /// @param amount The amount to withdraw.
    /// @param recipient The address to send the tokens to.
    function withdrawNative(uint256 amount, address recipient) external onlyOwner {
        require(getBalance() >= amount, "Insufficient funds in contract");
        payable(recipient).transfer(amount);
        emit Withdrawn(recipient, amount);
    }

    /// @notice The receive function is executed on a call to the contract with empty calldata.
    /// @dev This is the function that is executed on plain Ether transfers (e.g. via .send() or .transfer()).
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}

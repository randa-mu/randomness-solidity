// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {ISignatureScheme} from "../interfaces/ISignatureScheme.sol";

/// @title SignatureSchemeBase contract
/// @author Randamu
/// @notice Base contract that all signature scheme contracts must implement.
abstract contract SignatureSchemeBase is ISignatureScheme {
    /// @notice Returns the current blockchain chain ID.
    /// @dev Uses inline assembly to retrieve the `chainid` opcode.
    /// @return chainId The current chain ID of the network.
    function getChainId() public view returns (uint256 chainId) {
        assembly {
            chainId := chainid()
        }
    }
}

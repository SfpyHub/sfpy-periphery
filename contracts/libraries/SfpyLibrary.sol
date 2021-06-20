// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SafeMath.sol";

library SfpyLibrary {
    using SafeMath for uint256;
    /// @dev calculates the CREATE2 address for a pair without 
    /// @dev making any external calls
    /// @param factory contract address of the factory
    /// @param token contract address of the token
    function poolFor(address factory, address token) internal pure returns (address pool) {
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex'ff',
                            factory,
                            keccak256(abi.encodePacked(token)),
                            hex'299fc1dd996bb3989ecb29cbe15651bd653d7f3cba7229ed963bff23482465bc'
                        )
                    )
                )
            )
        );
    }

    /// @dev calculates the minimum amount needed to be returned back from a flash loan
    /// @dev including the 0.1% fee
    /// @param amountOut the amount of tokens that were borrowed
    function getAmountIn(uint256 amountOut) internal pure returns (uint256 amountIn) {
      uint256 feeAmount = amountOut.mul(10 ** 15) / (10 ** 18); // .1% fee (10 ** 15 / 10*18)
      amountIn = amountOut.add(feeAmount);
    }
}

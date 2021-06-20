// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISfpyCallback {
  /// @dev An interface that accepts a payment from a payee in order to execute 
  /// @dev any arbitrary code in a smart contract
  /// @param sender the address of the payee making the payment
  /// @param token the contract address of the token being used
  /// @param amount the amount of tokenAmount sent
  /// @param data any aribitrary data needed to execute the Flash App
  function afterPay(address sender, address token, uint256 amount, bytes calldata data) external;
}
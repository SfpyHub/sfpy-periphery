// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IExampleDummyExchange {
	function token() external view returns (address);
  function doubleUp(uint256 amount) external returns (uint256 amountOut);
}
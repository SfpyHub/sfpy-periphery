// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IExampleAirDrop {
	function token() external view returns (address);
  function transfer(uint amount, address to) external returns (uint amountOut);
}
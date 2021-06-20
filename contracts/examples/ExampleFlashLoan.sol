// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@sfpy/core/contracts/interfaces/ISfpyBorrower.sol';
import '@sfpy/core/contracts/interfaces/ISfpyPool.sol';

import '../libraries/SafeMath.sol';
import '../libraries/SfpyLibrary.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/IWETH.sol';

import './IExampleDummyExchange.sol';

contract ExampleFlashLoan is ISfpyBorrower {
	using SafeMath for uint;

	address immutable factory;
	address immutable exchange;

  constructor(address _factory, address _exchange) {
    factory = _factory;
    exchange = _exchange;
  }

  receive() external payable {}

  function borrow(address sender, uint amount, bytes calldata data) external override {
    address addr = ISfpyPool(msg.sender).token();
    assert(msg.sender == SfpyLibrary.poolFor(factory, addr)); // ensure that msg.sender is actually a V2 pair

    require(sender != address(0), 'INVALID SENDER');
    require(data.length > 0, 'INVALID DATA');

    address dummyTokenAddress = IExampleDummyExchange(exchange).token();
    require(dummyTokenAddress == addr, 'INVALID_TOKENS');

    IERC20 token = IERC20(addr);
    token.approve(exchange, amount);

    // Transfer amount borrowed to exchange and receive double the amount back
    // Fake arbitrage
    uint amountReceived = IExampleDummyExchange(exchange).doubleUp(amount);
    // Get the required amount to be repaid back to the pool
    // amount borrowed plus 0.1% fee
    uint amountRequired = SfpyLibrary.getAmountIn(amount);

    assert(amountReceived > amountRequired);
    assert(token.transfer(msg.sender, amountRequired)); // return tokens to pool and keep the rest as profit
  }
}
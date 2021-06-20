// SPDX-License-Identifier: MIT
pragma solidity >0.6.6;

import './IExampleAirDrop.sol';
import '../libraries/SafeMath.sol';
import '../interfaces/IERC20.sol';

// First 10 customers receive all the tokens
contract ExampleAirDrop is IExampleAirDrop {
	using SafeMath for uint;

	address public immutable override token;
	bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

	function _safeTransfer(address _token, address to, uint value) private {
		(bool success, bytes memory data) = _token.call(abi.encodeWithSelector(SELECTOR, to, value));
		require(success && (data.length == 0 || abi.decode(data, (bool))), 'DUMMY: TRANSFER_FAILED');
	}

	constructor(address _token) {
		token = _token;
	}

	// Transfer a 10th of the balance to the customer.
	function transfer(uint amount, address to) external virtual override returns (uint amountOut) {
		require(amount > 0, 'DUMMY: INSUFFICIENT_AMOUNT');
		address _token = token;
		uint balance = IERC20(_token).balanceOf(address(this));
		amountOut = balance / 10;
		require(balance > amountOut, 'DUMMY: INSUFFICIENT_LIQUIDITY');
		_safeTransfer(_token, to, amountOut);
	}
}
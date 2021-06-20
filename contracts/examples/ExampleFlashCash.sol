// SPDX-License-Identifier: MIT
pragma solidity >0.6.6;

import '../libraries/SafeMath.sol';
import '../libraries/SfpyLibrary.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/ISfpyCallback.sol';
import '../interfaces/ISfpyRouter.sol';

import './IExampleAirDrop.sol';

contract ExampleFlashCash is ISfpyCallback {
	using SafeMath for uint;

	address immutable router;
	address immutable airdrop;

  constructor(address _router, address _airdrop) {
    router = _router;
    airdrop = _airdrop;
  }

  receive() external payable {}

  function afterPay(address sender, address token, uint256 amount, bytes calldata data) external override {
    address _router = router;
    address _airdrop = airdrop;
    assert(msg.sender == _router); // ensure that msg.sender is actually the router

    require(amount > 0, 'INSUFFICIENT_AMOUNT');
    require(token != address(0), 'INVALID_TOKEN');
    require(sender != address(0), 'INVALID_SENDER');
    require(data.length > 0, 'INVALID_DATA');

    uint amountSent = IExampleAirDrop(_airdrop).transfer(amount, sender);
    assert(amountSent > 0);
  }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './IExampleDummyExchange.sol';
import '../libraries/SafeMath.sol';
import '../interfaces/IERC20.sol';

contract ExampleDummyExchange is IExampleDummyExchange {
    using SafeMath for uint256;

    address public immutable override token;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    function _safeTransfer(
        address _token,
        address to,
        uint256 value
    ) private {
        (bool success, bytes memory data) = _token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'DUMMY: TRANSFER_FAILED');
    }

    constructor(address _token) {
        token = _token;
    }

    // Sends back double the amount if balances are enough
    // Purely for use in the example flash loan contract
    function doubleUp(uint256 amount) external virtual override returns (uint256 amountOut) {
        address _token = token;
        uint256 balance = IERC20(_token).balanceOf(address(this));
        require(balance > amount.mul(2), 'DUMMY: INSUFFICIENT_LIQUIDITY');
        bool success = IERC20(_token).transferFrom(msg.sender, address(this), amount);
        require(success, 'DUMMY: DEPOSIT_FAILED');
        amountOut = amount.mul(2);
        _safeTransfer(_token, msg.sender, amountOut);
    }
}

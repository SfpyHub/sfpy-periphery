// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@sfpy/core/contracts/interfaces/ISfpyPool.sol';
import '@sfpy/libraries/contracts/libraries/TransferHelper.sol';

import './interfaces/ISfpyRouter.sol';
import './interfaces/ISfpyCallback.sol';
import './libraries/SfpyLibrary.sol';
import './libraries/SafeMath.sol';
import './interfaces/IWETH.sol';

contract SfpyRouter is ISfpyRouter {
    using SafeMath for uint256;

    address private immutable _factory;
    address private immutable _WETH;
    address private immutable _ETHER = address(0);

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, 'SFPY_ROUTER: EXPIRED');
        _;
    }

    constructor(address _f, address _weth) {
        _factory = _f;
        _WETH = _weth;
    }

    receive() external payable {
        assert(msg.sender == _WETH); // only accept ETH via fallback from the WETH contract
    }

    /// @dev returns factory address
    function factory() external view override returns (address) {
        return _factory;
    }

    /// @dev returns WETH address
    function WETH() external view override returns (address) {
        return _WETH;
    }

    /// @dev Accepts payment from `msg.sender` in the requested token
    /// @dev and calls the corresponding smart contract that implements 
    /// @dev the `ISafepayCallback` interface.
    /// @dev If the callee is successful, it mints liquidity to the owner
    /// @dev of the flash app contract
    /// @param token the contract address of the token being used
    /// @param tokenAmount the amount of tokenAmount sent
    /// @param to the recipient of the minted liquidity. Usually the same address that controls the Flash App
    /// @param callback the address of the smart contract that implements the `ISafepayCallback` interface
    /// @param deadline Unix timestamp after which the transaction will revert.
    /// @param data any aribitrary data needed to execute the Flash App
    function flash(
        address token,
        uint256 tokenAmount,
        address to,
        address callback,
        uint256 deadline,
        bytes calldata data
    ) external virtual override ensure(deadline) returns (uint256 amount, uint256 liquidity) {
        address pool = SfpyLibrary.poolFor(_factory, token);
        require(pool != address(0), 'SFPY_ROUTER: UNSUPPORTED POOL');
        TransferHelper.safeTransferFrom(token, msg.sender, pool, tokenAmount);
        ISfpyCallback(callback).afterPay(msg.sender, token, tokenAmount, data);
        liquidity = ISfpyPool(pool).mint(to);
        amount = tokenAmount;
        emit Flash(msg.sender, to, token, callback, amount);
    }

    /// @dev Sends tokens to a pool designated for a particular address
    /// @dev adds liquidity to an ERC-20 pool. To cover all possible 
    /// @dev scenarios `msg.sender` should have already given the router
    /// @dev an allowance of at least `tokenAmount` on `token`
    /// @param token the contract address of the token being used in the payment
    /// @param tokenAmount the amount of tokenAmount being paid
    /// @param rate a belief of the value of the token in a fiat currency - the exchange rate
    /// @param request an external ID of a payment request
    /// @param to recipient of the payment.
    /// @param deadline Unix timestamp after which the transaction will revert.
    function pay(
        address token,
        uint256 tokenAmount,
        uint256 rate,
        bytes32 request,
        address to,
        uint256 deadline 
    ) external virtual override ensure(deadline) returns (uint256 amount, uint256 liquidity) {
        address pool = SfpyLibrary.poolFor(_factory, token);
        require(pool != address(0), 'SFPY_ROUTER: UNSUPPORTED POOL');
        TransferHelper.safeTransferFrom(token, msg.sender, pool, tokenAmount);
        liquidity = ISfpyPool(pool).mint(to);
        amount = tokenAmount;
        emit Pay(msg.sender, to, token, request, amount, rate);
    }

    /// @dev Removes liquidity from an ERC-20 pool and sends the underlying  
    /// @dev tokens to the recipient. To cover all possible 
    /// @dev scenarios `msg.sender` should have already given the router
    /// @dev an allowance of at least the required liquidity to burn
    /// @param token the contract address of the token being used in the payment
    /// @param tokenAmount the amount of tokenAmount being paid
    /// @param payment an external ID of a payment
    /// @param to recipient of the payment.
    /// @param deadline Unix timestamp after which the transaction will revert.
    function refund(
        address token,
        uint256 tokenAmount,
        bytes32 payment,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256 amount, uint256 liquidity) {
        address pool = SfpyLibrary.poolFor(_factory, token);
        require(pool != address(0), 'SFPY_ROUTER: UNSUPPORTED POOL');
        liquidity = ISfpyPool(pool).liquidityToBurn(tokenAmount);
        amount = withdraw(token, liquidity, 0, to, deadline);
        emit Refund(msg.sender, to, token, payment, amount);
    }

    /// @dev Sends tokens to a pool designated for a particular address
    /// @dev when a payment needs to be made using ETH.
    /// @dev Adds liquidity to a WETH pool. 
    /// @dev `msg.value` is treated as the amount of ETH being paid.
    /// @param request an external ID of a payment request
    /// @param to recipient of the payment.
    /// @param rate a belief of the value of ETH in a fiat currency - the exchange rate
    /// @param deadline Unix timestamp after which the transaction will revert.
    function payETH(
        bytes32 request,
        address to,
        uint256 rate,
        uint256 deadline
    ) external payable virtual override ensure(deadline) returns (uint256 amount, uint256 liquidity) {
        address pool = SfpyLibrary.poolFor(_factory, _WETH);
        require(pool != address(0), 'SFPY_ROUTER: UNSUPPORTED POOL');
        IWETH(_WETH).deposit{value: msg.value}();
        assert(IWETH(_WETH).transfer(pool, msg.value));
        liquidity = ISfpyPool(pool).mint(to);
        amount = msg.value;
        emit Pay(msg.sender, to, _ETHER, request, amount, rate);
    }

    /// @dev Removes liquidity from a WETH pool and sends the underlying  
    /// @dev ETH to the recipient.
    /// @dev To cover all possible scenarios `msg.sender` should have already given the router
    /// @dev an allowance of at least the required liquidity to burn
    /// @param payment an external ID of a payment
    /// @param tokenAmount the amount of tokenAmount being paid
    /// @param to recipient of the payment.
    /// @param deadline Unix timestamp after which the transaction will revert.
    function refundETH(
        bytes32 payment,
        uint256 tokenAmount,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256 amount, uint256 liquidity) {
        address pool = SfpyLibrary.poolFor(_factory, _WETH);
        require(pool != address(0), 'SFPY_ROUTER: UNSUPPORTED POOL');
        liquidity = ISfpyPool(pool).liquidityToBurn(tokenAmount);
        amount = withdrawETH(liquidity, 0, to, deadline);
        emit Refund(msg.sender, to, _ETHER, payment, amount);
    }

    /// @dev Removes liquidity from an ERC-20 pool and converts liquidity
    /// @dev into the underlying token which is sent to the recipient
    /// @param token the contract address of the desired token.
    /// @param liquidity the amount of liquidity tokens to remove.
    /// @param amountMin the minimum amount of token that must be received for the transaction not to revert.
    /// @param to recipient of the underlying assets.
    /// @param deadline Unix timestamp after which the transaction will revert.
    function withdraw(
        address token,
        uint256 liquidity,
        uint256 amountMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amount) {
        address pool = SfpyLibrary.poolFor(_factory, token);
        require(pool != address(0), 'SFPY_ROUTER: UNSUPPORTED POOL');
        ISfpyPool(pool).transferFrom(msg.sender, pool, liquidity);
        amount = ISfpyPool(pool).burn(to);
        require(amount >= amountMin, 'SFPY_ROUTER: INSUFFICIENT_AMOUNT');
    }

    /// @dev Removes liquidity from a WETH pool and converts liquidity
    /// @dev into ETH which is sent to the recipient
    /// @param liquidity the amount of liquidity tokens to remove.
    /// @param amountMin the minimum amount of token that must be received for the transaction not to revert.
    /// @param to recipient of the underlying assets.
    /// @param deadline Unix timestamp after which the transaction will revert.
    function withdrawETH(
        uint256 liquidity,
        uint256 amountMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amount) {
        amount = withdraw(_WETH, liquidity, amountMin, address(this), deadline);
        IWETH(_WETH).withdraw(amount);
        TransferHelper.safeTransferETH(to, amount);
    }

    /// @dev Removes liquidity from an ERC-20 pool and sends the underlying  
    /// @dev tokens to the recipient, without pre-approval using EIP 712 signatures
    /// @param token the contract address of the token being used in the payment
    /// @param tokenAmount the amount of tokenAmount being refunded
    /// @param payment an external ID of a payment
    /// @param to recipient of the payment.
    /// @param deadline Unix timestamp after which the transaction will revert.
    /// @param approveMax Whether or not the approval amount in the signature is for liquidity or 2**256
    /// @param v The v component of the permit signature.
    /// @param r The r component of the permit signature.
    /// @param s The s component of the permit signature.
    function refundWithPermit(
        address token,
        uint256 tokenAmount,
        bytes32 payment,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amount) {
        address pool = SfpyLibrary.poolFor(_factory, token);
        require(pool != address(0), 'SFPY_ROUTER: UNSUPPORTED POOL');
        uint256 liquidity = ISfpyPool(pool).liquidityToBurn(tokenAmount);
        uint256 value = approveMax ? 2**256 - 1 : liquidity;
        ISfpyPool(pool).permit(msg.sender, address(this), value, deadline, v, r, s);
        amount = withdraw(token, liquidity, 0, to, deadline);
        emit Refund(msg.sender, to, token, payment, amount);
    }

    /// @dev Removes liquidity from an ERC-20 pool and converts liquidity
    /// @dev into the underlying token, without pre-approval using EIP 712 signatures
    /// @param token the contract address of the desired token.
    /// @param liquidity the amount of liquidity tokens to remove.
    /// @param amountMin the minimum amount of token that must be received for the transaction not to revert.
    /// @param to recipient of the underlying assets.
    /// @param deadline Unix timestamp after which the transaction will revert.
    /// @param approveMax Whether or not the approval amount in the signature is for liquidity or 2**256
    /// @param v The v component of the permit signature.
    /// @param r The r component of the permit signature.
    /// @param s The s component of the permit signature.
    function withdrawWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amount) {
        address pool = SfpyLibrary.poolFor(_factory, token);
        require(pool != address(0), 'SFPY_ROUTER: UNSUPPORTED POOL');
        uint256 value = approveMax ? 2**256 - 1 : liquidity;
        ISfpyPool(pool).permit(msg.sender, address(this), value, deadline, v, r, s);
        amount = withdraw(token, liquidity, amountMin, to, deadline);
    }

    /// @dev Removes liquidity from a WETH pool and converts liquidity
    /// @dev into ETH, without pre-approval using EIP 712 signatures
    /// @param liquidity the amount of liquidity tokens to remove.
    /// @param amountMin the minimum amount of token that must be received for the transaction not to revert.
    /// @param to recipient of the underlying assets.
    /// @param deadline Unix timestamp after which the transaction will revert.
    /// @param approveMax Whether or not the approval amount in the signature is for liquidity or 2**256
    /// @param v The v component of the permit signature.
    /// @param r The r component of the permit signature.
    /// @param s The s component of the permit signature.
    function withdrawETHWithPermit(
        uint256 liquidity,
        uint256 amountMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amount) {
        address pool = SfpyLibrary.poolFor(_factory, _WETH);
        require(pool != address(0), 'SFPY_ROUTER: UNSUPPORTED POOL');
        uint256 value = approveMax ? 2**256 - 1 : liquidity;
        ISfpyPool(pool).permit(msg.sender, address(this), value, deadline, v, r, s);
        amount = withdrawETH(liquidity, amountMin, to, deadline);
    }

    /// @dev Removes liquidity from a WETH pool and sends the underlying  
    /// @dev ETH to the recipient, without pre-approval using EIP 712 signatures
    /// @param tokenAmount the amount of tokenAmount being refunded
    /// @param payment an external ID of a payment
    /// @param to recipient of the payment.
    /// @param deadline Unix timestamp after which the transaction will revert.
    /// @param approveMax Whether or not the approval amount in the signature is for liquidity or 2**256
    /// @param v The v component of the permit signature.
    /// @param r The r component of the permit signature.
    /// @param s The s component of the permit signature.
    function refundETHWithPermit(
        bytes32 payment,
        uint256 tokenAmount,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amount) {
        address pool = SfpyLibrary.poolFor(_factory, _WETH);
        require(pool != address(0), 'SFPY_ROUTER: UNSUPPORTED POOL');
        uint256 liquidity = ISfpyPool(pool).liquidityToBurn(tokenAmount);
        uint256 value = approveMax ? 2**256 - 1 : liquidity;
        ISfpyPool(pool).permit(msg.sender, address(this), value, deadline, v, r, s);
        amount = withdrawETH(liquidity, 0, to, deadline);
        emit Refund(msg.sender, to, _ETHER, payment, amount);
    }
}

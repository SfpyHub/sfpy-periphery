// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISfpyRouter {
    event Pay(
        address indexed from,
        address indexed to,
        address indexed token,
        bytes32 request,
        uint256 amount,
        uint256 rate
    );

    event Refund(
        address indexed from, 
        address indexed to, 
        address indexed token, 
        bytes32 payment, 
        uint256 amount
    );

    event Flash(
        address indexed from, 
        address indexed to,
        address indexed token,
        address callback,
        uint256 amount
    );

    function factory() external view returns (address);
    function WETH() external view returns (address);

    function flash(
        address token,
        uint256 tokenAmount,
        address to,
        address callback,
        uint256 deadline,
        bytes calldata data
    ) external returns (uint256 amount, uint256 liquidity);

    function pay(
        address token,
        uint256 tokenAmount,
        uint256 rate,
        bytes32 request,
        address to,
        uint256 deadline
    ) external returns (uint256 amount, uint256 liquidity);

    function refund(
        address token,
        uint256 tokenAmount,
        bytes32 payment,
        address to,
        uint256 deadline
    ) external returns (uint256 amount, uint256 liquidity);

    function payETH(
        bytes32 request,
        address to,
        uint256 rate,
        uint256 deadline
    ) external payable returns (uint256 amount, uint256 liquidity);

    function refundETH(
        bytes32 payment,
        uint256 tokenAmount,
        address to,
        uint256 deadline
    ) external returns (uint256 amount, uint256 liquidity);

    function withdraw(
        address token,
        uint256 liquidity,
        uint256 amountMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amount);

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
    ) external returns (uint256 amount);

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
    ) external returns (uint256 amount);

    function withdrawETH(
        uint256 liquidity,
        uint256 amountMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amount);

    function withdrawETHWithPermit(
        uint256 liquidity,
        uint256 amountMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amount);

    function refundETHWithPermit(
        bytes32 payment,
        uint256 tokenAmount,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amount);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20.sol";

interface IHyperDeFi is IERC20 {
    function getIDOConfigs() external view returns (
        uint256 IDOAmount,
        uint256 IDODepositCap,
        uint256 IDODepositMax,
        uint32  IDOTimestampFrom,
        uint32  IDOTimestampTo,

        address buffer
    );
    function getBufferConfigs() external pure returns (address dex, address usd);

    function isInitialLiquidityCreated() external view returns (bool);
    function createInitLiquidity() external payable returns (bool);
}

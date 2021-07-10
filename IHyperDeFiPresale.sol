// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

interface IHyperDeFiPresale {
    function getPresaleAmount() external pure returns (uint256);
    function getStatus(address account) external view returns (
        bool depositAllowed,

        uint256 endTimestamp,
        uint256 liquidityCreatedTimestamp,

        uint256 presaleAmount,
        uint256 balance,
        uint256 fund,
        uint256 portion,

        bool redeemed,

        uint256 busdBalance,
        uint256 busdAllowance
    );
}

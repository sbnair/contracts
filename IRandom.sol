// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IRandom {
    function generate() external view returns (uint256);
    function generateFromAccount(address account) external view returns (uint256);
}

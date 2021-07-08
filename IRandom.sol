// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IRandom {
    function generate() external view returns (uint256);
    function generateFromAccount(address account) external view returns (uint256);
}

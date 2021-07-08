// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IBuffer {
    function swapIntoLiquidity(uint256 amount) external returns (uint256 tokenAdded, uint256 busdAdded);
}

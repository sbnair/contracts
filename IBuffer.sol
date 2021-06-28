// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IBuffer {
    function swapIntoLiquidity(uint256 amount) external 
        returns (
            uint256 half,
            uint256 anotherHalf,
            uint256 swapped
        );
}

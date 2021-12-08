// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IHyperDeFiBuffer {
    function USD() external view returns (address);
    function metaWRAP() external view returns (string memory name, string memory symbol, uint8 decimals);
    function metaUSD() external view returns (string memory name, string memory symbol, uint8 decimals);

    function priceToken2WRAP() external view returns (uint256);
    function priceToken2USD() external view returns (uint256);
    function priceWRAP2USD() external view returns (uint256);
    function swapIntoLiquidity(uint256 amount) external;
}

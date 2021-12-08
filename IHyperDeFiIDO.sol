// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IHyperDeFiIDO {
    function isFounder(address account) external view returns (bool);
    function priceToken2WRAP() external view returns (uint256 price);
    function priceToken2USD() external view returns (uint256 price);
    
    function getDepositTotal() external view returns (uint256);
    function getAccount(address account) external view returns (
        uint256 amountWRAP,
        uint256 amountToken,
        bool redeemed
    );
}

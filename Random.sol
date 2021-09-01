// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.5;

contract Random {
    function generate() public view returns (uint256) {
        return uint256(keccak256(abi.encode(blockhash(block.number - 1))));
    }
    
    function generateFromAccount(address account) public view returns (uint256) {
        return uint256(keccak256(abi.encode(blockhash(block.number - 1), account)));
    }
}

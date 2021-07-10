// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.6;

import "./Context.sol";
import "./IERC20.sol";
import "./IUniswapV2Router02.sol";
import "./IHyperDeFiBuffer.sol";


contract HyperDeFiBuffer is Context, IHyperDeFiBuffer {
    IERC20             private constant HYPER_DEFI = IERC20(0xA176e5dF74638af78072d7e0A7C5b7DcB5576c87);
    IERC20             private constant BUSD       = IERC20(0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7);
    IUniswapV2Router02 private constant PANCAKE    = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
    address            private constant BLACK_HOLE = address(0xdead);
    
    function swapIntoLiquidity(uint256 amount) external override returns (uint256 tokenAdded, uint256 busdAdded) {
        require(_msgSender() == address(HYPER_DEFI), "Buffer: caller is not `HyperDeFi` contract");

        // path
        address[] memory path = new address[](2);
        path[0] = address(HYPER_DEFI);
        path[1] = address(BUSD);

        // swap half amount to BUSD
        uint256 half = amount / 2;
        PANCAKE.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            half,
            0,
            path,
            address(this),
            block.timestamp
        );

        // add liquidity
        uint256 busdBalance = BUSD.balanceOf(address(this));
        BUSD.approve(address(PANCAKE), busdBalance);
        (tokenAdded, busdAdded,) = PANCAKE.addLiquidity(
            address(HYPER_DEFI),
            address(BUSD),
            HYPER_DEFI.balanceOf(address(this)),
            busdBalance,
            0,
            0,
            BLACK_HOLE,
            block.timestamp
        );
        tokenAdded += half;
        
        // swap remaining BUSD to HyperDeFi, then send to black-hole
        uint256 busd0 = BUSD.balanceOf(address(this));
        if (0 < busd0) {
            path[0] = address(BUSD);
            path[1] = address(HYPER_DEFI);
            
            uint256 amountSwap = PANCAKE.getAmountsOut(busd0, path)[1];
            if (0 < amountSwap) {
                PANCAKE.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    busd0,
                    0,
                    path,
                    BLACK_HOLE,
                    block.timestamp
                );
            }
        }
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.6;

import "./Context.sol";
import "./IERC20.sol";
import "./IUniswapV2Router02.sol";
import "./IHyperDeFiBuffer.sol";


contract HyperDeFiBuffer is Context, IHyperDeFiBuffer {
    IERC20             private constant HYPER_DEFI = IERC20(0x0F6F376F562F625BBe8b64B52208Eb82aD310c49);
    IERC20             private constant WBNB       = IERC20(0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd);
    IUniswapV2Router02 private constant PANCAKE    = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
    address            private constant BLACK_HOLE = address(0xdead);
    
    function swapIntoLiquidity(uint256 amount) external override returns (uint256 tokenAdded, uint256 busdAdded) {
        require(_msgSender() == address(HYPER_DEFI), "Buffer: caller is not `HyperDeFi` contract");

        // path
        address[] memory path = new address[](2);
        path[0] = address(HYPER_DEFI);
        path[1] = address(WBNB);

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
        uint256 wbnbBalance = WBNB.balanceOf(address(this));
        WBNB.approve(address(PANCAKE), wbnbBalance);
        (tokenAdded, busdAdded,) = PANCAKE.addLiquidity(
            address(HYPER_DEFI),
            address(WBNB),
            HYPER_DEFI.balanceOf(address(this)),
            wbnbBalance,
            0,
            0,
            BLACK_HOLE,
            block.timestamp
        );
        tokenAdded += half;
        
        // swap remaining BUSD to HyperDeFi, then send to black-hole
        uint256 wbnb0 = WBNB.balanceOf(address(this));
        if (0 < wbnb0) {
            path[0] = address(WBNB);
            path[1] = address(HYPER_DEFI);
            
            uint256 amountSwap = PANCAKE.getAmountsOut(wbnb0, path)[1];
            if (0 < amountSwap) {
                PANCAKE.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    wbnb0,
                    0,
                    path,
                    BLACK_HOLE,
                    block.timestamp
                );
            }
        }
    }
}

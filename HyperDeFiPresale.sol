// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.6;

import "./Context.sol";
import "./IERC20.sol";
import "./IUniswapV2Router02.sol";
import "./IHyperDeFiPresale.sol";

interface IHyperDeFi is IERC20 {
    function mintLiquidity() external returns (bool);
}

contract HyperDeFiPresale is Context, IHyperDeFiPresale {
    uint256 private immutable END_TIMESTAMP  = 1625983200;
    uint256 private immutable PRESALE_AMOUNT  = 30_000_000_000_000e2; // 1_000_000_000_000_000e2 * 3 / 100;

    IHyperDeFi         private constant HYPER_DEFI = IHyperDeFi(0xA176e5dF74638af78072d7e0A7C5b7DcB5576c87);
    IERC20             private constant BUSD       = IERC20(0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7);
    IUniswapV2Router02 private constant PANCAKE    = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
    address            private constant BLACK_HOLE = address(0xdead);

    uint256 private              _liquidityCreatedTimestamp;
    uint256 private              _fund;
    mapping (address => uint256) _deposit;
    mapping (address => bool)    _redeemed;


    function getPresaleAmount() public pure override returns (uint256) {
        return PRESALE_AMOUNT;
    }

    function getStatus(address account) public view override
        returns (
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
        )
    {
        depositAllowed = 0 == _liquidityCreatedTimestamp;

        endTimestamp = END_TIMESTAMP;
        liquidityCreatedTimestamp = _liquidityCreatedTimestamp;

        presaleAmount = PRESALE_AMOUNT;
        balance = HYPER_DEFI.balanceOf(address(this));
        fund = _fund;
        portion = _getPortion(account);

        redeemed = _redeemed[account];
        
        busdBalance = BUSD.balanceOf(account);
        busdAllowance = BUSD.allowance(account, address(this));
    }

    function _getPortion(address account) private view returns (uint256 portion) {
        if (0 < _fund) {
            portion = PRESALE_AMOUNT * _deposit[account] / _fund;
        }
    }

    function deposit(uint256 amount) external {
        if (0 < _liquidityCreatedTimestamp) {
            revert("HyperDeFi Presale: PancakeSwap liquidity has already been created");
        } else {
            assert(BUSD.transferFrom(_msgSender(), address(this), amount));

            _fund += amount;
            _deposit[_msgSender()] += amount;
            
            if (block.timestamp > END_TIMESTAMP) {
                uint256 balance0 = HYPER_DEFI.balanceOf(address(this));
                assert(HYPER_DEFI.mintLiquidity());

                uint256 busdBalance = BUSD.balanceOf(address(this));
                assert(BUSD.approve(address(PANCAKE), busdBalance));

                uint256 _liquidityAmount = HYPER_DEFI.balanceOf(address(this)) - balance0;
                (uint256 tokenAdded, uint256 busdAdded,) = PANCAKE.addLiquidity(
                    address(HYPER_DEFI),
                    address(BUSD),
                    _liquidityAmount,
                    busdBalance,
                    0,
                    0,
                    BLACK_HOLE,
                    block.timestamp
                );

                require(0 < tokenAdded && 0 < busdAdded, "HyperDeFi Presale: create PancakeSwap liquidity failed");
                _liquidityCreatedTimestamp = block.timestamp;
            }
        }
    }
    
    function redeem() external {
        require(0 < _liquidityCreatedTimestamp, "HyperDeFi Presale: PancakeSwap liquidity not created");
        require(!_redeemed[_msgSender()], "HyperDeFi Presale: caller has already redeemed");
        assert(HYPER_DEFI.transfer(_msgSender(), _getPortion(_msgSender())));
        _redeemed[_msgSender()] = true;
    }
}

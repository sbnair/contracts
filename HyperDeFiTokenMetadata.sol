// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./IERC20Metadata.sol";

contract HyperDeFiTokenMetadata is IERC20Metadata {
    string internal constant _name   = "HyperDeFi";
    string internal constant _symbol = "HDEFI";
    uint8  internal constant _decimals = 2;

    uint8   internal constant FOMO_PERCENTAGE     = 60;
    uint256 internal constant FOMO_TIMESTAMP_STEP = 15 minutes;

    uint256 internal constant TOTAL_SUPPLY_CAP   = 1_000_000_000_000e2;
    uint256 internal constant BURN_AMOUNT        = TOTAL_SUPPLY_CAP / 2;
    uint256 internal constant DIST_AMOUNT        = TOTAL_SUPPLY_CAP * 48 / 100;
    uint256 internal constant INIT_LIQUIDITY     = TOTAL_SUPPLY_CAP / 100;
    uint256 internal constant IDO_AMOUNT         = TOTAL_SUPPLY_CAP / 100;
    uint256 internal constant IDO_DEPOSIT_CAP    = 50e18;
    uint256 internal constant IDO_DEPOSIT_MAX    = 0.1e18;
    uint32  internal constant IDO_TIMESTAMP_FROM = 1639137600;
    uint32  internal constant IDO_TIMESTAMP_TO   = IDO_TIMESTAMP_FROM + 7 days;
    uint32  internal constant TIMESTAMP_LAUNCH   = IDO_TIMESTAMP_TO + 1 days;

    address internal constant ADDRESS_BUFFER = address(0xbbbbbbb1908049D19544205F61D6D42aBDE9952F);
    address internal constant ADDRESS_IDO    = address(0x00000000E00A2E5B43460D40BcdF82E6e054CD3D);
    address internal constant ADDRESS_DEX    = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    address internal constant ADDRESS_USD    = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

    uint16  internal constant AUTO_SWAP_NUMERATOR_MIN = 1;
    uint16  internal constant AUTO_SWAP_NUMERATOR_MAX = 10;
    uint16  internal constant AUTO_SWAP_DENOMINATOR   = 1_000;
    uint256 internal constant AIRDROP_THRESHOLD       = 1_000_000e2;

    uint16  internal WHALE_NUMERATOR   = 5;
    uint16  internal WHALE_DENOMINATOR = 1_000;
    uint8   internal ROBBER_PERCENTAGE = 15;
    uint8[] internal BONUS             = [10, 20, 20];

    address internal constant FARM       = address(0x1);
    address internal constant FOMO       = address(0xf);
    address internal constant BLACK_HOLE = address(0xdead);

    /**
     * @dev Returns the name of the token.
     */
    function name() public pure override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public pure override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public pure override returns (uint8) {
        return _decimals;
    }
}

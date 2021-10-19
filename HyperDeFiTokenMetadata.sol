// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./IERC20Metadata.sol";

contract HyperDeFiTokenMetadata is IERC20Metadata {
    string internal constant _name   = "v519";
    string internal constant _symbol = "v519";
    uint8  internal constant _decimals = 2;

    uint256 internal constant  TOTAL_SUPPLY_CAP    = 1_000_000_000_000_000e2;
    uint256 internal immutable INIT_LIQUIDITY      = TOTAL_SUPPLY_CAP * 20 / 100;
    uint256 internal constant  GENESIS_AMOUNT      = TOTAL_SUPPLY_CAP * 15 / 100;
    uint256 internal constant  GENESIS_DEPOSIT_CAP = 0.03e18;
    uint256 internal constant  GENESIS_DEPOSIT_MAX = 0.003e18;

    uint32 internal immutable GENESIS_START_TIMESTAMP = 1634601600;
    uint32 internal immutable GENESIS_END_TIMESTAMP   = 1634688000;
    uint32 internal immutable LAUNCH_TIMESTAMP        = 1634695200;

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

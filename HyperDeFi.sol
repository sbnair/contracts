// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.6;

import "./DeFiToken.sol";


contract HyperDeFi is DeFiToken {
    function getMetadata() public view
        returns (
            string memory tokenName,
            string memory tokenSymbol,
            uint8         tokenDecimals,
            
            string memory priceName,
            string memory priceSymbol,
            uint8         priceDecimals,

            uint256 price,
            uint256 holders,
            uint256 usernames,

            uint256[10] memory supplies,
            address[10] memory accounts
        )
    {
        tokenName     = _name;
        tokenSymbol   = _symbol;
        tokenDecimals = _decimals;

        priceName     = BUSD.name();
        priceSymbol   = BUSD.symbol();
        priceDecimals = BUSD.decimals();

        price = _getPrice();
        holders = _holders.length;
        usernames = _totalUsername;

        // supplies
        supplies[0] = _gate + _totalSupply; // cap
        supplies[1] = _gate;                // gate
        supplies[2] = _totalSupply;         // totalSupply
        supplies[3] = _totalTax;            // totalTax
        supplies[4] = balanceOf(PANCAKE_PAIR);    // liquidity
        supplies[5] = balanceOf(address(BUFFER)); // buffer
        supplies[6] = balanceOf(TAX);             // tax
        supplies[7] = balanceOf(AIRDROP);         // airdrop
        supplies[8] = balanceOf(FOMO);            // fomo
        supplies[9] = balanceOf(BLACK_HOLE);      // dead

        // accounts
        accounts[0] = address(PANCAKE); // pancake
        accounts[1] = PANCAKE_PAIR;     // pair
        accounts[2] = address(BUSD);    // BUSD
        accounts[3] = TAX;              // tax
        accounts[4] = address(BUFFER);  // buffer
        accounts[5] = AIRDROP;          // airdrop
        accounts[6] = FOMO;             // fomo
        accounts[7] = owner();          // fund
        accounts[8] = address(0);       // zero
        accounts[9] = BLACK_HOLE;       // burn
    }

    function getGlobal() public view
        returns (
            bool    autoSwapReady,
            address fomoNext,

            uint16[7]   memory i16,
            uint256[11] memory i256,

            uint8[8] memory takerFees,
            uint8[8] memory makerFees,
            uint8[8] memory whaleFees,
            uint8[8] memory robberFees,
            
            address[] memory flats,
            address[] memory slots
        )
    {
        autoSwapReady = _autoSwapReady();
        fomoNext      = _fomoNextAccount;

        i16[0] = WHALE_FRACTION_A;
        i16[1] = WHALE_FRACTION_B;
        i16[2] = ROBBER_PERCENTAGE;
        i16[3] = AUTO_SWAP_NUMERATOR_MIN; // autoSwapNumeratorMin
        i16[4] = AUTO_SWAP_NUMERATOR_MAX; // autoSwapNumeratorMax
        i16[5] = AUTO_SWAP_DENOMINATOR;   // autoSwapDenominator
        i16[6] = FOMO_PERCENTAGE;          // fomoPercentage

        i256[0] = LAUNCH_TIMESTAMP;      // launch timestamp
        i256[1] = AIRDROP_MAX;           // airdrop max
        i256[2] = LIQUIDITY_AMOUNT;      // liquidity amount (min)
        i256[3] = LOTTO_THRESHOLD;       // lotto  threshold
        i256[4] = _getWhaleThreshold();  // whale  threshold
        i256[5] = _getRobberThreshold(); // robber threshold

        i256[6] = _getAutoSwapAmountMin();  // autoSwapAmountMin
        i256[7] = _getAutoSwapAmountMax();  // autoSwapAmountMax

        i256[8] = _getFomoAmount();     // fomo amount
        i256[9] = _fomoTimestamp;       // fomo timestamp
        i256[10] = FOMO_TIMESTAMP_STEP; // fomo timestampStep


        takerFees[0] = TAKER_FEE.tax;
        takerFees[1] = TAKER_FEE.lotto;
        takerFees[2] = TAKER_FEE.fomo;
        takerFees[3] = TAKER_FEE.liquidity;
        takerFees[4] = TAKER_FEE.fund;
        takerFees[5] = TAKER_FEE.destroy;
        takerFees[6] = TAKER_FEE.txn;
        takerFees[7] = TAKER_FEE.fee;

        makerFees[0] = MAKER_FEE.tax;
        makerFees[1] = MAKER_FEE.lotto;
        makerFees[2] = MAKER_FEE.fomo;
        makerFees[3] = MAKER_FEE.liquidity;
        makerFees[4] = MAKER_FEE.fund;
        makerFees[5] = MAKER_FEE.destroy;
        makerFees[6] = MAKER_FEE.txn;
        makerFees[7] = MAKER_FEE.fee;
        
        whaleFees[0] = WHALE_FEE.tax;
        whaleFees[1] = WHALE_FEE.lotto;
        whaleFees[2] = WHALE_FEE.fomo;
        whaleFees[3] = WHALE_FEE.liquidity;
        whaleFees[4] = WHALE_FEE.fund;
        whaleFees[5] = WHALE_FEE.destroy;
        whaleFees[6] = WHALE_FEE.txn;
        whaleFees[7] = WHALE_FEE.fee;
        
        robberFees[0] = ROBBER_FEE.tax;
        robberFees[1] = ROBBER_FEE.lotto;
        robberFees[2] = ROBBER_FEE.fomo;
        robberFees[3] = ROBBER_FEE.liquidity;
        robberFees[4] = ROBBER_FEE.fund;
        robberFees[5] = ROBBER_FEE.destroy;
        robberFees[6] = ROBBER_FEE.txn;
        robberFees[7] = ROBBER_FEE.fee;

        flats = _flats;
        slots = _slots;
    }

    function getAccount(address account) public view
        returns (
            bool    isHolder,
            bool    isWhale,
            bool    isFlat,
            bool    isSlot,

            string memory username,
            uint256 balance,
            uint256 harvest,

            uint256 totalHarvest,
            uint256 totalTaxSnap
        )
    {
        isHolder = _isHolder[account];
        isWhale  = balanceOf(account) > _getWhaleThreshold();
        isFlat   = _isFlat[account];
        isSlot   = _isSlot[account];

        username     = _username[account];
        balance      = balanceOf(account);
        harvest      = harvestOf(account);

        totalHarvest = _totalHarvest[account];
        totalTaxSnap = _totalTaxSnap[account];
    }
    
    function getAccountByUsername(string calldata value) public view
        returns (
            address account,
        
            bool    isHolder,
            bool    isWhale,
            bool    isFlat,
            bool    isSlot,

            string memory username,
            uint256 balance,
            uint256 harvest,

            uint256 totalHarvest,
            uint256 totalTaxSnap
        )
    {
        account = _username2address[value];

        isHolder = _isHolder[account];
        isWhale  = balanceOf(account) > _getWhaleThreshold();
        isFlat   = _isFlat[account];
        isSlot   = _isSlot[account];

        username     = _username[account];
        balance      = balanceOf(account);
        harvest      = harvestOf(account);

        totalHarvest = _totalHarvest[account];
        totalTaxSnap = _totalTaxSnap[account];
    }
    
    function getHolders(uint256 offset) public view
        returns (
            uint256[100] memory ids,
            address[100] memory holders,
            string[100]  memory usernames,
            uint256[100] memory balances,
            bool[100]    memory isWhales
        )
    {
        uint8 counter;
        for (uint256 i = offset; i < _holders.length; i++) {
            counter++;
            if (counter > 100) break;
            ids[i] = i;
            holders[i] = _holders[i];
            usernames[i] = _username[_holders[i]];
            balances[i] = balanceOf(holders[i]);
            isWhales[i] = balanceOf(holders[i]) > _getWhaleThreshold();
        }
    }
}



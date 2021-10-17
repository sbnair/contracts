// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.9;

import "./HyperDeFiToken.sol";


contract HyperDeFi is HyperDeFiToken {
    uint256                      private _liquidityCreatedTimestamp;
    uint256                      private _genesisFund;
    mapping (address => uint256) private _genesisDeposit;
    mapping (address => bool)    private _genesisRedeemed;

    event GenesisDeposit(address indexed account, uint256 bnbAmount);


    modifier inGenesis {
        require(block.timestamp > GENESIS_START_TIMESTAMP, "HyperDeFi Genesis: not started");
        require(0 == _liquidityCreatedTimestamp, "HyperDeFi Genesis: PancakeSwap liquidity has already been created");
        require(GENESIS_DEPOSIT_MAX > _genesisDeposit[_msgSender()], "HyperDeFi Genesis: deposit max reached for the sender");

        _;
        
        if (GENESIS_DEPOSIT_CAP <= address(this).balance || GENESIS_END_TIMESTAMP < block.timestamp) {

            // mint initial liquidity
            _balance[address(this)] += INIT_LIQUIDITY;
            _totalSupply += INIT_LIQUIDITY;
            emit Transfer(address(0), address(this), INIT_LIQUIDITY);
            emit Tx(uint8(TX_TYPE.FLAT), address(0), address(this), INIT_LIQUIDITY, INIT_LIQUIDITY);
    
            // intialize the PancakeSwap Liquidity
            _approve(address(this), address(PANCAKE), INIT_LIQUIDITY);
            (uint256 tokenAdded, uint256 bnbAdded,) = PANCAKE.addLiquidityETH{value: address(this).balance}(
                address(this),
                INIT_LIQUIDITY,
                0,
                0,
                BLACK_HOLE,
                block.timestamp
            );
    
            require(0 < tokenAdded && 0 < bnbAdded, "HyperDeFi Genesis: create PancakeSwap liquidity failed");
            _liquidityCreatedTimestamp = block.timestamp;
        }
    }

    // for Pre-Sale
    constructor () {
        _totalSupply += GENESIS_AMOUNT;
        _balance[address(this)] += GENESIS_AMOUNT;
        emit Transfer(address(0), address(this), GENESIS_AMOUNT);
        emit Tx(uint8(TX_TYPE.FLAT), address(0), address(this), GENESIS_AMOUNT, GENESIS_AMOUNT);
    }

    receive() external payable {
        _deposit();
    }

    fallback() external payable {
        _deposit();
    }

    function deposit() external payable {
        _deposit();
    }

    function _deposit() private inGenesis {
        uint256 amount = msg.value;

        // GENESIS_DEPOSIT_MAX
        if (GENESIS_DEPOSIT_MAX < amount + _genesisDeposit[_msgSender()]) {
            amount = GENESIS_DEPOSIT_MAX -_genesisDeposit[_msgSender()];
            payable(_msgSender()).transfer(msg.value - amount);
        }

        // GENESIS_DEPOSIT_CAP
        if (GENESIS_DEPOSIT_CAP < address(this).balance) {
            amount = address(this).balance - GENESIS_DEPOSIT_CAP;
            payable(_msgSender()).transfer(address(this).balance - GENESIS_DEPOSIT_CAP);
        }

        _genesisFund += amount;
        _genesisDeposit[_msgSender()] += amount;
        emit GenesisDeposit(_msgSender(), amount);
    }

    function _createLiquidity() private {
        // mint initial liquidity
        _balance[address(this)] += INIT_LIQUIDITY;
        _totalSupply += INIT_LIQUIDITY;
        emit Transfer(address(0), address(this), INIT_LIQUIDITY);
        emit Tx(uint8(TX_TYPE.FLAT), address(0), address(this), INIT_LIQUIDITY, INIT_LIQUIDITY);

        // intialize the PancakeSwap Liquidity
        _approve(address(this), address(PANCAKE), INIT_LIQUIDITY);
        (uint256 tokenAdded, uint256 bnbAdded,) = PANCAKE.addLiquidityETH{value: address(this).balance}(
            address(this),
            INIT_LIQUIDITY,
            0,
            0,
            BLACK_HOLE,
            block.timestamp
        );

        require(0 < tokenAdded && 0 < bnbAdded, "HyperDeFi Genesis: create PancakeSwap liquidity failed");
        _liquidityCreatedTimestamp = block.timestamp;
    }

    function genesisRedeem() external {
        require(0 < _liquidityCreatedTimestamp, "HyperDeFi Genesis: PancakeSwap liquidity not created");
        require(!_genesisRedeemed[_msgSender()], "HyperDeFi Genesis: caller has already redeemed");
        
        _addHolder(_msgSender());

        uint256 amount = _genesisPortion(_msgSender());
        _balance[_msgSender()] += amount;
        _balance[address(this)] -= amount;
        emit Transfer(address(this), _msgSender(), amount);

        _genesisRedeemed[_msgSender()] = true;
        emit Tx(uint8(TX_TYPE.REDEEM), address(this), _msgSender(), amount, amount);
    }

    function _genesisPortion(address account) private view returns (uint256 portion) {
        if (0 < _genesisFund) {
            portion = GENESIS_AMOUNT * _genesisDeposit[account] / _genesisFund;
        }
    }

    function getGenesis(address account) public view 
        returns (
            bool depositAllowed,

            uint256 depositMax,
            uint256 depositCap,

            uint32 startTimestamp,
            uint32 endTimestamp,
            uint256 liquidityCreatedTimestamp,

            uint256 genesisAmount,
            uint256 fund,
            uint256 portion,

            bool redeemed
        )
    {
        depositAllowed = 0 == _liquidityCreatedTimestamp;

        depositMax = GENESIS_DEPOSIT_MAX;
        depositCap = GENESIS_DEPOSIT_CAP;

        startTimestamp = GENESIS_START_TIMESTAMP;
        endTimestamp = GENESIS_END_TIMESTAMP;
        liquidityCreatedTimestamp = _liquidityCreatedTimestamp;

        genesisAmount = GENESIS_AMOUNT;
        fund = _genesisFund;
        portion = _genesisPortion(account);

        redeemed = _genesisRedeemed[account];
    }


    function getMetadata() public view
        returns (
            string[3]  memory tokenNames,
            string[3]  memory tokenSymbols,
            uint8[3]   memory tokenDecimals,
            uint256[3] memory tokenPrices,
            uint256[9] memory supplies,
            address[9] memory accounts,
            
            uint256 holders,
            uint256 usernames
        )
    {
        tokenNames[0]     = _name;
        tokenSymbols[0]   = _symbol;
        tokenDecimals[0]  = _decimals;

        tokenNames[1]     = WBNB.name();
        tokenSymbols[1]   = WBNB.symbol();
        tokenDecimals[1]  = WBNB.decimals();

        tokenNames[2]     = USDT.name();
        tokenSymbols[2]   = USDT.symbol();
        tokenDecimals[2]  = USDT.decimals();

        tokenPrices[0] = _getTokenBnbPrice();                                       // HyperDeFi price in BNB
        tokenPrices[1] = _getBnbUsdtPrice();                                        // BNB price in USDT
        tokenPrices[2] = tokenPrices[0] * tokenPrices[1] / 10 ** tokenDecimals[1];  // HyperDeFi price in USDT


        // supplies
        supplies[0] = TOTAL_SUPPLY_CAP;                // cap
        supplies[1] = TOTAL_SUPPLY_CAP - _totalSupply; // gate

        supplies[2] = _totalSupply;               // totalSupply
        supplies[3] = _totalTax;                  // totalTax
        supplies[4] = balanceOf(PANCAKE_PAIR);    // liquidity
        supplies[5] = balanceOf(address(BUFFER)); // buffer
        supplies[6] = balanceOf(TAX);             // tax
        supplies[7] = balanceOf(FOMO);            // fomo
        supplies[8] = balanceOf(BLACK_HOLE);      // dead

        // accounts
        accounts[0] = address(PANCAKE);  // pancake
        accounts[1] = address(WBNB);     // WBNB
        accounts[2] = address(USDT);     // USDT
        accounts[3] = PANCAKE_PAIR;      // pair
        accounts[4] = address(BUFFER);   // buffer
        accounts[5] = TAX;               // tax
        accounts[6] = FOMO;              // fomo
        accounts[7] = owner();           // fund
        accounts[8] = BLACK_HOLE;        // burn

        //        
        holders = _holders.length;
        usernames = _totalUsername;
    }

    function getGlobal() public view
        returns (
            bool    autoSwapReady,
            address fomoNext,

            uint16[7]   memory i16,
            uint256[18] memory i256,

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
        i16[6] = FOMO_PERCENTAGE;         // fomoPercentage

        i256[0] = LAUNCH_TIMESTAMP;      // launch timestamp
        i256[1] = INIT_LIQUIDITY;        // init liquidity
        i256[2] = AIRDROP_THRESHOLD;     // airdrop threshold
        i256[3] = _getWhaleThreshold();  // whale   threshold
        i256[4] = _getRobberThreshold(); // robber  threshold

        i256[5] = _getAutoSwapAmountMin();  // autoSwapAmountMin
        i256[6] = _getAutoSwapAmountMax();  // autoSwapAmountMax

        i256[7] = _getFomoAmount();     // fomo amount
        i256[8] = _fomoTimestamp;       // fomo timestamp
        i256[9] = FOMO_TIMESTAMP_STEP;  // fomo timestampStep


        takerFees[0] = TAKER_FEE.tax;
        takerFees[1] = TAKER_FEE.airdrop;
        takerFees[2] = TAKER_FEE.fomo;
        takerFees[3] = TAKER_FEE.liquidity;
        takerFees[4] = TAKER_FEE.fund;
        takerFees[5] = TAKER_FEE.destroy;
        takerFees[6] = TAKER_FEE.txn;
        takerFees[7] = TAKER_FEE.fee;

        makerFees[0] = MAKER_FEE.tax;
        makerFees[1] = MAKER_FEE.airdrop;
        makerFees[2] = MAKER_FEE.fomo;
        makerFees[3] = MAKER_FEE.liquidity;
        makerFees[4] = MAKER_FEE.fund;
        makerFees[5] = MAKER_FEE.destroy;
        makerFees[6] = MAKER_FEE.txn;
        makerFees[7] = MAKER_FEE.fee;
        
        whaleFees[0] = WHALE_FEE.tax;
        whaleFees[1] = WHALE_FEE.airdrop;
        whaleFees[2] = WHALE_FEE.fomo;
        whaleFees[3] = WHALE_FEE.liquidity;
        whaleFees[4] = WHALE_FEE.fund;
        whaleFees[5] = WHALE_FEE.destroy;
        whaleFees[6] = WHALE_FEE.txn;
        whaleFees[7] = WHALE_FEE.fee;
        
        robberFees[0] = ROBBER_FEE.tax;
        robberFees[1] = ROBBER_FEE.airdrop;
        robberFees[2] = ROBBER_FEE.fomo;
        robberFees[3] = ROBBER_FEE.liquidity;
        robberFees[4] = ROBBER_FEE.fund;
        robberFees[5] = ROBBER_FEE.destroy;
        robberFees[6] = ROBBER_FEE.txn;
        robberFees[7] = ROBBER_FEE.fee;

        flats = _flats;
        slots = _slots;

        // genesis
        i256[10] = GENESIS_DEPOSIT_MAX;
        i256[11] = GENESIS_DEPOSIT_CAP;
        i256[12] = GENESIS_START_TIMESTAMP;
        i256[13] = GENESIS_END_TIMESTAMP;
        i256[14] = _liquidityCreatedTimestamp;
        i256[15] = GENESIS_AMOUNT;
        i256[16] = balanceOf(address(this));
        i256[17] = _genesisFund;
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
            uint256 totalTaxSnap,
            
            // pre-sale
            uint256 bnbBalance,
            uint256 genesisDeposit,
            uint256 genesisPortion,
            bool    genesisRedeemed
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

        // genesis
        bnbBalance     = account.balance;
        genesisDeposit = _genesisDeposit[account];
        genesisPortion = _genesisPortion(account);
        genesisRedeemed = _genesisRedeemed[account];
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



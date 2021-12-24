// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.10;

import "./IERC20.sol";
import "./IUniswapV2Router02.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Pair.sol";
import "./IHyperDeFi.sol";
import "./IHyperDeFiBuffer.sol";
import "./IHyperDeFiIDO.sol";
import "./Ownable.sol";
import "./Math.sol";
import "./HyperDeFiTokenMetadata.sol";


/**
 * @dev DeFi Token
 */
contract HyperDeFiToken is Ownable, IHyperDeFi, HyperDeFiTokenMetadata {
    using Math for uint256;

    struct Percentage {
        uint8 farm;
        uint8 airdrop;
        uint8 fomo;
        uint8 liquidity;
        uint8 fund;
        uint8 destroy;
    }

    struct Snap {
        uint256 totalSupply;
        uint256 totalTax;
    }

    bool    private  _swapLock;
    uint256 internal _totalSupply;
    uint256 internal _distributed;
    uint256 internal _totalFarm;
    uint256 internal _totalUsername;
    uint256 internal _fomoTimestamp;

    address[] internal _flats;
    address[] internal _slots;
    address[] internal _funds;
    address[] internal _holders;

    // Resources
    IHyperDeFiIDO      internal constant  IDO    = IHyperDeFiIDO(ADDRESS_IDO);
    IHyperDeFiBuffer   internal constant  BUFFER = IHyperDeFiBuffer(ADDRESS_BUFFER);
    IUniswapV2Router02 internal constant  DEX    = IUniswapV2Router02(ADDRESS_DEX);
    IUniswapV2Factory  internal immutable DEX_FACTORY;
    IUniswapV2Pair     internal immutable DEX_PAIR;
    IERC20             internal immutable WRAP;

    //
    uint256 internal _initPrice;
    uint256 internal _timestampLiquidityCreated;
    address internal _fomoNextAccount;

    // tax
    Percentage internal TAKER_TAX  = Percentage(3, 1, 2, 5, 1, 3);
    Percentage internal MAKER_TAX  = Percentage(3, 1, 1, 4, 1, 0);
    Percentage internal WHALE_TAX  = Percentage(3, 1, 1, 5, 1, 19);
    Percentage internal ROBBER_TAX = Percentage(3, 1, 1, 5, 1, 74);

    mapping (address => uint256) internal _balance;
    mapping (address => uint256) internal _totalHarvest;
    mapping (address => uint256) internal _totalFarmSnap;
    mapping (address => string)  internal _username;
    mapping (address => bool)    internal _usernamed;
    mapping (string  => address) internal _username2address;

    mapping (address => uint256) internal _coupon;
    mapping (uint256 => address) internal _inviter;
    mapping (address => uint256) internal _couponUsed;
    mapping (address => uint256) internal _visitors;

    mapping (address => bool)    internal _isFlat;
    mapping (address => bool)    internal _isSlot;
    mapping (address => bool)    internal _isFund;
    mapping (address => bool)    internal _isHolder;
    mapping (address => mapping (address => uint256)) internal _allowances;

    // enum
    enum TX_TYPE {MINT, HARVEST, FLAT, TAKER, MAKER, WHALE, ROBBER}

    // events
    event TX(uint8 indexed txType, address indexed sender, address indexed recipient, uint256 amount, uint256 txAmount);
    event SlotRegistered(address account);
    event UsernameSet(address indexed account, string username);
    event CouponVisitor(address inviter, address visitor);
    event Airdrop(address indexed account, uint256 amount);
    event Bonus(address indexed account, uint256 amount);
    event Fund(address indexed account, uint256 amount);

    //
    modifier withSwapLock {
        _swapLock = true;
        _;
        _swapLock = false;
    }

    //
    constructor () {
        WRAP        = IERC20(DEX.WETH());
        DEX_FACTORY = IUniswapV2Factory(DEX.factory());
        DEX_PAIR    = IUniswapV2Pair(DEX_FACTORY.createPair(address(WRAP), address(this)));
        _registerFund(FOMO);
        _registerFund(BLACK_HOLE);
        _registerFund(address(BUFFER));
        _registerFund(address(IDO));
        _registerFund(address(this));
        _registerFund(_msgSender());
        _mint(BLACK_HOLE, BURN_AMOUNT);
        _mint(address(IDO), IDO_AMOUNT);
        _isHolder[owner()] = true;
        _holders.push(owner());
    }

    function getIDOConfigs() public pure returns
    (
        uint256 IDOAmount,
        uint256 IDODepositCap,
        uint256 IDODepositMax,
        uint32  IDOTimestampFrom,
        uint32  IDOTimestampTo,

        address buffer
    ) {
        IDOAmount = IDO_AMOUNT;
        IDODepositCap = IDO_DEPOSIT_CAP;
        IDODepositMax = IDO_DEPOSIT_MAX;
        IDOTimestampFrom = IDO_TIMESTAMP_FROM;
        IDOTimestampTo = IDO_TIMESTAMP_TO;

        buffer = ADDRESS_BUFFER;
    }

    function getBufferConfigs() public pure returns
    (
        address dex,
        address usd
    ) {
        dex = ADDRESS_DEX;
        usd = ADDRESS_USD;
    }

    function isInitialLiquidityCreated() public view returns (bool) {
        return 0 < _timestampLiquidityCreated;
    }

    /**
     * @dev Set username for `_msgSender()`
     */
    function setUsername(string calldata value) external {
        require(0 < balanceOf(_msgSender()) || IDO.isFounder(_msgSender()), "HyperDeFi: balance is zero");
        require(address(0) == _username2address[value], "HyperDeFi: username is already benn taken");
        require(!_usernamed[_msgSender()], "HyperDeFi: username cannot be changed");

        _username[_msgSender()] = value;
        _usernamed[_msgSender()] = true;
        _username2address[value] = _msgSender();
        _totalUsername++;
        
        emit UsernameSet(_msgSender(), value);
        
        _mayAutoSwapIntoLiquidity();
    }

    /**
     * @dev Generate coupon for `_msgSender()`
     */
    function genConpon() external {
        require(0 < balanceOf(_msgSender()) || IDO.isFounder(_msgSender()), "HyperDeFi Conpon: balance is zero");
        require(_coupon[_msgSender()] == 0, "HyperDeFi Conpon: already generated");

        uint256 coupon = uint256(keccak256(abi.encode(blockhash(block.number - 1), _msgSender()))) % type(uint32).max;
        require(0 < coupon, "HyperDeFi Conpon: invalid code, please retry");

        _coupon[_msgSender()] = coupon;
        _inviter[coupon] = _msgSender();
        
        _mayAutoSwapIntoLiquidity();
    }

    /**
     * @dev Set coupon for `_msgSender()`
     */
    function useCoupon(uint256 coupon) external {
        address inviter = _inviter[coupon];
        require(isValidCouponForAccount(coupon, _msgSender()), "HyperDeFi Coupon: invalid");

        _couponUsed[_msgSender()] = coupon;
        _visitors[inviter]++;

        emit CouponVisitor(inviter, _msgSender());
        
        _mayAutoSwapIntoLiquidity();
    }

    /**
     * @dev Returns `true` if `coupon` is valid for `account`
     */
    function isValidCouponForAccount(uint256 coupon, address account) public view returns (bool) {
        address inviter = _inviter[coupon];
        if (inviter == address(0)) return false;
 
        for (uint8 i = 1; i < BONUS.length; i++) {
            if (inviter == account) return false;

            inviter = _inviter[_couponUsed[inviter]];
            if (inviter == address(0)) return true;
        }

        return true;
    }

    /**
     * @dev Pay TAX
     */
    function payFee(uint256 farm, uint256 airdrop, uint256 fomo, uint256 liquidity, uint256 fund, uint256 destroy) public returns (bool) {
        uint256 amount = farm + airdrop + fomo + liquidity + fund + destroy;
        require(amount > 0, "HyperDeFi: fee amount is zero");
        require(amount <= balanceOf(_msgSender()), "HyperDeFi: fee amount exceeds balance");
        unchecked {
            _balance[_msgSender()] -= amount;
        }

        if (0 < farm)      _payFarm(     _msgSender(), farm);
	    if (0 < airdrop)   _payAirdrop(  _msgSender(), airdrop, _generateRandom(tx.origin));
        if (0 < fomo)      _payFomo(     _msgSender(), fomo);
	    if (0 < liquidity) _payLiquidity(_msgSender(), liquidity);
	    if (0 < fund)      _payFund(     _msgSender(), fund);
	    if (0 < destroy)   _payDestroy(  _msgSender(), destroy);
	    
	    _mayAutoSwapIntoLiquidity();
        return true;
    }

    /**
     * @dev Pay TAX from `sender`
     */
    function payFeeFrom(address sender, uint256 farm, uint256 airdrop, uint256 fomo, uint256 liquidity, uint256 fund, uint256 destroy) public returns (bool) {
        uint256 amount = farm + airdrop + fomo + liquidity + fund + destroy;
        require(amount > 0, "HyperDeFi: fee amount is zero");
        require(amount <= balanceOf(sender), "HyperDeFi: fee amount exceeds balance");

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "HyperDeFi: fee amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
            _balance[sender] -= amount;
        }

        if (0 < farm)      _payFarm(     sender, farm);
	    if (0 < airdrop)   _payAirdrop(  sender, airdrop, _generateRandom(tx.origin));
        if (0 < fomo)      _payFomo(     sender, fomo);
	    if (0 < liquidity) _payLiquidity(sender, liquidity);
	    if (0 < fund)      _payFund(     sender, fund);
	    if (0 < destroy)   _payDestroy(  sender, destroy);
	    
	    _mayAutoSwapIntoLiquidity();
        return true;
    }

    function harvestOf(address account) public view returns (uint256) {
        if (_totalFarm <= _totalFarmSnap[account]) return 0; // never happens

        uint256 harvest = _balance[account] * (_totalFarm - _totalFarmSnap[account]) / _totalSupply;
        return harvest.min(balanceOf(FARM));
    }

    function takeHarvest() public returns (bool) {
        _takeHarvest(_msgSender());
        
        _mayAutoSwapIntoLiquidity();
        return true;
    }




    /**
     * @dev Register a slot for DApp
     */
    function registerSlot(address account) public onlyOwner {
        require(!_isSlot[account], "The slot is already exist");
        require(!_isHolder[account], "The holder is already exist");
        
        _isSlot[account] = true;
        _isFlat[account] = true;
        _slots.push(account);
        _flats.push(account);
        emit SlotRegistered(account);
        
        _mayAutoSwapIntoLiquidity();
    }




    // --------- --------- --------- --------- --------- --------- --------- --------- --------- --------- --------- --------- ERC20
    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balance[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        if (BLACK_HOLE == recipient || address(this) == recipient) {
            _burn(_msgSender(), amount);
            return true;
        }
        
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev Create initial liquidity
     */
    function createInitLiquidity() public payable returns (bool) {
        require(_msgSender() == address(IDO), "HyperDeFi: caller is not the IDO contract");
        require(0 == _timestampLiquidityCreated, "HyperDeFi: initial liquidity has been created");

        _initPrice = address(this).balance * 10 ** _decimals / INIT_LIQUIDITY;
        _mint(address(this), INIT_LIQUIDITY);
        _approve(address(this), ADDRESS_DEX, type(uint256).max);

        DEX.addLiquidityETH{value: address(this).balance}(
            address(this),
            INIT_LIQUIDITY,
            0,
            0,
            BLACK_HOLE,
            block.timestamp
        );

        _timestampLiquidityCreated = block.timestamp;
        return true;
    }

    /**
     * @dev Burn
     */
    function burn(uint256 amount) public returns (bool) {
        _burn(_msgSender(), amount);

        _mayAutoSwapIntoLiquidity();
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);

        _mayAutoSwapIntoLiquidity();
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        _transfer(sender, recipient, amount);
        return true;
    }

    /**
     * @dev Burn from `sender`
     */
    function burnFrom(address sender,  uint256 amount) public returns (bool) {
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }
        
        _burn(sender, amount);
        _mayAutoSwapIntoLiquidity();
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);

        _mayAutoSwapIntoLiquidity();
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        _mayAutoSwapIntoLiquidity();
        return true;
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) private {
        require(account != address(0), "ERC20: mint to the zero address");
        require(TOTAL_SUPPLY_CAP >= _totalSupply + amount, "ERC20: cap exceeded");

        _totalSupply += amount;
        _balance[account] += amount;
        emit Transfer(address(0), account, amount);
        emit TX(uint8(TX_TYPE.MINT), address(0), account, amount, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account` to black-hole.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");
        require(_totalSupply >= amount, "ERC20: burn amount exceeds total supply");
        require(_balance[account] >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balance[account] -= amount;
            _balance[BLACK_HOLE] += amount;
        }

        emit Transfer(account, BLACK_HOLE, amount);
    }
    // --------- --------- --------- --------- --------- --------- --------- --------- --------- --------- --------- --------- ERC20 <END>

    function _priceToken2WRAP() internal view returns (uint256 price) {
        uint256 pairTokenAmount = balanceOf(address(DEX_PAIR));
        if (0 < pairTokenAmount) {
            return BUFFER.priceToken2WRAP();
        }
        else {
            return IDO.priceToken2WRAP();
        }
    }

    function _priceToken2USD() internal view returns (uint256 price) {
        uint256 pairTokenAmount = balanceOf(address(DEX_PAIR));
        if (0 < pairTokenAmount) {
            return BUFFER.priceToken2USD();
        }
        else {
            return IDO.priceToken2USD();
        }
    }

    function _takeHarvest(address account) internal {
        uint256 amount = harvestOf(account);
        if (0 == amount) return;

        _totalFarmSnap[account] = _totalFarm;
        if (0 == amount) return;

        if (_balance[FARM] < amount) return;
        unchecked {
            _balance[FARM] -= amount;
        }

        _balance[account] += amount;
        _totalHarvest[account] += amount;
        emit Transfer(FARM, account, amount);
        emit TX(uint8(TX_TYPE.HARVEST), FARM, account, amount, amount);
    }

    /**
     * @dev Register a fund for this DeFi token
     */    
    function _registerFund(address account) internal {
        require(!_isFund[account], "The fund is already exist");
        require(!_isHolder[account], "The holder is already exist");

        _isFund[account] = true;
        _isFlat[account] = true;

        _funds.push(account);
        _flats.push(account);
    }

    /**
     * @dev Add Holder
     */
	function _addHolder(address account) internal {
        if (_isHolder[account] || _isSlot[account] || _isFund[account]) return;
        if (account == ADDRESS_DEX || account == address(DEX_PAIR)) return;

        _isHolder[account] = true;
        _holders.push(account);
    }

    /**
     * @dev Auto-swap amount
     */
    function _getAutoSwapAmountMin() internal view returns (uint256) {
        uint256 pairBalance = balanceOf(address(DEX_PAIR));
        if (0 < pairBalance) return pairBalance * AUTO_SWAP_NUMERATOR_MIN / AUTO_SWAP_DENOMINATOR;
        return INIT_LIQUIDITY * AUTO_SWAP_NUMERATOR_MIN / AUTO_SWAP_DENOMINATOR;
    }
    function _getAutoSwapAmountMax() internal view returns (uint256) {
        uint256 pairBalance = balanceOf(address(DEX_PAIR));
        if (0 < pairBalance)  return pairBalance * AUTO_SWAP_NUMERATOR_MAX / AUTO_SWAP_DENOMINATOR;
        return INIT_LIQUIDITY * AUTO_SWAP_NUMERATOR_MAX / AUTO_SWAP_DENOMINATOR;
    }

    /**
     * @dev Returns whale balance amount
     */
    function _getWhaleThreshold() internal view returns (uint256 amount) {
        uint256 pairBalance = balanceOf(address(DEX_PAIR));
        if (0 < pairBalance) return pairBalance * WHALE_NUMERATOR / WHALE_DENOMINATOR;
    }

    /**
     * @dev Returns robber balance amount
     */
    function _getRobberThreshold() internal view returns (uint256 amount) {
        uint256 pairBalance = balanceOf(address(DEX_PAIR));
        if (0 < pairBalance) return pairBalance * ROBBER_PERCENTAGE / 100;
    }

    /**
     * @dev FOMO amount
     */
    function _getFomoAmount() internal view returns (uint256) {
        return balanceOf(FOMO) * FOMO_PERCENTAGE / 100;
    }


    /**
     * @dev May auto-swap into liquidity - from the `_BUFFER` contract
     */
    function _mayAutoSwapIntoLiquidity() internal withSwapLock {
        // may mint to `_BUFFER`
        _mayMintToBuffer();

        // may swap
        uint256 amount = balanceOf(address(BUFFER));
        if (0 == amount) return;
        if (amount < _getAutoSwapAmountMin()) return;

        _approve(address(BUFFER), address(DEX), balanceOf(address(BUFFER)));
        BUFFER.swapIntoLiquidity(amount.min(_getAutoSwapAmountMax()));
    }

    /**
     * @dev Transfer token
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "ERC20: transfer amount is zero");
        require(amount <= balanceOf(sender), "ERC20: transfer amount exceeds the balance");

        // may transfer fomo
        _mayMoveFomo();

        // get harvest for recipient
        if (recipient != address(DEX_PAIR)) _takeHarvest(recipient);

        // may auto-swap into liquidity
        if (sender != address(DEX_PAIR) && recipient != address(DEX_PAIR) && !_swapLock) _mayAutoSwapIntoLiquidity();

        // tx type
        uint256 coupon = sender == address(DEX_PAIR) ? _couponUsed[recipient] : _couponUsed[sender];

        TX_TYPE txType = TX_TYPE.TAKER;
        if (_isFlat[sender] || _isFlat[recipient]) txType = TX_TYPE.FLAT;
        else if (sender == address(DEX_PAIR)) txType = TX_TYPE.MAKER;

        // whale or robber
        if (txType != TX_TYPE.FLAT) {
            require(block.timestamp > TIMESTAMP_LAUNCH, "HyperDeFi: transfer before the `LAUNCH_TIMESTAMP`");

            uint256 whaleThreshold = _getWhaleThreshold();
            uint256 txAmountIfWhale = amount * (100 - WHALE_TAX.farm - WHALE_TAX.airdrop - WHALE_TAX.fomo - WHALE_TAX.liquidity - WHALE_TAX.fund - WHALE_TAX.destroy) / 100;

            // buy as/to a whale
            if (sender    == address(DEX_PAIR) && whaleThreshold < balanceOf(recipient) + txAmountIfWhale) txType = TX_TYPE.WHALE;
            
            // sell as a whale
            else if (recipient == address(DEX_PAIR) && whaleThreshold < balanceOf(sender)) txType = TX_TYPE.WHALE;
            
            // send from a whale
            else if (sender != address(DEX_PAIR) && recipient != address(DEX_PAIR) && whaleThreshold < balanceOf(sender)) txType = TX_TYPE.WHALE;

            // // send to a whale            
            // else if (sender != DEX_PAIR && recipient != DEX_PAIR && whaleThreshold < balanceOf(recipient)) txType = TX_TYPE.WHALE;

            // buy/sell as a robber
            if ((sender == address(DEX_PAIR) || recipient == address(DEX_PAIR)) && _getRobberThreshold() < amount) txType = TX_TYPE.ROBBER;
        }

        // tx
        uint256 rand = _generateRandom(tx.origin);
        (uint256 farm, uint256 airdrop, uint256 fomo, uint256 liquidity, uint256 fund, uint256 destroy, uint256 txAmount) = _txData(amount, txType, coupon);

        _balance[sender] -= amount;
        _balance[recipient] += txAmount;
        emit Transfer(sender, recipient, txAmount);

        // buy from liquidity, non-slot
	    if (sender == address(DEX_PAIR) && !_isFlat[recipient] && !_isSlot[recipient] && txType != TX_TYPE.ROBBER) {
	        // fomo
            _fomoNextAccount = recipient;
            _fomoTimestamp = block.timestamp + FOMO_TIMESTAMP_STEP;
	    }

        // fee
        if (0 < farm)      _payFarm(     sender, farm);
	    if (0 < airdrop)   _payAirdrop(  sender, airdrop, rand);
        if (0 < fomo)      _payFomo(     sender, fomo);
	    if (0 < liquidity) _payLiquidity(sender, liquidity);
	    if (0 < fund)      _payFund(     sender, fund);
	    if (0 < destroy)   _payDestroy(  sender, destroy);

        // Tx event
        emit TX(uint8(txType), sender, recipient, amount, txAmount);

        // // may mint to `_BUFFER`
        // if (!_isFlat[sender] && !_isFlat[recipient]) _mayMintToBuffer();

        // add holder
        _addHolder(sender);
        _addHolder(recipient);
    }

    /**
     * @dev Generate random from account
     */
    function _generateRandom(address account) private view returns (uint256) {
        return uint256(keccak256(abi.encode(blockhash(block.number - 1), account)));
    }

    /**
     * @dev TxData
     */
    function _txData(uint256 amount, TX_TYPE txType, uint256 coupon) private view
        returns (
            uint256 farm,
            uint256 airdrop,
            uint256 fomo,
            uint256 liquidity,
            uint256 fund,
            uint256 destroy,
            uint256 txAmount
        )
    {
        (farm, airdrop, fomo, liquidity, fund, destroy) = _txDataWithoutTxAmount(amount, txType, coupon);
        
        txAmount = amount - farm - airdrop - fomo - liquidity - fund - destroy;

        return (farm, airdrop, fomo, liquidity, fund, destroy, txAmount);
    }
    function _txDataWithoutTxAmount(uint256 amount, TX_TYPE txType, uint256 coupon) private view
        returns (
            uint256 farm,
            uint256 airdrop,
            uint256 fomo,
            uint256 liquidity,
            uint256 fund,
            uint256 destroy
        )
    {
        if (txType == TX_TYPE.FLAT) return (0, 0, 0, 0, 0, 0);

        Percentage memory percentage;
        if      (txType == TX_TYPE.MAKER)  percentage = MAKER_TAX;
        else if (txType == TX_TYPE.WHALE)  percentage = WHALE_TAX;
        else if (txType == TX_TYPE.ROBBER) percentage = ROBBER_TAX;
        else                               percentage = TAKER_TAX;

		if (0 < percentage.farm)      farm    = amount * percentage.farm / 100;
        if (0 < percentage.airdrop)   airdrop = amount * percentage.airdrop / 100;
        if (0 < percentage.fomo)      fomo    = amount * percentage.fomo / 100;
        if (0 < percentage.liquidity) {
            if (coupon == 0 || txType == TX_TYPE.ROBBER) {
                liquidity = amount * percentage.liquidity / 100;
            } else {
                liquidity = amount * (percentage.liquidity - 1) / 100;
            }
        }
        if (0 < percentage.fund)      fund    = amount * percentage.fund / 100;
        if (0 < percentage.destroy)   destroy = amount * percentage.destroy / 100;
        
        return (farm, airdrop, fomo, liquidity, fund, destroy);
    }

    /**
     * @dev Pay FARM
     */
    function _payFarm(address account, uint256 amount) private {
        _totalFarm += amount;
        _balance[FARM] += amount;
        emit Transfer(account, FARM, amount);
    }

    /**
     * @dev Pay AIRDROP
     */
    function _payAirdrop(address account, uint256 amount, uint256 rand) private {
        uint256 destroy;
        uint256 airdrop = amount;
        address accountAirdrop = _holders[rand % _holders.length];

        address accountLoop = accountAirdrop;
        for (uint8 i; i < BONUS.length; i++) {
            address inviter = _inviter[_couponUsed[accountLoop]];
            
            if (inviter == address(0)) {
                break;
            }

            uint256 bonus = amount * BONUS[i] / 100;
            
            airdrop -= bonus;
            
            if (balanceOf(inviter) < AIRDROP_THRESHOLD) {
                destroy += bonus;
            } else {
                _balance[inviter] += bonus;
                emit Transfer(account, inviter, bonus);
                emit Bonus(inviter, bonus);
            }
            
            accountLoop = inviter;
        }

        if (balanceOf(accountAirdrop) < AIRDROP_THRESHOLD) {
            destroy += airdrop;
            airdrop = 0;
        }
        
        if (0 < destroy) {
            _payDestroy(account, destroy);
        }

        if (0 < airdrop) {
            _balance[accountAirdrop] += airdrop;
            emit Transfer(account, accountAirdrop, airdrop);
            emit Airdrop(accountAirdrop, airdrop);
        }
    }

    /**
     * @dev Pay FOMO to `_fomo`
     */
    function _payFomo(address account, uint256 amount) private {
        _balance[FOMO] += amount;
        emit Transfer(account, FOMO, amount);
    }

    /**
     * @dev Pay LIQUIDITY
     */
    function _payLiquidity(address account, uint256 amount) private {
        _balance[address(BUFFER)] += amount;
        emit Transfer(account, address(BUFFER), amount);
    }

    /**
     * @dev Pay FUND
     */
    function _payFund(address account, uint256 amount) private {
        _balance[owner()] += amount;
        emit Transfer(account, owner(), amount);
        emit Fund(account, amount);
    }

    /**
     * @dev pay DESTROY
     */
    function _payDestroy(address account, uint256 amount) internal {
        _balance[BLACK_HOLE] += amount;
        emit Transfer(account, BLACK_HOLE, amount);
    }

    /**
     * @dev May move FOMO amount
     */
    function _mayMoveFomo() private {
        if (_fomoNextAccount == address(0) || block.timestamp < _fomoTimestamp) return;
        
        uint256 amount = _getFomoAmount();

        _balance[FOMO] -= amount;
        _balance[_fomoNextAccount] += amount;
        emit Transfer(FOMO, _fomoNextAccount, amount);
        
        _fomoNextAccount = address(0);
    }

    /**
     * @dev May mint to `_BUFFER`
     */
    function _mayMintToBuffer() private {
        if (0 == _initPrice) return;
        if (0 == balanceOf(address(DEX_PAIR))) return;

        uint256 amount = DIST_AMOUNT * BUFFER.priceToken2WRAP() / _initPrice / 1024;

        if (amount >= DIST_AMOUNT) return;
        if (_distributed >= amount) return;
        amount -= _distributed;

        _distributed += amount;
        _mint(address(BUFFER), amount);
    }
}

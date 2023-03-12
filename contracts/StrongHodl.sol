
/**

   #StrongHODL features:
   
   _ 2% fee when buying the tokens
   _ 4% fee when selling the tokens
   
        Half of these fee is used to add liquidity to pancakeswap liquidity pool
        The other half is a reward for every hodler (RFI token)
   
    _ Buybacks of tokens are perform with BNB that were left apart after adding liquidity
    _ Soft burns will occur from time to time, to lock a certain amount defined beforehand.
    Besides, with each burn the number of tokens of every hodler will increase with a bonus
    depending on the total number of hodlers.

 */

pragma solidity ^0.6.12;
// SPDX-License-Identifier: Unlicensed

import "./IERC20.sol";
import "./SafeMath.sol";
import "./context.sol";
import "./Address.sol";
import "./Ownable.sol";
import "./IPancake.sol";



contract strongHODL is Context, IERC20, Ownable {
    
    using SafeMath for uint256;
    using Address for address;

    

    //-----------------------------------------------------\\
    //----------- Token variables -------------------------\\
    //-----------------------------------------------------\\  
    string private constant NAME = "TestCoin2";//"StrongHODL";
    string private constant SYMBOL = "TC";//"STRONG";
    uint8 private constant DECIMALS = 10;
    
    uint256 private constant MAX = ~uint256(0); // MAX = 2^(256) - 1 (highest uint256)
    uint256 private _tTotal = 10**12 * 10**10; // 1 trillion tokens
    uint256 private _rTotal = (MAX - (MAX % _tTotal)); // Highest number that is initially divisible by _tTotal
    uint256 public _maxTxAmount = 10**8 * 10**10; // 100 million tokens max per transaction

    mapping (address => uint256) private _rOwned; // reflected balances of users
    mapping (address => uint256) private _tOwned; // Standard balances of users
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcludedFromFee; // Some addresses are exempted from fees
    mapping (address => bool) private _isExcludedFromReward; // Some addresses are exempted from rewards (like the burn address)
    address[] private _excluded;

     
    
    //-----------------------------------------------------\\
    //----------- Fee variables ---------------------------\\
    //-----------------------------------------------------\\
    // Fees are given in Per-mille (not percentages) => this allows percentages with one decimal.
    // For e.g. 1.5% = 15‰ (1.5 percent = 15 per-mille) 
    uint256 public _buyerFee = 20; // 2%
    uint256 private _previousBuyerFee = _buyerFee;
    uint256 private constant MAXBUYERFEE = 40; // 4%
    uint256 private _tBuyerFeeTotal;
    
    uint256 public _sellerFee = 40; // 4%
    uint256 private _previousSellerFee = _sellerFee;
    uint256 private constant MAXSELLERFEE = 90; // 9%
    uint256 private _tSellerFeeTotal;
    
    uint256 private constant PERMILLEDIVISOR = 10**3; // 1000
    
    uint256 private _tFeeTotal;
    bool private _dxSale = false;  // While selling tokens to investors on DxSale, fees won't be activated
    
    
    //-----------------------------------------------------\\
    //----------- Auto BuyBack variables ------------------\\
    //-----------------------------------------------------\\
    
    bool private inBuyBack;
    bool public BuyBackEnabled = true; 
    // The num of BNB necessary to buy tokens should be small enough to not drain liquidity
    uint256 private constant numBNBSellToBuyBack = 1 * 10**16; // 0.01BNB (BNB has 18 decimals)  // TODO : Setter à faire ?
    uint256 private constant minAmountToKeepForFees = 1 * 10**15; // 0.001 BNB
    
    event BuyBackEnabledUpdated(bool enabled);
    event BNBBuyBack(uint256 bnbUsed); 
    
    modifier lockTheBuyBack {
        inBuyBack = true;
        _;
        inBuyBack = false;
    }       
    
    
    //-----------------------------------------------------\\
    //----------- Auto Burn variables ---------------------\\
    //-----------------------------------------------------\\   
    
    address private constant BURNADDRESS = 0x3141592653589793238462643383279502884197; // arbitrary set to pi value (3.14159..)
    uint256 private constant MAXBURNAMOUNT = 6 * 10**11 * 10**10; // 600 billions tokens (60% of supply)
    uint256 private _currentTokenBalanceForBurn = 0;
    uint256 private constant MAXBONUSTOKENHODLERS = 10; // 10 for test; 10**6; // 1 million holders
    uint256 private constant minNumTokenHodler = 10; // Anyone that has more than 10 tokens is considered a hodler
    uint256 private nb_hodlers = 0; 
    uint256 private _tBurnTotal = 0;
    
    
    
    //-----------------------------------------------------\\
    //----------- Auto Liquidity variables ----------------\\
    //-----------------------------------------------------\\    
    IPancakeRouter02 public immutable pancakeswapV2Router;
    address public immutable pancakeswapV2Pair;
    
    bool private inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;    
    /* Before adding liquidity to the liquidity pool, the min num of tokens accumulated with the fees needs
       to be at least equal to numTokensSellToAddToLiquidity. */    
    uint256 private constant numTokensSellToAddToLiquidity = 1 * 10**4 * 10**10; // 50 million tokens min
    uint256 private _currentTokenBalanceForLP = 0;
                    
    
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 bnbReceived, uint256 tokensIntoLiqudity);
    
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }    



    
    constructor ()  public  {
        _rOwned[_msgSender()] = _rTotal;
        
        // The PancakeSwap v2 router address is hardcoded 
        IPancakeRouter02 _pancakeswapV2Router = IPancakeRouter02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
        // Main Net : 0x10ED43C718714eb63d5aA57B78B54704E256024E
        // Test Net : 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3 

         // Create a pancakeswap pair for this new token
        pancakeswapV2Pair = IPancakeFactory(_pancakeswapV2Router.factory())
            .createPair(address(this), _pancakeswapV2Router.WETH()); // WETH is WBNB 

        // set the rest of the contract variables
        pancakeswapV2Router = _pancakeswapV2Router;
        
        // Exclude owner, this contract and the burn address from fees
        excludeFromFee(owner());  
        excludeFromFee(address(this));
        excludeFromFee(BURNADDRESS);

        // Exclude owner, this contract and the burn address from rewards
        excludeFromReward(owner());
        excludeFromReward(address(this));
        excludeFromReward(BURNADDRESS);
        
        
        /* Keep 60 % of the tokens in this contract => It will be burnt progressively with the autoBurn feature
            The remaining 40 % will go to the owner contract (see the website for more info about the tokenomics) */
        _currentTokenBalanceForBurn = MAXBURNAMOUNT;
        uint256 tokenToTransfer = _tTotal.sub(MAXBURNAMOUNT);
        _tOwned[owner()] = tokenToTransfer;
        _tOwned[address(this)] = _currentTokenBalanceForBurn;
        emit Transfer(address(0), owner(), tokenToTransfer); 

    }
    
    function addLiquiditySimu() external payable{
        
        uint tokenAmount = 1* 10**11 * 10**10; // 10% of total supply
        
        require(address(this).balance>0, "Balance is 0");
        uint bnbAmount = address(this).balance; //1BNB
        
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(pancakeswapV2Router), tokenAmount);

        // add the liquidity
        pancakeswapV2Router.addLiquidityETH{value: bnbAmount}( // ETH is BNB
            address(this), 
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this), // LP tokens will be kept in this smart contract
            block.timestamp
        );   
        
        
        
         
    }
    
    
    function getPairAddress() public view returns(address) {
   		return pancakeswapV2Pair;
   	}
    
    function balanceBNB() public view returns(uint) {
    
    	return address(this).balance;
    }
    
    

    // ----------------------------------------------------- //
    // Generic public info about the token
    // ----------------------------------------------------- //
    
    /// @return the name of the token
    function name() external pure returns (string memory) {return NAME;}

    /// @return the symbol of the token
    function symbol() external pure returns (string memory) {return SYMBOL;}

    /// @return the decimals of the token
    function decimals() external pure returns (uint8) {return DECIMALS;}

    /// @return the total supply of the token
    function totalSupply() external view override returns (uint256) {return _tTotal;}
    
    
    // ----------------------------------------------------- //
    // Main functions that need to be overriden (from IERC20)
    // ----------------------------------------------------- //
    
    /** 
        @param account : The address we will use to know the balance 
        @dev The balance is either obtained from tOwned or it is the reflection of the rOwned balance.
        @return the balance of the account
    */
    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcludedFromReward[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    /** 
        @param recipient : The address of the recipient
        @param amount    : The amount of tokens that are being transfered
        @notice We are updating the number of hodlers by observing the balances before and after the transfer
        @return True
    */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        
        (uint256 balancePreTransferSender, uint256 balancePreTransferRecipient) = getBalanceBeforeTransfer(_msgSender(), recipient);     

        /*  When buying tokens in PancakeSwap : 
            swapBNBForExactTokens calls this function 
            Hence the last argument of _transfer is set to true to indicate a buy */        
        _transfer(_msgSender(), recipient, amount, true);
        
        updateNbHodlers(_msgSender(), balancePreTransferSender);
        updateNbHodlers(recipient, balancePreTransferRecipient);
        
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }


    /** 
        @param sender    : The address of the sender
               recipient : The address of the recipient
               amount    : The amount of tokens that are being transfered
        @notice We are updating the number of hodlers by observing the balances before and after the transfer
        @return True
    */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        
        (uint256 balancePreTransferSender, uint256 balancePreTransferRecipient) = getBalanceBeforeTransfer(sender, recipient);     
        
        
        /*  When selling tokens in PancakeSwap : 
            swapExactTokensForBNBSupportingFeeOnTransferTokens calls the transferFrom function
            Hence the last argument of _transfer is set to false to indicate a sell */
        _transfer(sender, recipient, amount, false);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));

        updateNbHodlers(sender, balancePreTransferSender);
        updateNbHodlers(recipient, balancePreTransferRecipient);
             
        
        return true;
    }
    
    
    
    // TODO : check how those functions are used
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }
    
    
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    /** 
        @param sender    : The address of the sender
               recipient : The address of the recipient
        @return The current balances of the sender and the recipient
    */    
    function getBalanceBeforeTransfer(address sender, address recipient) private view returns (uint256, uint256) {return (balanceOf(sender), balanceOf(recipient));}
    
    
    /** 
        @param hodler : The address of a hodler (user)
               balanceBeforeTransfer : The balance of the hodler before a transfer
        @notice This function checks the balances before and after a transfer to identify new hodlers
    */      
    function updateNbHodlers(address hodler, uint256 balanceBeforeTransfer) private {
        
        // pancakeswapV2Pair should not be included in the list of hodlers
        if (hodler == pancakeswapV2Pair)
            return;
        
        /* Note that we check if the balance is very low and not zero.
           This is because when someone wants to sell all his tokens, some might be left in the wallet. */
        
        // New hodler (his balance was very low before buying tokens)
        if (balanceBeforeTransfer<=minNumTokenHodler && balanceOf(hodler)>minNumTokenHodler) 
            nb_hodlers = nb_hodlers + 1;
            
        // One hodler leaves the community (his balance is very low after selling tokens)
        else if (balanceBeforeTransfer>minNumTokenHodler && balanceOf(hodler)<=minNumTokenHodler) 
            nb_hodlers = nb_hodlers - 1;
    }
    
    /// @return the total number of hodlers
    function getNumberOfhodler() public view returns (uint256) {return nb_hodlers;}
    
    
    // ----------------------------------------------------- //
    //                  SOFT BURN 
    // ----------------------------------------------------- //
    
    
    function getAmountForLiquidity() public view returns(uint256) {
    	return _currentTokenBalanceForLP;
    }
    
     function getAmountForBurn() public view returns(uint256) {
    	return _currentTokenBalanceForBurn;
    }
       
    
    function _burn(address sender, uint256 amount) external onlyOwner {
        // Todo : define a custom burn function
        _burnAndTakeLiquidity(amount);
    }
    
    // There is a bonus based on the number of hodlers
    // => The amount of rTokens is reduced proportionnaly
    // This function can be called from outside by the owner (via _burn)
    // or by the smart contract with the autoBurn function   
    
    
    /** 
        @param amount : The amount to be burned and/or added to the liquidity pool
        @dev Please refer to the whitepaper for more details about the mecanics of this function
        @return tAmountToBurn : The calculated amount of tokens that has been soft burned
                rAmountToBurn : The calculated reflected amount of tokens that will be reduced from rSupply
    */      
    function _burnAndTakeLiquidity(uint256 amount) private returns (uint256, uint256) {
        
        
        // TODO : check if this works (require should check currentBurnBalance if the sender is the contract)
        // TODO : need to check the real balance allocated for the burn since part og tokenBalanceForBurn goes to liquidity
        require(_currentTokenBalanceForBurn >= amount, "BaseRfiToken: burn amount exceeds balance");

        // Get the current rate
        uint256 currentRate = _getRate();
        
        // Calculate the reflected amount 
        uint256 rAmount = amount.mul(currentRate);
        
        // Calculate the "bonus" that is a percentage of holders => More holders higher the bonus  
        uint256 bonusHodler = (nb_hodlers.mul(100).div(MAXBONUSTOKENHODLERS));
        
        // Calulate the reflected amount to be burned (depending on the bonusHodler)
        uint256 rAmountToBurn = bonusHodler.mul(rAmount).div(100);
        
        // The remaining reflected amount is kept for the liquidity
        uint256 rAmountForLiquidity = rAmount - rAmountToBurn;
        
        // Calculate the amount of tokens to be added to the liquidity pool
        uint256 tAmountForLiquidity = rAmountForLiquidity.div(currentRate);
        
        // Calculate the amount of tokens to be soft burned
        uint256 tAmountToBurn = rAmountToBurn.div(currentRate);
        
        
        // Keep track of the balance allocated for the autoLP    
        _currentTokenBalanceForLP = _currentTokenBalanceForLP.add(tAmountForLiquidity);
        
        
        // Keep track of the balance allocated for the autoBurn
        // Amount of burn has been reduced : part of it is added to the liquidity pool
        // The other part is sent to the burn address
        // TODO : tokenBalanceForBurn or simply tokenBalance ?
        _currentTokenBalanceForBurn.sub(amount);

        // Remove the amount from this contract's balance and send it the burn contract 
        // Note that only tOwned is modified since both this contract and the burn contract will always be excluled from rewards.
        _tOwned[address(this)] = _tOwned[address(this)].sub(tAmountToBurn);
        _tOwned[BURNADDRESS] = _tOwned[BURNADDRESS].add(tAmountToBurn);
            
    

        // Emit the event so that the burn address balance is updated 
        emit Transfer(address(this), BURNADDRESS, amount);
        
        return (tAmountToBurn, rAmountToBurn);
    }    
    


    /// @return the total fee 
    function totalFees() external view returns (uint256) {return _tFeeTotal;}
    
    /// @return the total buyer fee
    function totalBuyerFees() external view returns (uint256) {return _tBuyerFeeTotal;}
    
    /// @return the total seller fee
    function totalSellerFees() external view returns (uint256) {return _tSellerFeeTotal;}
    
    /// @return the total burn 
    function totalBurn() external view returns (uint256) {return _tBurnTotal;}


    /** @param dxSale : boolean 
        @dev This function set the dxSale state variable to enable/disable fees */
    function setDXSale(bool dxSale) external onlyOwner {_dxSale = dxSale;} 


    /** @param rAmount : The reflected amount to be converted back to tokens
        @return the amount of token from the reflected amount balance */
    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }




    /// @param account : The to be excluded from rewards
    function excludeFromReward(address account) public onlyOwner() {
        require(!_isExcludedFromReward[account], "Account is already excluded");
        
        // If the account has som reflected tokens => convert it to tokens
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        
        // Save it to the state variables
        _isExcludedFromReward[account] = true;
        _excluded.push(account);
    }

    /// @param account : The to be included in rewards
    function includeInReward(address account) external onlyOwner() {
        
        // Prevent owner, burn and this contract to be included in rewards
        require(account!=owner(), "Owner cannot be included in rewards !");
        require(account!=address(this), "The token contract cannot be included in rewards !");
        require(account!=BURNADDRESS, "The burn address cannot be included in rewards !");
        
        require(_isExcludedFromReward[account], "Account is not excluded");
        
        // Save it to the state variables
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcludedFromReward[account] = false;
                _excluded.pop();
                break;
            }
        }
    }
    
    /// @return true if the account is excluded from rewards 
    function isExcludedFromReward(address account) public view returns (bool) {return _isExcludedFromReward[account];}


    /// @notice This function exclude from fee the account given in parameter
    function excludeFromFee(address account) public onlyOwner {_isExcludedFromFee[account] = true;}
    
    /// @notice This function include from fee the account given in parameter
    function includeInFee(address account) public onlyOwner {
        
        // Prevent owner, burn and this contract to be included in fees
        require(account!=owner(), "Owner cannot be included in fee !");
        require(account!=address(this), "The token contract cannot be included in fee !");
        require(account!=BURNADDRESS, "The burn address cannot be included in fee !");
        
        _isExcludedFromFee[account] = false;
    }
    
    /// @return true if the account is excluded from fees 
    function isExcludedFromFee(address account) public view returns(bool) {return _isExcludedFromFee[account];}


    // ----------------------------------------------------- //
    // Setter functions that can be called by the owner only
    // ----------------------------------------------------- //

    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        _maxTxAmount = _tTotal.mul(maxTxPercent).div(100); 
    }
    
    
    function setBuyerFee(uint256 buyerFee) external onlyOwner() {
        // BuyerFee is in per-mille
        // Note that Owner cannot set a buyer fee higher than 4%
        if (buyerFee > MAXBUYERFEE) buyerFee = MAXBUYERFEE;
        _buyerFee = buyerFee;
    }     
    
    function setSellerFee(uint256 sellerFee) external onlyOwner() {
        // SellerFee is in per-mille
        // Note that Owner cannot set a seller fee higher than 9%
        if (sellerFee > MAXSELLERFEE) sellerFee = MAXSELLERFEE;        
        _sellerFee = sellerFee;
    } 
    
    
    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }
    
    
    function setBuyBackEnabled(bool _enabled) external onlyOwner {
        BuyBackEnabled = _enabled;
        emit BuyBackEnabledUpdated(_enabled);
    }    
    
    

    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate =  _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if(_isExcludedFromReward[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
            
        // Keep track of the balance allocated for the autoLP
        _currentTokenBalanceForLP = _currentTokenBalanceForLP.add(tLiquidity);
    }
    
    function _autoBurn(uint256 tAmount) private {
        (uint256 tAmountBurned, uint256 rAmountBurned) = _burnAndTakeLiquidity(tAmount);
        _rTotal = _rTotal.sub(rAmountBurned);
        _tBurnTotal = _tBurnTotal.add(tAmountBurned);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }


    function _getValues(uint256 tAmount, bool isBuying) private returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        uint256 tTransferFee;
        if (isBuying) {
            tTransferFee = calculateBuyerFee(tAmount);
            _tBuyerFeeTotal = _tBuyerFeeTotal.add(tTransferFee);
        }
        else {
            tTransferFee = calculateSellerFee(tAmount);
            _tSellerFeeTotal = _tSellerFeeTotal.add(tTransferFee);
        }
        
        uint256 tTransferAmount = tAmount.sub(tTransferFee);
        
        /* Transfer fees are split in half:
            _ First half will be used to add liquidity
            _ Second half will be used to as static reward to all token HODLers */
        uint256 tLiquidityFee = tTransferFee.div(2);
        uint256 tRewardFee = tTransferFee.div(2);
        
        
        // Calculate reflected amounts
        uint256 currentRate = _getRate();
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rRewardFee = tRewardFee.mul(currentRate);
        uint256 rLiquidityFee = tLiquidityFee.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rRewardFee).sub(rLiquidityFee);

        return (rAmount, rTransferAmount, rRewardFee, tTransferAmount, tRewardFee, tLiquidityFee);
    }    


    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;  
        
        /* To get currentSupply for rate calculation, we need to remove the supply from 
           excluded accounts. Indeed, as you can see in the transfer functions,
           even though they are excluded from rewards, they still receive rTokens as well as tTokens. */
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        
        // If rSupply (more or less equals rTotal, that has been reduced with the fee reflection) 
        // TODO : check what happen when rSupply is 0. Will the static reward stop one day ?
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
    

    function calculateBuyerFee(uint256 _amount) private view returns (uint256) {return _amount.mul(_buyerFee).div(PERMILLEDIVISOR);}

    function calculateSellerFee(uint256 _amount) private view returns (uint256) {return _amount.mul(_sellerFee).div(PERMILLEDIVISOR);}
        
    
    function removeAllFee() private {
        if(_buyerFee == 0 && _sellerFee == 0) return;
        
        _previousBuyerFee = _buyerFee;
        _previousSellerFee = _sellerFee;

        _buyerFee = 0;
        _sellerFee = 0;
    }
    
    function restoreAllFee() private {
        _buyerFee = _previousBuyerFee;
        _sellerFee = _previousSellerFee;
    }
    


    
    

  
    
     //to receive BNB from pancakeswapV2Router when swapping
    receive() external payable {}    

    function _transfer(address from,address to, uint256 amount, bool isBuying) private {
        
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        
        if(from != owner() && to != owner() && !_dxSale)
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");



        /************************************************************************
        ************************* Auto LP ***************************************
        *************************************************************************/


        // Get the number of tokens available for the auto LP (removing the supply for the autoBurn)
        uint256 contractTokenBalance = _currentTokenBalanceForLP;
        
        if(contractTokenBalance >= _maxTxAmount)
            contractTokenBalance = _maxTxAmount;

        /* 1) Check if the token balance of this contract is over the min number of
              tokens that we need to initiate a swap + liquidity add.
           2) Check also that we are not already in a liquidity event.
           3) Lastly, check if the sender is not pancakeswap pair. */        
        if (contractTokenBalance >= numTokensSellToAddToLiquidity &&
            !inSwapAndLiquify &&
            //from != pancakeswapV2Pair &&
            swapAndLiquifyEnabled)
        {
            // add liquidity
            swapAndLiquify(numTokensSellToAddToLiquidity);
        }


        /************************************************************************
        ************************* Auto Buyback **********************************
        *************************************************************************/
        
        // TODO : Check the amount of BNB is not too high (maxTrxAmount)
        // The amount of BNB should be small (other idea wa to use getAmountsOut mais les reserves semblent compliqués)
        // TODO : Check if there is a small amount for fees (check swap function)
        
        uint256 contractBNBBalance = address(this).balance;
        
        /* 1) Check if the BNB balance of this contract is over the min number of
              BNB that we need to initiate a buyback.
           2) Check also that we are not already in a buyback event.
           3) Lastly, check if the sender is not pancakeswap pair. */        
        if (contractBNBBalance >= numBNBSellToBuyBack &&
            !inBuyBack &&
            //from != pancakeswapV2Pair &&
            BuyBackEnabled) {
            // BuyBack tokens with all available BNBs
            uint256 bnbAmount = contractBNBBalance - minAmountToKeepForFees;
            swapBNBForTokens(bnbAmount);
        }
        
        
        // TODO : need to know how many token are added to the contract
        
        /************************************************************************
        ************************* Transfer **************************************
        *************************************************************************/          

        //indicates if fee should be deducted from transfer
        bool takeFee = true;
        
        // Do not deduct fees if any account is excluded from fee or we are in dxSale
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to] || _dxSale){
            takeFee = false;
        }
        
        // transfer amount, it will take fees
        _tokenTransfer(from, to, amount, takeFee, isBuying);
    }
    
    
    function swapBNBForTokens(uint256 bnbAmount) private lockTheBuyBack{
        // generate the pancakeswap pair path of token -> WBNB
        address[] memory path = new address[](2);
        //path[0] = pancakeswapV2Router.WBNB(); 
        path[1] = address(this);

        // make the swap
        pancakeswapV2Router.swapETHForExactTokens{value:bnbAmount}( // ETH is BNB
            0, // Any amount
            path,
            address(this),
            block.timestamp);
        
        emit BNBBuyBack(bnbAmount);  // TODO : need to know how many tokens were bought, all the tokens should be burned
    }
    
  

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current BNB balance.
        // this is so that we can capture exactly the amount of BNB that the
        // swap creates, and not make the liquidity event include any BNB that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for BNB
        swapTokensForBNB(half); 

        // how much BNB did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to pancakeswap
        addLiquidity(otherHalf, newBalance);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForBNB(uint256 tokenAmount) private {
        // generate the pancakeswap pair path of token -> WBNB
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeswapV2Router.WETH(); 
        

        _approve(address(this), address(pancakeswapV2Router), tokenAmount);

        // make the swap  ETH is BNB
        pancakeswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens (
            tokenAmount,
            0, // accept any amount of BNB
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(pancakeswapV2Router), tokenAmount);

        // add the liquidity
        pancakeswapV2Router.addLiquidityETH{value: bnbAmount}( // ETH is BNB
            address(this), 
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this), // LP tokens will be kept in this smart contract
            block.timestamp
        );
    }
    
 


    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee, bool isBuying) private {
        if(!takeFee)
            removeAllFee();
            
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) = _getValues(amount, isBuying);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);      
        
        if (_isExcludedFromReward[sender])  _tOwned[sender] = _tOwned[sender].sub(amount);
        if (_isExcludedFromReward[recipient]) _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);

        
        _takeLiquidity(tLiquidity);        
        _reflectFee(rFee, tFee);
        
        // TODO : need to check for enough token amount to burn (it will be zero at one moment)
        _autoBurn(tFee);
        
        if(!takeFee)
            restoreAllFee();
    }


}

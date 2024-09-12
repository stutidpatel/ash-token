// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IDexRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

interface IDexFactory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

interface IDexPair {
    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
}

contract AshToken is ERC20, Ownable {
    using Address for address;

    uint256 public constant maxTax = 100; // 10% maximum tax :                        10% = 100
    uint256 public buyTax;
    uint256 public sellTax;

    uint256 public transferTax = 100; // 10% Distribution tax :                   10% = 100
    uint256 public constant daoFundTax = 800; // 80% tax for DAO Fund :                   80% = 800
    uint256 public constant marketingTax = 135; // 13.5% tax for Marketing/Operations :     13.5% = 135
    uint256 public constant liquidityTax = 25; // 2.5% tax for Liquidity Pool :            2.5% = 25
    uint256 public constant reflectionsTax = 25; // 2.5% tax for Reflections :               2.5% = 25
    uint256 public constant burningTax = 15; // 1.5% burning :                           1.5% = 15

    uint256 public daoThreshold;
    uint256 public marketingThreshold;

    address public immutable dexRouter;
    address public immutable lpPair;
    address public immutable DAO_ADDRESS;
    address public immutable MARKETING_ADDRESS;

    uint256 public constant MAX = ~uint256(0);
    uint256 public constant tTotal = 10 * 10 ** 12 * 10 ** 18;
    uint256 public rTotal = (MAX - (MAX % tTotal));
    uint256 public tFeeTotal;

    mapping(address => uint256) public rOwned;
    mapping(address => uint256) public tOwned;
    mapping(address => bool) public isExcludedFromFees;
    mapping(address => bool) public automatedMarketMakerPairs;

    bool public inSwapAndLiquify;

    // Overflow Protection Variables
    uint256 public lastMintTimestamp;
    uint256 public mintCapPerPeriod; // 1% of 2 days supply
    uint256 public constant mintCapPercentage = 1; // 1% cap
    uint256 public lastMintTime;
    uint256 public mintedAmountInPeriod;

    // 2 days in seconds
    uint256 public constant secondsIn2Days = 2 * 24 * 60 * 60;

    uint256 public futureDate; // The future date when tokens will start to be released
    uint256 public DCATimeFrame; // The timeframe over which the release will occur
    uint256 public snapshotDate; // The snapshot date for the token calculation
    uint256 public timeLockReleasePercentage; // Percentage of total supply to release
    uint256 public tokensReleased; // Track the amount of tokens already released
    mapping(address => uint256) public lockedTokens; // Track the locked tokens for each address

    event ExcludeFromFees(address indexed account, bool indexed value);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event ClaimTokens(address indexed token, uint256 amount);
    event SetBuySellTax(uint256 buyTax, uint256 sellTax);
    event SetTransferTax(uint256 transferTax);
    event SetThreshold(uint256 daoThreshold, uint256 marketingThreshold);
    event SwapAndEvolve(
        uint256 ashSwapped,
        uint256 bnbReceived,
        uint256 ashIntoLiquidity
    );
    event Mint(address indexed account, uint256 amount);
    event TimeLockSet(
        uint256 futureDate,
        uint256 DCATimeFrame,
        uint256 snapshotDate
    );
    event TiBIUpdated(uint256 newTIBI);

    constructor() ERC20("Ash Token", "ASH") Ownable(msg.sender) {
        address _wbnb;
        address _dexRouter;

        if (block.chainid == 56) {
            // bsc mainnet
            _wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // WETH
            _dexRouter = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4; // PCS V2
        } else if (block.chainid == 97) {
            // bsc testnet
            _wbnb = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd; // WETH
            _dexRouter = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1; // PCS V2
        } else if (block.chainid == 5) {
            _wbnb = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6; // WETH
            _dexRouter = 0x9a489505a00cE272eAa5e07Dba6491314CaE3796; // PCS V2
        } else {
            // revert("Chain not configured"); // for testing on hardhat
        }

        // Create Pair
        // lpPair = IDexFactory(IDexRouter(_dexRouter).factory()).createPair(
        //     address(this),
        //     _wbnb
        // );

        buyTax = 80;
        sellTax = 80;

        daoThreshold = 10 ** 8 * 10 ** 18;
        marketingThreshold = 5 * 10 ** 7 * 10 ** 18;

        // Initialize mint cap            // Number of seconds in 2 days
        mintCapPerPeriod = (tTotal / 100) / (2 * 24 * 60 * 60); // 1% of total supply per 2 days

        isExcludedFromFees[msg.sender] = true;
        isExcludedFromFees[address(this)] = true;
        isExcludedFromFees[address(0xdead)] = true;

        dexRouter = _dexRouter;
        DAO_ADDRESS = 0x73A71240E5Ca0F1ABa08e6Ec081a81064209bC7A; // Set the DAO Fund address
        MARKETING_ADDRESS = 0x092fe11a9B2a54a704E74c6AB2005efcf1e84215; // Set the Marketing/Operations address

        _mint(owner(), tTotal);
    }

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    function totalSupply() public pure override returns (uint256) {
        return tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return tokenFromReflection(rOwned[account]);
    }

    receive() external payable {}

    function tokenFromReflection(
        uint256 rAmount
    ) public view returns (uint256) {
        require(
            rAmount <= rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    /*function _update(address sender, address recipient, uint256 amount) internal virtual override {
        require(amount > 0, "Transfer amount must be greater than zero");

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (isExcludedFromFees[sender] || isExcludedFromFees[recipient]) {
            takeFee = false;
        }

        uint256 feeAmount;

        if (automatedMarketMakerPairs[sender]) feeAmount = buyTax;
        else if (automatedMarketMakerPairs[recipient]) feeAmount = sellTax;
        else feeAmount = transferTax;

        if (inSwapAndLiquify || !takeFee) feeAmount = 0;
           
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tDao, uint256 tMarketing, uint256 tLiquidity, uint256 tBurning) = _getValues(amount, feeAmount);
        
        rOwned[sender] = rOwned[sender] - rAmount;
        rOwned[recipient] = rOwned[recipient] + rTransferAmount; 

        if (feeAmount > 0) {
            address _daoReceiver;
            address _marketReceiver;

            uint256 _tDao;
            uint256 _tMarketing;

            if (balanceOf(DAO_ADDRESS) + tDao > daoThreshold && !automatedMarketMakerPairs[sender]) {
                _daoReceiver = address(this);
                _tDao = tDao;
            } else {
                _daoReceiver = DAO_ADDRESS;
            }
            _takeFee(sender, tDao, _daoReceiver);
        
            if (balanceOf(MARKETING_ADDRESS) + tMarketing > marketingThreshold && !automatedMarketMakerPairs[sender]) {
                _marketReceiver = address(this);
                _tMarketing = tMarketing;
            } else {
                _marketReceiver = MARKETING_ADDRESS;
            }    
            _takeFee(sender, tMarketing, _marketReceiver);

            if (_tDao + _tMarketing > 0) {
                uint256 beforeBalance = address(this).balance;
                swapTokensForBnb(_tDao + _tMarketing, address(this)); 
                uint256 afterBalance = address(this).balance;

                uint256 _bnbBalance = afterBalance - beforeBalance;
                uint256 _daoBalance = _bnbBalance * _tDao/(_tDao + _tMarketing);

                payable(DAO_ADDRESS).transfer(_daoBalance);
                payable(MARKETING_ADDRESS).transfer(_bnbBalance - _daoBalance);

            }

            _takeFee(sender, tLiquidity, address(this));
            _takeBurn(sender, tBurning);

            _reflectFee(rFee, tFee);
        }


        emit Transfer(sender, recipient, tTransferAmount);

    }
*/
    function swapTokensForBnb(
        uint256 tokenAmount,
        address receiver
    ) private lockTheSwap {
        // generate the uniswap pair path of token -> wbnb
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = IDexRouter(dexRouter).WETH();

        _approve(address(this), address(dexRouter), tokenAmount);

        IDexRouter(dexRouter)
            .swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokenAmount,
                0,
                path,
                receiver,
                block.timestamp
            );
    }

    function swapAndEvolve() public onlyOwner lockTheSwap {
        // split the contract balance into halves
        uint256 contractAshBalance = balanceOf(address(this));
        // require(contractAshBalance >= numOfAshToSwapAndEvolve, "ASH balance is not reach for S&E Threshold");

        uint256 half = contractAshBalance / 2;
        uint256 otherHalf = contractAshBalance - half;

        // capture the contract's current BNB balance.
        // this is so that we can capture exactly the amount of BNB that the
        // swap creates, and not make the liquidity event include any BNB that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap ASH for BNB
        swapTokensForBnb(half, address(this));

        // how much BNB did we just swap into?
        uint256 newBalance = address(this).balance;
        uint256 swapeedBNB = newBalance - initialBalance;

        // add liquidity to Pancakeswap
        addLiquidity(otherHalf, swapeedBNB);

        emit SwapAndEvolve(half, swapeedBNB, otherHalf);
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(dexRouter), tokenAmount);

        // add the liquidity
        IDexRouter(dexRouter).addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    function _takeFee(
        address sender,
        uint256 tAmount,
        address recipient
    ) private {
        if (recipient == address(0)) return;
        if (tAmount == 0) return;

        uint256 currentRate = _getRate();
        uint256 rAmount = tAmount * currentRate;
        rOwned[recipient] = rOwned[recipient] + rAmount;

        emit Transfer(sender, recipient, tAmount);
    }

    function _takeBurn(address sender, uint256 _amount) private {
        if (_amount == 0) return;
        tOwned[address(0xdead)] = tOwned[address(0xdead)] + _amount;
        uint256 _rAmount = _amount * _getRate();
        rOwned[address(0xdead)] = rOwned[address(0xdead)] + _rAmount;

        emit Transfer(sender, address(0xdead), _amount);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        rTotal = rTotal - rFee;
        tFeeTotal = tFeeTotal + tFee;
    }

    function _getValues(
        uint256 tAmount,
        uint256 feeAmount
    )
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (
            uint256 tTransferAmount,
            uint256 tDao,
            uint256 tMarketing,
            uint256 tLiquidity,
            uint256 tFee,
            uint256 tBurning
        ) = _getTValues(tAmount, feeAmount);
        uint256 currentRate = _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tDao,
            tMarketing,
            tLiquidity,
            tFee,
            tBurning,
            currentRate
        );
        return (
            rAmount,
            rTransferAmount,
            rFee,
            tTransferAmount,
            tFee,
            tDao,
            tMarketing,
            tLiquidity,
            tBurning
        );
    }

    function _getTValues(
        uint256 tAmount,
        uint256 feeAmount
    )
        private
        pure
        returns (uint256, uint256, uint256, uint256, uint256, uint256)
    {
        uint256 transFee = tAmount * feeAmount;

        uint256 tDao = (transFee * daoFundTax) / 1000000;
        uint256 tMarketing = (transFee * marketingTax) / 1000000;
        uint256 tLiquidity = (transFee * liquidityTax) / 1000000;
        uint256 tFee = (transFee * reflectionsTax) / 1000000;
        uint256 tBurning = transFee /
            1000 -
            tDao -
            tMarketing -
            tLiquidity -
            tFee;

        uint256 tTransferAmount = tAmount - transFee / 1000;

        return (tTransferAmount, tDao, tMarketing, tLiquidity, tFee, tBurning);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tDao,
        uint256 tMarketing,
        uint256 tLiquidity,
        uint256 tFee,
        uint256 tBurning,
        uint256 currentRate
    ) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount * currentRate;

        uint256 rDao = tDao * currentRate;
        uint256 rMarketing = tMarketing * currentRate;
        uint256 rLiquidity = tLiquidity * currentRate;
        uint256 rFee = tFee * currentRate;
        uint256 rBurning = tBurning * currentRate;

        uint256 rTransferAmount = rAmount -
            rDao -
            rMarketing -
            rLiquidity -
            rFee -
            rBurning;

        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = rTotal;
        uint256 tSupply = tTotal;

        if (rSupply < rTotal / tTotal) return (rTotal, tTotal);
        return (rSupply, tSupply);
    }

    function claimTokens(address _token) external onlyOwner {
        IERC20 token = IERC20(_token);
        bool success = token.transfer(owner(), token.balanceOf(address(this)));

        if (success) {
            emit ClaimTokens(_token, token.balanceOf(address(this)));
        }
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(
            isExcludedFromFees[account] != excluded,
            "error: Account is already the value of 'excluded'"
        );
        isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function setAutomatedMarketMakerPair(
        address pair,
        bool value
    ) public onlyOwner {
        require(
            pair != lpPair || value,
            "The pair cannot be removed from automatedMarketMakerPairs"
        );
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function setThreshold(
        uint256 _daoThreshold,
        uint256 _marketingThreshold
    ) external onlyOwner {
        require(_daoThreshold > 0 && _marketingThreshold > 0, "Should over 0");

        daoThreshold = _daoThreshold;
        marketingThreshold = _marketingThreshold;

        emit SetThreshold(_daoThreshold, _marketingThreshold);
    }

    function setTransferTax(uint256 _transferTax) external onlyOwner {
        require(_transferTax <= maxTax, "Cannot exceed maximum tax of 10%");

        transferTax = _transferTax;

        emit SetTransferTax(_transferTax);
    }

    function setTax(uint256 _buyTax, uint256 _sellTax) external onlyOwner {
        require(
            _buyTax <= maxTax && _sellTax <= maxTax,
            "Cannot exceed maximum tax of 10%"
        );

        buyTax = _buyTax;
        sellTax = _sellTax;

        emit SetBuySellTax(_buyTax, _sellTax);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        require(to != address(0), "ERC20: mint to the zero address");

        // Calculate 1% of total supply
        uint256 onePercentOfTotalSupply = (tTotal * mintCapPercentage) / 100;

        // Check if period has elapsed
        if (block.timestamp >= lastMintTime + secondsIn2Days) {
            // Reset the period
            lastMintTime = block.timestamp;
            mintedAmountInPeriod = 0;
        }

        // Calculate mint cap for the period
        uint256 remainingMintCap = onePercentOfTotalSupply -
            mintedAmountInPeriod;
        require(
            amount <= remainingMintCap,
            "Minting exceeds 1% cap for the period"
        );

        _mint(to, amount);

        // Update reflection balances
        uint256 currentRate = _getRate();
        rOwned[to] += amount * currentRate; // Update reflection balance
        tOwned[to] += amount; // Update actual token balance
        mintedAmountInPeriod += amount;
        emit Transfer(address(0), to, amount);
    }
   

    // Set Time Lock
    function setTimeLock(
        uint256 _futureDate,
        uint256 _DCATimeFrame,
        uint256 _snapshotDate,
        uint256 _releasePercentage
    ) external onlyOwner {
        require(
            _futureDate > block.timestamp,
            "Future date must be in the future"
        );
        require(_DCATimeFrame > 0, "Time frame must be greater than zero");
        require(
            _releasePercentage <= 100,
            "Release percentage must be between 0 and 100"
        );

        futureDate = _futureDate;
        DCATimeFrame = _DCATimeFrame;
        snapshotDate = _snapshotDate;
        timeLockReleasePercentage = _releasePercentage;
    }

    // Lock Tokens
    function lockTokens(address account, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        require(
            balanceOf(owner()) >= amount,
            "Insufficient balance to lock tokens"
        );

        _transfer(owner(), address(this), amount);
        lockedTokens[account] += amount;
    }

    // Release Locked Tokens
    function releaseLockedTokens() external {
        require(
            block.timestamp >= futureDate,
            "Tokens cannot be released before the future date"
        );

        uint256 elapsedTime = block.timestamp - futureDate;
        uint256 releasePeriod = DCATimeFrame;
        uint256 totalReleasable = (totalSupply() * timeLockReleasePercentage) /
            100;
        uint256 releasableAmount = (totalReleasable * elapsedTime) /
            releasePeriod;

        require(
            releasableAmount > tokensReleased,
            "No tokens to release at this time"
        );

        uint256 toRelease = releasableAmount - tokensReleased;
        require(
            lockedTokens[msg.sender] >= toRelease,
            "Insufficient locked tokens"
        );

        tokensReleased += toRelease;
        lockedTokens[msg.sender] -= toRelease;

        _transfer(address(this), msg.sender, toRelease);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseHook} from "@v4-periphery/utils/BaseHook.sol";
import {IPoolManager} from "@v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "@v4-core/libraries/Hooks.sol";
import {PoolKey} from "@v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@v4-core/types/Currency.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TickMath} from "@v4-core/libraries/TickMath.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@v4-core/types/BalanceDelta.sol";
import {IHooks} from "@v4-core/interfaces/IHooks.sol";
import {BeforeSwapDelta} from "@v4-core/types/BeforeSwapDelta.sol";
import {LiquidityAmounts} from "@v4-periphery/libraries/LiquidityAmounts.sol";
import {IUnlockCallback} from "@v4-core/interfaces/callback/IUnlockCallback.sol";
import {PoolIdLibrary} from "@v4-core/types/PoolId.sol";
import {PoolId} from "@v4-core/types/PoolId.sol";
import {OutcomeTokenFactory} from "../tokens/OutcomeTokenFactory.sol";
import {IOracleAdapter} from "../oracles/IOracleAdapter.sol";

/// @title MultiOutcomePredictionMarketHook
/// @notice Uniswap v4 hook supporting prediction markets with N outcomes (2-10)
/// @dev Each outcome gets its own USDC-paired pool. Generalizes the binary PredictionMarketHook.
contract MultiOutcomePredictionMarketHook is BaseHook, Ownable, IUnlockCallback {
    using CurrencyLibrary for Currency;
    using SafeERC20 for IERC20;
    using PoolIdLibrary for PoolKey;

    // ============ Constants ============

    uint256 public constant MAX_OUTCOMES = 10;
    uint256 public constant MIN_OUTCOMES = 2;
    uint24 public constant POOL_FEE = 3000;
    int24 public constant TICK_SPACING = 60;
    int24 public constant TICK_LOWER = -887220;
    int24 public constant TICK_UPPER = 887220;

    // ============ Enums ============

    enum MarketState { Created, PoolsInitialized, Open, Closed, Resolved }
    enum OperationType { None, AddLiquidity, RemoveLiquidity, Swap }

    // ============ Structs ============

    struct Market {
        string question;
        MarketState state;
        uint256 outcomeCount;
        uint256 startTime;
        uint256 endTime;
        uint256 totalUSDCCollected;
        address resolver; // Oracle adapter or owner allowed to resolve
    }

    struct OutcomeInfo {
        address token;
        PoolKey poolKey;
        bool isUSDCToken0;
        uint256 usdcInPool;
        uint256 tokensInPool;
        uint256 hookTokenBalance; // Tokens held by hook after resolution
    }

    struct MarketSnapshot {
        uint256 totalVolume;
        uint256 totalBets;
        uint256 lastUpdateTimestamp;
    }

    struct OperationContext {
        OperationType operationType;
        uint256 marketId;
        uint256 outcomeIndex;
        PoolKey poolKey;
        IPoolManager.ModifyLiquidityParams modifyParams;
        IPoolManager.SwapParams swapParams;
        address recipient;
    }

    // ============ State ============

    address public immutable usdc;
    OutcomeTokenFactory public immutable tokenFactory;

    uint256 public nextMarketId;

    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(uint256 => OutcomeInfo)) public outcomes;
    mapping(uint256 => uint256[]) public winningOutcomes; // marketId => winning outcome indices
    mapping(uint256 => mapping(address => bool)) public hasClaimed; // marketId => user => claimed
    mapping(uint256 => MarketSnapshot) public marketSnapshots;

    // Reverse lookup: poolId => (marketId, outcomeIndex) for hook callbacks
    mapping(PoolId => uint256) internal _poolToMarketId;
    mapping(PoolId => uint256) internal _poolToOutcomeIndex;
    mapping(PoolId => bool) internal _isRegisteredPool;

    OperationContext internal _currentOperation;

    // ============ Events ============

    event MarketCreated(uint256 indexed marketId, string question, uint256 outcomeCount, address resolver);
    event MarketOpened(uint256 indexed marketId, uint256 startTime, uint256 endTime);
    event MarketClosed(uint256 indexed marketId, uint256 closeTime);
    event MarketResolved(uint256 indexed marketId, uint256[] winningOutcomes);
    event BetPlaced(uint256 indexed marketId, uint256 indexed outcomeIndex, address indexed user, uint256 usdcAmount, uint256 tokensReceived);
    event BetSold(uint256 indexed marketId, uint256 indexed outcomeIndex, address indexed user, uint256 tokenAmount, uint256 usdcReceived);
    event WinningsClaimed(uint256 indexed marketId, address indexed user, uint256 usdcAmount);
    event PoolInitialized(uint256 indexed marketId, uint256 indexed outcomeIndex, address token);
    event MarketReset(uint256 indexed marketId);

    // ============ Constructor ============

    constructor(
        IPoolManager _poolManager,
        address _usdc,
        OutcomeTokenFactory _tokenFactory
    ) BaseHook(IPoolManager(_poolManager)) Ownable(tx.origin) {
        usdc = _usdc;
        tokenFactory = _tokenFactory;
    }

    // ============ Hook Permissions ============

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // ============ Market Lifecycle ============

    /// @notice Create a new prediction market with N outcomes
    /// @param question The prediction question
    /// @param outcomeNames Names for each outcome token
    /// @param outcomeSymbols Symbols for each outcome token
    /// @param initialSupplyPerOutcome Token supply minted per outcome
    /// @param resolver Address of the oracle adapter that can resolve this market (address(0) = owner only)
    /// @return marketId The ID of the created market
    function createMarket(
        string calldata question,
        string[] calldata outcomeNames,
        string[] calldata outcomeSymbols,
        uint256 initialSupplyPerOutcome,
        address resolver
    ) external onlyOwner returns (uint256 marketId) {
        uint256 count = outcomeNames.length;
        require(count >= MIN_OUTCOMES && count <= MAX_OUTCOMES, "Invalid outcome count");
        require(count == outcomeSymbols.length, "Names/symbols length mismatch");
        require(initialSupplyPerOutcome > 0, "Zero supply");

        marketId = nextMarketId++;

        markets[marketId] = Market({
            question: question,
            state: MarketState.Created,
            outcomeCount: count,
            startTime: 0,
            endTime: 0,
            totalUSDCCollected: 0,
            resolver: resolver == address(0) ? owner() : resolver
        });

        // Deploy outcome tokens via factory
        for (uint256 i = 0; i < count; i++) {
            address token = tokenFactory.createToken(
                marketId,
                i,
                outcomeNames[i],
                outcomeSymbols[i],
                initialSupplyPerOutcome,
                address(this) // Mint to this hook contract
            );
            outcomes[marketId][i].token = token;
        }

        emit MarketCreated(marketId, question, count, markets[marketId].resolver);
    }

    /// @notice Convenience function to create a binary YES/NO market
    function createBinaryMarket(
        string calldata question,
        uint256 initialSupplyPerOutcome,
        address resolver
    ) external onlyOwner returns (uint256 marketId) {
        string[] memory names = new string[](2);
        names[0] = "Yes";
        names[1] = "No";
        string[] memory symbols = new string[](2);
        symbols[0] = "YES";
        symbols[1] = "NO";

        // Use this.createMarket to call the external function (which checks onlyOwner on msg.sender)
        // Instead, inline the logic since we're already onlyOwner
        uint256 count = 2;
        marketId = nextMarketId++;

        markets[marketId] = Market({
            question: question,
            state: MarketState.Created,
            outcomeCount: count,
            startTime: 0,
            endTime: 0,
            totalUSDCCollected: 0,
            resolver: resolver == address(0) ? owner() : resolver
        });

        for (uint256 i = 0; i < count; i++) {
            address token = tokenFactory.createToken(
                marketId, i, names[i], symbols[i], initialSupplyPerOutcome, address(this)
            );
            outcomes[marketId][i].token = token;
        }

        emit MarketCreated(marketId, question, count, markets[marketId].resolver);
    }

    /// @notice Initialize pools for all outcomes of a market
    /// @param marketId The market to initialize
    /// @param usdcPerPool Amount of USDC to seed each pool with
    /// @param tokensPerPool Amount of outcome tokens to seed each pool with
    function initializePools(
        uint256 marketId,
        uint256 usdcPerPool,
        uint256 tokensPerPool
    ) external onlyOwner {
        Market storage market = markets[marketId];
        require(market.state == MarketState.Created, "Market not in Created state");
        require(market.outcomeCount > 0, "Market has no outcomes");

        for (uint256 i = 0; i < market.outcomeCount; i++) {
            _initializeOutcomePool(marketId, i, usdcPerPool, tokensPerPool);
        }

        market.state = MarketState.PoolsInitialized;
    }

    /// @notice Open a market for betting
    function openMarket(uint256 marketId) external onlyOwner {
        Market storage market = markets[marketId];
        require(market.state == MarketState.PoolsInitialized, "Pools not initialized");

        market.state = MarketState.Open;
        market.startTime = block.timestamp;
        market.endTime = block.timestamp + 7 days;

        emit MarketOpened(marketId, market.startTime, market.endTime);
    }

    /// @notice Close a market to stop betting
    function closeMarket(uint256 marketId) external onlyOwner {
        Market storage market = markets[marketId];
        require(market.state == MarketState.Open, "Market not open");

        market.state = MarketState.Closed;
        market.endTime = block.timestamp;

        emit MarketClosed(marketId, block.timestamp);
    }

    /// @notice Resolve a market with the winning outcome(s)
    /// @param marketId The market to resolve
    /// @param _winningOutcomes Array of winning outcome indices
    function resolveMarket(uint256 marketId, uint256[] calldata _winningOutcomes) external {
        Market storage market = markets[marketId];
        require(market.state == MarketState.Closed, "Market not closed");
        require(msg.sender == market.resolver || msg.sender == owner(), "Not authorized");
        require(_winningOutcomes.length > 0, "No winners specified");

        // Validate outcome indices
        for (uint256 i = 0; i < _winningOutcomes.length; i++) {
            require(_winningOutcomes[i] < market.outcomeCount, "Invalid outcome index");
        }

        // Remove liquidity from all pools
        for (uint256 i = 0; i < market.outcomeCount; i++) {
            _removeLiquidityFromPool(marketId, i);
        }

        // Collect total USDC and record hook's token balances
        market.totalUSDCCollected = IERC20(usdc).balanceOf(address(this));

        for (uint256 i = 0; i < market.outcomeCount; i++) {
            outcomes[marketId][i].hookTokenBalance = IERC20(outcomes[marketId][i].token).balanceOf(address(this));
        }

        // Store winning outcomes
        for (uint256 i = 0; i < _winningOutcomes.length; i++) {
            winningOutcomes[marketId].push(_winningOutcomes[i]);
        }

        market.state = MarketState.Resolved;

        emit MarketResolved(marketId, _winningOutcomes);
    }

    /// @notice Claim winnings from a resolved market
    function claim(uint256 marketId) external {
        Market storage market = markets[marketId];
        require(market.state == MarketState.Resolved, "Market not resolved");
        require(!hasClaimed[marketId][msg.sender], "Already claimed");

        uint256[] storage winners = winningOutcomes[marketId];
        require(winners.length > 0, "No winners");

        // Calculate user's share across all winning outcomes
        uint256 totalShare = 0;
        uint256 usdcPerWinner = market.totalUSDCCollected / winners.length;

        for (uint256 i = 0; i < winners.length; i++) {
            uint256 outcomeIdx = winners[i];
            OutcomeInfo storage info = outcomes[marketId][outcomeIdx];
            address token = info.token;

            uint256 userBalance = IERC20(token).balanceOf(msg.sender);
            if (userBalance == 0) continue;

            uint256 totalCirculating = IERC20(token).totalSupply() - info.hookTokenBalance;
            if (totalCirculating == 0) continue;

            totalShare += (userBalance * usdcPerWinner) / totalCirculating;
        }

        require(totalShare > 0, "No winning tokens held");

        hasClaimed[marketId][msg.sender] = true;
        IERC20(usdc).transfer(msg.sender, totalShare);

        emit WinningsClaimed(marketId, msg.sender, totalShare);
    }

    // ============ Swap Functions ============

    /// @notice Swap USDC for outcome tokens or vice versa
    /// @param marketId The market to trade in
    /// @param outcomeIndex Which outcome to trade
    /// @param buyOutcome True = buy outcome tokens with USDC, False = sell outcome tokens for USDC
    /// @param amountIn Amount of input tokens
    /// @param minAmountOut Minimum output tokens (slippage protection)
    /// @return amountOut Actual output amount
    function swap(
        uint256 marketId,
        uint256 outcomeIndex,
        bool buyOutcome,
        uint256 amountIn,
        uint256 minAmountOut
    ) external returns (uint256 amountOut) {
        Market storage market = markets[marketId];
        require(market.state == MarketState.Open, "Market not open");
        require(outcomeIndex < market.outcomeCount, "Invalid outcome");
        require(amountIn > 0, "Zero amount");

        OutcomeInfo storage info = outcomes[marketId][outcomeIndex];

        address tokenIn;
        address tokenOut;

        if (buyOutcome) {
            tokenIn = usdc;
            tokenOut = info.token;
        } else {
            tokenIn = info.token;
            tokenOut = usdc;
        }

        amountOut = _executeSwap(marketId, outcomeIndex, tokenIn, tokenOut, amountIn, msg.sender);
        require(amountOut >= minAmountOut, "Slippage: insufficient output");

        // Update analytics
        MarketSnapshot storage snap = marketSnapshots[marketId];
        uint256 volume = buyOutcome ? amountIn : amountOut; // USDC volume
        snap.totalVolume += volume;
        snap.totalBets++;
        snap.lastUpdateTimestamp = block.timestamp;

        if (buyOutcome) {
            emit BetPlaced(marketId, outcomeIndex, msg.sender, amountIn, amountOut);
        } else {
            emit BetSold(marketId, outcomeIndex, msg.sender, amountIn, amountOut);
        }
    }

    // ============ View Functions ============

    /// @notice Get odds for all outcomes as percentages (sum to 100)
    function getOdds(uint256 marketId) external view returns (uint256[] memory odds) {
        Market storage market = markets[marketId];
        require(market.state == MarketState.Open || market.state == MarketState.PoolsInitialized, "Market not active");

        uint256 count = market.outcomeCount;
        odds = new uint256[](count);

        uint256 totalUSDC = 0;
        for (uint256 i = 0; i < count; i++) {
            totalUSDC += outcomes[marketId][i].usdcInPool;
        }

        if (totalUSDC == 0) {
            uint256 equalOdds = 100 / count;
            for (uint256 i = 0; i < count; i++) {
                odds[i] = equalOdds;
            }
            return odds;
        }

        for (uint256 i = 0; i < count; i++) {
            odds[i] = (outcomes[marketId][i].usdcInPool * 100) / totalUSDC;
        }
    }

    /// @notice Get the price of a single outcome token in USDC terms
    function getOutcomePrice(uint256 marketId, uint256 outcomeIndex) external view returns (uint256 price) {
        OutcomeInfo storage info = outcomes[marketId][outcomeIndex];
        if (info.tokensInPool == 0) return 0;
        price = (info.usdcInPool * 1e18) / info.tokensInPool;
    }

    /// @notice Get a summary of a market
    function getMarketSummary(uint256 marketId) external view returns (
        string memory question,
        MarketState state,
        uint256 outcomeCount,
        uint256 startTime,
        uint256 endTime,
        uint256 totalUSDCCollected,
        address resolver
    ) {
        Market storage m = markets[marketId];
        return (m.question, m.state, m.outcomeCount, m.startTime, m.endTime, m.totalUSDCCollected, m.resolver);
    }

    /// @notice Get a user's token balance for each outcome in a market
    function getUserPosition(uint256 marketId, address user) external view returns (uint256[] memory balances) {
        uint256 count = markets[marketId].outcomeCount;
        balances = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            address token = outcomes[marketId][i].token;
            if (token != address(0)) {
                balances[i] = IERC20(token).balanceOf(user);
            }
        }
    }

    /// @notice Get the total number of markets created
    function getMarketCount() external view returns (uint256) {
        return nextMarketId;
    }

    /// @notice Get outcome details
    function getOutcomeInfo(uint256 marketId, uint256 outcomeIndex) external view returns (
        address token,
        uint256 usdcInPool,
        uint256 tokensInPool,
        uint256 hookTokenBalance
    ) {
        OutcomeInfo storage info = outcomes[marketId][outcomeIndex];
        return (info.token, info.usdcInPool, info.tokensInPool, info.hookTokenBalance);
    }

    /// @notice Get winning outcomes for a resolved market
    function getWinningOutcomes(uint256 marketId) external view returns (uint256[] memory) {
        return winningOutcomes[marketId];
    }

    /// @notice Get analytics snapshot for a market
    function getMarketSnapshot(uint256 marketId) external view returns (
        uint256 totalVolume,
        uint256 totalBets,
        uint256 lastUpdateTimestamp
    ) {
        MarketSnapshot storage s = marketSnapshots[marketId];
        return (s.totalVolume, s.totalBets, s.lastUpdateTimestamp);
    }

    // ============ Hook Callbacks ============

    function _beforeAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) internal view override returns (bytes4) {
        PoolId pid = key.toId();
        require(_isRegisteredPool[pid], "Unknown pool");
        uint256 mid = _poolToMarketId[pid];
        require(markets[mid].state != MarketState.Closed && markets[mid].state != MarketState.Resolved, "Market closed");
        return IHooks.beforeAddLiquidity.selector;
    }

    function _beforeRemoveLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) internal view override returns (bytes4) {
        PoolId pid = key.toId();
        require(_isRegisteredPool[pid], "Unknown pool");
        return IHooks.beforeRemoveLiquidity.selector;
    }

    function _beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) internal view override returns (bytes4, BeforeSwapDelta, uint24) {
        PoolId pid = key.toId();
        require(_isRegisteredPool[pid], "Unknown pool");
        uint256 mid = _poolToMarketId[pid];
        require(markets[mid].state == MarketState.Open, "Market not active");
        return (IHooks.beforeSwap.selector, BeforeSwapDelta.wrap(0), 0);
    }

    function _afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        BalanceDelta delta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        PoolId pid = key.toId();
        if (!_isRegisteredPool[pid]) return (IHooks.afterSwap.selector, 0);

        uint256 mid = _poolToMarketId[pid];
        uint256 oidx = _poolToOutcomeIndex[pid];
        OutcomeInfo storage info = outcomes[mid][oidx];

        int256 usdcDelta;
        int256 tokenDelta;

        if (info.isUSDCToken0) {
            usdcDelta = delta.amount0();
            tokenDelta = delta.amount1();
        } else {
            usdcDelta = delta.amount1();
            tokenDelta = delta.amount0();
        }

        // Update pool balance tracking
        if (usdcDelta < 0) {
            info.usdcInPool += uint256(-usdcDelta);
        } else if (usdcDelta > 0) {
            uint256 abs = uint256(usdcDelta);
            info.usdcInPool = info.usdcInPool >= abs ? info.usdcInPool - abs : 0;
        }

        if (tokenDelta < 0) {
            info.tokensInPool += uint256(-tokenDelta);
        } else if (tokenDelta > 0) {
            uint256 abs = uint256(tokenDelta);
            info.tokensInPool = info.tokensInPool >= abs ? info.tokensInPool - abs : 0;
        }

        return (IHooks.afterSwap.selector, 0);
    }

    // ============ Unlock Callback ============

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        require(msg.sender == address(poolManager), "Unauthorized callback");

        if (_currentOperation.operationType == OperationType.None) {
            return "";
        }

        if (_currentOperation.operationType == OperationType.AddLiquidity) {
            return _handleAddLiquidity();
        } else if (_currentOperation.operationType == OperationType.RemoveLiquidity) {
            return _handleRemoveLiquidity();
        } else if (_currentOperation.operationType == OperationType.Swap) {
            uint256 outputAmount = _handleSwap(data);
            return abi.encode(outputAmount);
        }

        return "";
    }

    // ============ Internal: Pool Initialization ============

    function _initializeOutcomePool(
        uint256 marketId,
        uint256 outcomeIndex,
        uint256 usdcAmount,
        uint256 tokenAmount
    ) internal {
        OutcomeInfo storage info = outcomes[marketId][outcomeIndex];
        address token = info.token;
        require(token != address(0), "Token not deployed");

        info.isUSDCToken0 = uint160(usdc) < uint160(token);

        info.poolKey = PoolKey({
            currency0: Currency.wrap(info.isUSDCToken0 ? usdc : token),
            currency1: Currency.wrap(info.isUSDCToken0 ? token : usdc),
            fee: POOL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(this))
        });

        // Register pool for hook callbacks
        PoolId pid = info.poolKey.toId();
        _poolToMarketId[pid] = marketId;
        _poolToOutcomeIndex[pid] = outcomeIndex;
        _isRegisteredPool[pid] = true;

        // Initialize the Uniswap pool at 1:1 price
        IPoolManager(address(poolManager)).initialize(info.poolKey, TickMath.getSqrtPriceAtTick(0));

        // Add initial liquidity
        _addLiquidityToPool(marketId, outcomeIndex, usdcAmount, tokenAmount);

        info.usdcInPool = usdcAmount;
        info.tokensInPool = tokenAmount;

        emit PoolInitialized(marketId, outcomeIndex, token);
    }

    function _addLiquidityToPool(
        uint256 marketId,
        uint256 outcomeIndex,
        uint256 usdcAmount,
        uint256 tokenAmount
    ) internal {
        OutcomeInfo storage info = outcomes[marketId][outcomeIndex];

        uint256 amount0 = info.isUSDCToken0 ? usdcAmount : tokenAmount;
        uint256 amount1 = info.isUSDCToken0 ? tokenAmount : usdcAmount;

        IERC20(Currency.unwrap(info.poolKey.currency0)).approve(address(poolManager), 0);
        IERC20(Currency.unwrap(info.poolKey.currency0)).approve(address(poolManager), amount0);
        IERC20(Currency.unwrap(info.poolKey.currency1)).approve(address(poolManager), 0);
        IERC20(Currency.unwrap(info.poolKey.currency1)).approve(address(poolManager), amount1);

        uint160 sqrtPriceAX96 = TickMath.getSqrtPriceAtTick(-887272);
        uint160 sqrtPriceBX96 = TickMath.getSqrtPriceAtTick(887272);
        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(0);

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, amount0, amount1
        );

        IPoolManager.ModifyLiquidityParams memory params = IPoolManager.ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: int128(liquidity),
            salt: keccak256(abi.encodePacked("eigenbets", marketId, outcomeIndex))
        });

        _currentOperation = OperationContext({
            operationType: OperationType.AddLiquidity,
            marketId: marketId,
            outcomeIndex: outcomeIndex,
            poolKey: info.poolKey,
            modifyParams: params,
            swapParams: IPoolManager.SwapParams({zeroForOne: false, amountSpecified: 0, sqrtPriceLimitX96: 0}),
            recipient: address(0)
        });

        poolManager.unlock(new bytes(0));
        _resetOperation();
    }

    function _removeLiquidityFromPool(uint256 marketId, uint256 outcomeIndex) internal {
        OutcomeInfo storage info = outcomes[marketId][outcomeIndex];

        IPoolManager.ModifyLiquidityParams memory params = IPoolManager.ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: type(int128).min,
            salt: keccak256(abi.encodePacked("eigenbets", marketId, outcomeIndex))
        });

        _currentOperation = OperationContext({
            operationType: OperationType.RemoveLiquidity,
            marketId: marketId,
            outcomeIndex: outcomeIndex,
            poolKey: info.poolKey,
            modifyParams: params,
            swapParams: IPoolManager.SwapParams({zeroForOne: false, amountSpecified: 0, sqrtPriceLimitX96: 0}),
            recipient: address(0)
        });

        poolManager.unlock(new bytes(0));

        // Zero out pool balances
        info.usdcInPool = 0;
        info.tokensInPool = 0;

        _resetOperation();
    }

    // ============ Internal: Swap Execution ============

    function _executeSwap(
        uint256 marketId,
        uint256 outcomeIndex,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address recipient
    ) internal returns (uint256 amountOut) {
        OutcomeInfo storage info = outcomes[marketId][outcomeIndex];

        bool zeroForOne = tokenIn == Currency.unwrap(info.poolKey.currency0);

        // Transfer input tokens from user
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(address(poolManager), amountIn);

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: int256(amountIn),
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        });

        _currentOperation = OperationContext({
            operationType: OperationType.Swap,
            marketId: marketId,
            outcomeIndex: outcomeIndex,
            poolKey: info.poolKey,
            modifyParams: IPoolManager.ModifyLiquidityParams({tickLower: 0, tickUpper: 0, liquidityDelta: 0, salt: bytes32(0)}),
            swapParams: params,
            recipient: recipient
        });

        bytes memory result = poolManager.unlock(new bytes(0));
        amountOut = abi.decode(result, (uint256));

        _resetOperation();
    }

    // ============ Internal: Callback Handlers ============

    function _handleAddLiquidity() internal returns (bytes memory) {
        (BalanceDelta delta, ) = poolManager.modifyLiquidity(
            _currentOperation.poolKey,
            _currentOperation.modifyParams,
            ""
        );
        _processBalanceDelta(delta, _currentOperation.poolKey);
        return "";
    }

    function _handleRemoveLiquidity() internal returns (bytes memory) {
        (BalanceDelta delta, ) = poolManager.modifyLiquidity(
            _currentOperation.poolKey,
            _currentOperation.modifyParams,
            ""
        );
        _processBalanceDelta(delta, _currentOperation.poolKey);
        return "";
    }

    function _handleSwap(bytes calldata data) internal returns (uint256 outputAmount) {
        BalanceDelta delta = poolManager.swap(
            _currentOperation.poolKey,
            _currentOperation.swapParams,
            data
        );

        Currency tokenIn;
        Currency tokenOut;
        uint256 amountIn;
        uint256 amountOut;

        if (_currentOperation.swapParams.zeroForOne) {
            tokenIn = _currentOperation.poolKey.currency0;
            tokenOut = _currentOperation.poolKey.currency1;
            amountIn = uint256(uint128(-delta.amount0()));
            amountOut = uint256(uint128(delta.amount1()));
        } else {
            tokenIn = _currentOperation.poolKey.currency1;
            tokenOut = _currentOperation.poolKey.currency0;
            amountIn = uint256(uint128(-delta.amount1()));
            amountOut = uint256(uint128(delta.amount0()));
        }

        // Settle: transfer input token to pool
        IERC20(Currency.unwrap(tokenIn)).transfer(address(poolManager), amountIn);
        poolManager.settle();

        // Take: pull output token from pool to recipient
        address recipient = _currentOperation.recipient == address(0) ? msg.sender : _currentOperation.recipient;
        poolManager.take(tokenOut, recipient, amountOut);

        return amountOut;
    }

    function _processBalanceDelta(BalanceDelta delta, PoolKey memory key) internal {
        // Negative delta = owe tokens to pool, transfer in
        if (delta.amount0() < 0) {
            uint256 amount = uint256(uint128(-delta.amount0()));
            poolManager.sync(key.currency0);
            IERC20(Currency.unwrap(key.currency0)).safeTransfer(address(poolManager), amount);
            poolManager.settle();
        }
        if (delta.amount1() < 0) {
            uint256 amount = uint256(uint128(-delta.amount1()));
            poolManager.sync(key.currency1);
            IERC20(Currency.unwrap(key.currency1)).safeTransfer(address(poolManager), amount);
            poolManager.settle();
        }

        // Positive delta = pool owes us tokens, take them
        if (delta.amount0() > 0) {
            poolManager.take(key.currency0, address(this), uint256(uint128(delta.amount0())));
        }
        if (delta.amount1() > 0) {
            poolManager.take(key.currency1, address(this), uint256(uint128(delta.amount1())));
        }
    }

    function _resetOperation() internal {
        _currentOperation = OperationContext({
            operationType: OperationType.None,
            marketId: 0,
            outcomeIndex: 0,
            poolKey: PoolKey({
                currency0: Currency.wrap(address(0)),
                currency1: Currency.wrap(address(0)),
                fee: 0,
                tickSpacing: 0,
                hooks: IHooks(address(0))
            }),
            modifyParams: IPoolManager.ModifyLiquidityParams({tickLower: 0, tickUpper: 0, liquidityDelta: 0, salt: bytes32(0)}),
            swapParams: IPoolManager.SwapParams({zeroForOne: false, amountSpecified: 0, sqrtPriceLimitX96: 0}),
            recipient: address(0)
        });
    }
}

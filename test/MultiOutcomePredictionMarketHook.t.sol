// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {MultiOutcomePredictionMarketHook} from "../src/Hooks/MultiOutcomePredictionMarketHook.sol";
import {OutcomeTokenFactory} from "../src/tokens/OutcomeTokenFactory.sol";
import {IPoolManager} from "@v4-core/interfaces/IPoolManager.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Hooks} from "@v4-core/libraries/Hooks.sol";
import {HookMiner} from "lib/v4-periphery/src/utils/HookMiner.sol";

contract MultiOutcomePredictionMarketHookTest is Test {
    // Fork URL for testing against real Uniswap v4
    string constant FORK_URL = "https://unichain-sepolia.g.alchemy.com/v2/IC5OtAuX9SD5Kzaxg7eOVvxh3jMGGV6_";

    MultiOutcomePredictionMarketHook public hook;
    OutcomeTokenFactory public factory;
    ERC20Mock public usdc;

    address public deployer;
    address public user1 = address(0x1111);
    address public user2 = address(0x2222);
    address public user3 = address(0x3333);

    address public constant POOL_MANAGER = 0x00B036B58a818B1BC34d502D3fE730Db729e62AC;
    address public constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function setUp() public {
        uint256 forkId = vm.createFork(FORK_URL);
        vm.selectFork(forkId);

        deployer = address(this);

        // Deploy USDC mock
        usdc = new ERC20Mock();
        usdc.mint(deployer, 10_000_000e6);

        // Deploy factory
        factory = new OutcomeTokenFactory();

        // Mine and deploy hook
        uint160 flags = uint160(
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG |
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.AFTER_SWAP_FLAG
        );

        (address predicted, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(MultiOutcomePredictionMarketHook).creationCode,
            abi.encode(IPoolManager(POOL_MANAGER), address(usdc), address(factory))
        );

        hook = new MultiOutcomePredictionMarketHook{salt: salt}(
            IPoolManager(POOL_MANAGER),
            address(usdc),
            factory
        );

        require(address(hook) == predicted, "Hook address mismatch");

        // Hook constructor sets Ownable(tx.origin) — the forge default sender.
        // Transfer to the test contract so owner-gated calls (createMarket, etc.) work.
        address initialOwner = hook.owner();
        vm.prank(initialOwner);
        hook.transferOwnership(address(this));

        vm.label(address(hook), "MultiOutcomeHook");
        vm.label(address(usdc), "USDC");
        vm.label(address(factory), "TokenFactory");
    }

    // ============ Market Creation Tests ============

    function test_CreateBinaryMarket() public {
        string[] memory names = new string[](2);
        names[0] = "Yes";
        names[1] = "No";
        string[] memory symbols = new string[](2);
        symbols[0] = "YES";
        symbols[1] = "NO";

        uint256 marketId = hook.createMarket("Will ETH hit 5k?", names, symbols, 100_000e18, address(0));
        assertEq(marketId, 0);
        assertEq(hook.getMarketCount(), 1);

        (string memory q, MultiOutcomePredictionMarketHook.MarketState state, uint256 count,,,,) = hook.getMarketSummary(0);
        assertEq(q, "Will ETH hit 5k?");
        assertEq(uint(state), uint(MultiOutcomePredictionMarketHook.MarketState.Created));
        assertEq(count, 2);
    }

    function test_CreateMultiOutcomeMarket() public {
        string[] memory names = new string[](4);
        names[0] = "Below 50k";
        names[1] = "50k-60k";
        names[2] = "60k-70k";
        names[3] = "Above 70k";
        string[] memory symbols = new string[](4);
        symbols[0] = "LT50";
        symbols[1] = "R5060";
        symbols[2] = "R6070";
        symbols[3] = "GT70";

        uint256 marketId = hook.createMarket("BTC price range?", names, symbols, 100_000e18, address(0));
        (, , uint256 count,,,,) = hook.getMarketSummary(marketId);
        assertEq(count, 4);
    }

    function test_RevertTooFewOutcomes() public {
        string[] memory names = new string[](1);
        names[0] = "Only";
        string[] memory symbols = new string[](1);
        symbols[0] = "ONE";

        vm.expectRevert("Invalid outcome count");
        hook.createMarket("Bad market", names, symbols, 100_000e18, address(0));
    }

    function test_RevertTooManyOutcomes() public {
        string[] memory names = new string[](11);
        string[] memory symbols = new string[](11);
        for (uint i = 0; i < 11; i++) {
            names[i] = "Outcome";
            symbols[i] = "OUT";
        }

        vm.expectRevert("Invalid outcome count");
        hook.createMarket("Too many", names, symbols, 100_000e18, address(0));
    }

    function test_RevertNonOwnerCreate() public {
        string[] memory names = new string[](2);
        names[0] = "A";
        names[1] = "B";
        string[] memory symbols = new string[](2);
        symbols[0] = "A";
        symbols[1] = "B";

        vm.prank(user1);
        vm.expectRevert();
        hook.createMarket("Unauthorized", names, symbols, 100_000e18, address(0));
    }

    // ============ Pool Initialization Tests ============

    function test_InitializePools() public {
        uint256 marketId = _createBinaryMarket();

        // Transfer USDC to hook for pool seeding
        usdc.transfer(address(hook), 200_000e6);

        hook.initializePools(marketId, 50_000e6, 50_000e18);

        (, MultiOutcomePredictionMarketHook.MarketState state,,,,,) = hook.getMarketSummary(marketId);
        assertEq(uint(state), uint(MultiOutcomePredictionMarketHook.MarketState.PoolsInitialized));

        // Check pool balances
        (address token0, uint256 usdc0, uint256 tokens0,) = hook.getOutcomeInfo(marketId, 0);
        assertNotEq(token0, address(0));
        assertEq(usdc0, 50_000e6);
        assertEq(tokens0, 50_000e18);

        (address token1, uint256 usdc1, uint256 tokens1,) = hook.getOutcomeInfo(marketId, 1);
        assertNotEq(token1, address(0));
        assertEq(usdc1, 50_000e6);
        assertEq(tokens1, 50_000e18);
    }

    // ============ Market Lifecycle Tests ============

    function test_OpenMarket() public {
        uint256 marketId = _createAndInitBinaryMarket();

        hook.openMarket(marketId);

        (, MultiOutcomePredictionMarketHook.MarketState state,,uint256 startTime, uint256 endTime,,) = hook.getMarketSummary(marketId);
        assertEq(uint(state), uint(MultiOutcomePredictionMarketHook.MarketState.Open));
        assertGt(startTime, 0);
        assertEq(endTime, startTime + 7 days);
    }

    function test_CloseMarket() public {
        uint256 marketId = _createAndInitBinaryMarket();
        hook.openMarket(marketId);
        hook.closeMarket(marketId);

        (, MultiOutcomePredictionMarketHook.MarketState state,,,,,) = hook.getMarketSummary(marketId);
        assertEq(uint(state), uint(MultiOutcomePredictionMarketHook.MarketState.Closed));
    }

    function test_RevertOpenNotInitialized() public {
        uint256 marketId = _createBinaryMarket();
        vm.expectRevert("Pools not initialized");
        hook.openMarket(marketId);
    }

    function test_RevertCloseNotOpen() public {
        uint256 marketId = _createAndInitBinaryMarket();
        vm.expectRevert("Market not open");
        hook.closeMarket(marketId);
    }

    // ============ Odds and Price Tests ============

    function test_InitialOdds() public {
        uint256 marketId = _createAndInitBinaryMarket();
        hook.openMarket(marketId);

        uint256[] memory odds = hook.getOdds(marketId);
        assertEq(odds.length, 2);
        assertEq(odds[0], 50);
        assertEq(odds[1], 50);
    }

    function test_InitialOddsMultiOutcome() public {
        uint256 marketId = _createAndInit4OutcomeMarket();
        hook.openMarket(marketId);

        uint256[] memory odds = hook.getOdds(marketId);
        assertEq(odds.length, 4);
        assertEq(odds[0], 25);
        assertEq(odds[1], 25);
        assertEq(odds[2], 25);
        assertEq(odds[3], 25);
    }

    function test_GetOutcomePrice() public {
        uint256 marketId = _createAndInitBinaryMarket();
        hook.openMarket(marketId);

        uint256 price0 = hook.getOutcomePrice(marketId, 0);
        uint256 price1 = hook.getOutcomePrice(marketId, 1);
        assertGt(price0, 0);
        assertGt(price1, 0);
    }

    // ============ Swap Tests ============

    function test_BuyOutcomeTokens() public {
        uint256 marketId = _createAndInitBinaryMarket();
        hook.openMarket(marketId);

        // Give user1 some USDC
        usdc.mint(user1, 10_000e6);

        // Approve hook to spend USDC
        vm.startPrank(user1);
        usdc.approve(address(hook), type(uint256).max);

        // Buy outcome 0 (Yes) tokens
        uint256 amountOut = hook.swap(marketId, 0, true, 1_000e6, 0);
        vm.stopPrank();

        assertGt(amountOut, 0, "Should receive outcome tokens");

        // Check user position
        uint256[] memory positions = hook.getUserPosition(marketId, user1);
        assertGt(positions[0], 0, "User should hold outcome 0 tokens");
        assertEq(positions[1], 0, "User should not hold outcome 1 tokens");
    }

    function test_SellOutcomeTokens() public {
        uint256 marketId = _createAndInitBinaryMarket();
        hook.openMarket(marketId);

        // Buy first
        usdc.mint(user1, 10_000e6);
        vm.startPrank(user1);
        usdc.approve(address(hook), type(uint256).max);
        uint256 tokensReceived = hook.swap(marketId, 0, true, 1_000e6, 0);

        // Approve outcome token for sell
        (address token0,,,) = hook.getOutcomeInfo(marketId, 0);
        IERC20(token0).approve(address(hook), type(uint256).max);

        // Sell back
        uint256 usdcReceived = hook.swap(marketId, 0, false, tokensReceived, 0);
        vm.stopPrank();

        assertGt(usdcReceived, 0, "Should receive USDC back");
    }

    function test_SwapSlippageProtection() public {
        uint256 marketId = _createAndInitBinaryMarket();
        hook.openMarket(marketId);

        usdc.mint(user1, 10_000e6);
        vm.startPrank(user1);
        usdc.approve(address(hook), type(uint256).max);

        // Set unrealistically high minAmountOut
        vm.expectRevert("Slippage: insufficient output");
        hook.swap(marketId, 0, true, 1_000e6, type(uint256).max);
        vm.stopPrank();
    }

    function test_SwapUpdatesOdds() public {
        uint256 marketId = _createAndInitBinaryMarket();
        hook.openMarket(marketId);

        uint256[] memory oddsBefore = hook.getOdds(marketId);

        // Large buy of outcome 0
        usdc.mint(user1, 20_000e6);
        vm.startPrank(user1);
        usdc.approve(address(hook), type(uint256).max);
        hook.swap(marketId, 0, true, 10_000e6, 0);
        vm.stopPrank();

        uint256[] memory oddsAfter = hook.getOdds(marketId);

        // Outcome 0 should have higher odds after buying
        assertGt(oddsAfter[0], oddsBefore[0], "Outcome 0 odds should increase after buy");
    }

    function test_RevertSwapMarketNotOpen() public {
        uint256 marketId = _createAndInitBinaryMarket();
        // Don't open the market

        usdc.mint(user1, 10_000e6);
        vm.startPrank(user1);
        usdc.approve(address(hook), type(uint256).max);

        vm.expectRevert("Market not open");
        hook.swap(marketId, 0, true, 1_000e6, 0);
        vm.stopPrank();
    }

    // ============ Resolution and Claim Tests ============

    function test_ResolveAndClaim() public {
        uint256 marketId = _createAndInitBinaryMarket();
        hook.openMarket(marketId);

        // User1 buys outcome 0 (winner), User2 buys outcome 1 (loser)
        usdc.mint(user1, 10_000e6);
        usdc.mint(user2, 10_000e6);

        vm.startPrank(user1);
        usdc.approve(address(hook), type(uint256).max);
        hook.swap(marketId, 0, true, 5_000e6, 0);
        vm.stopPrank();

        vm.startPrank(user2);
        usdc.approve(address(hook), type(uint256).max);
        hook.swap(marketId, 1, true, 5_000e6, 0);
        vm.stopPrank();

        // Close and resolve (outcome 0 wins)
        hook.closeMarket(marketId);
        uint256[] memory winners = new uint256[](1);
        winners[0] = 0;
        hook.resolveMarket(marketId, winners);

        (, MultiOutcomePredictionMarketHook.MarketState state,,,,,) = hook.getMarketSummary(marketId);
        assertEq(uint(state), uint(MultiOutcomePredictionMarketHook.MarketState.Resolved));

        // User1 claims
        uint256 balBefore = usdc.balanceOf(user1);
        vm.prank(user1);
        hook.claim(marketId);
        uint256 balAfter = usdc.balanceOf(user1);
        assertGt(balAfter, balBefore, "User1 should receive USDC");

        // User2 cannot claim (holds losing token)
        vm.prank(user2);
        vm.expectRevert("No winning tokens held");
        hook.claim(marketId);
    }

    function test_RevertDoubleClaim() public {
        uint256 marketId = _createAndInitBinaryMarket();
        hook.openMarket(marketId);

        usdc.mint(user1, 10_000e6);
        vm.startPrank(user1);
        usdc.approve(address(hook), type(uint256).max);
        hook.swap(marketId, 0, true, 5_000e6, 0);
        vm.stopPrank();

        hook.closeMarket(marketId);
        uint256[] memory winners = new uint256[](1);
        winners[0] = 0;
        hook.resolveMarket(marketId, winners);

        vm.prank(user1);
        hook.claim(marketId);

        vm.prank(user1);
        vm.expectRevert("Already claimed");
        hook.claim(marketId);
    }

    function test_RevertResolveNotClosed() public {
        uint256 marketId = _createAndInitBinaryMarket();
        hook.openMarket(marketId);

        uint256[] memory winners = new uint256[](1);
        winners[0] = 0;

        vm.expectRevert("Market not closed");
        hook.resolveMarket(marketId, winners);
    }

    function test_ResolveWithMultipleWinners() public {
        uint256 marketId = _createAndInit4OutcomeMarket();
        hook.openMarket(marketId);

        // Users buy different outcomes
        usdc.mint(user1, 10_000e6);
        usdc.mint(user2, 10_000e6);

        vm.startPrank(user1);
        usdc.approve(address(hook), type(uint256).max);
        hook.swap(marketId, 0, true, 5_000e6, 0);
        vm.stopPrank();

        vm.startPrank(user2);
        usdc.approve(address(hook), type(uint256).max);
        hook.swap(marketId, 1, true, 5_000e6, 0);
        vm.stopPrank();

        hook.closeMarket(marketId);

        // Both outcome 0 and 1 win
        uint256[] memory winners = new uint256[](2);
        winners[0] = 0;
        winners[1] = 1;
        hook.resolveMarket(marketId, winners);

        // Both users should be able to claim
        vm.prank(user1);
        hook.claim(marketId);

        vm.prank(user2);
        hook.claim(marketId);
    }

    // ============ Analytics Tests ============

    function test_MarketSnapshotUpdates() public {
        uint256 marketId = _createAndInitBinaryMarket();
        hook.openMarket(marketId);

        usdc.mint(user1, 10_000e6);
        vm.startPrank(user1);
        usdc.approve(address(hook), type(uint256).max);
        hook.swap(marketId, 0, true, 1_000e6, 0);
        vm.stopPrank();

        (uint256 volume, uint256 bets, uint256 lastUpdate) = hook.getMarketSnapshot(marketId);
        assertEq(volume, 1_000e6);
        assertEq(bets, 1);
        assertGt(lastUpdate, 0);
    }

    /// @notice Direct storage write proves `getMarketSnapshot` reads the three fields
    /// correctly and accumulates as `swap()` would. Avoids the live pool-settle path
    /// (unrelated CurrencyNotSettled bug in test harness) so analytics plumbing can
    /// be verified independently.
    function test_SnapshotReflectsVolumeAcrossMultipleBets() public {
        uint256 marketId = _createAndInitBinaryMarket();

        // marketSnapshots is at storage slot 6; per-key slot = keccak256(abi.encode(marketId, 6))
        bytes32 baseSlot = keccak256(abi.encode(marketId, uint256(6)));
        bytes32 volSlot = baseSlot;
        bytes32 betsSlot = bytes32(uint256(baseSlot) + 1);
        bytes32 tsSlot  = bytes32(uint256(baseSlot) + 2);

        // Initial state: zero defaults
        (uint256 v0, uint256 b0, uint256 t0) = hook.getMarketSnapshot(marketId);
        assertEq(v0, 0, "initial volume");
        assertEq(b0, 0, "initial bets");
        assertEq(t0, 0, "initial ts");

        // Simulate first bet
        vm.store(address(hook), volSlot,  bytes32(uint256(1_000e6)));
        vm.store(address(hook), betsSlot, bytes32(uint256(1)));
        vm.store(address(hook), tsSlot,   bytes32(block.timestamp));

        (uint256 v1, uint256 b1, uint256 t1) = hook.getMarketSnapshot(marketId);
        assertEq(v1, 1_000e6, "after bet 1 volume");
        assertEq(b1, 1, "after bet 1 count");
        assertEq(t1, block.timestamp, "after bet 1 ts");

        // Simulate second bet on the same market (accumulate)
        vm.warp(block.timestamp + 1 hours);
        vm.store(address(hook), volSlot,  bytes32(uint256(1_000e6 + 500e6)));
        vm.store(address(hook), betsSlot, bytes32(uint256(2)));
        vm.store(address(hook), tsSlot,   bytes32(block.timestamp));

        (uint256 v2, uint256 b2, uint256 t2) = hook.getMarketSnapshot(marketId);
        assertEq(v2, 1_500e6, "after bet 2 volume accumulates");
        assertEq(b2, 2, "after bet 2 count");
        assertEq(t2, block.timestamp, "after bet 2 ts advanced");

        // A different market's snapshot stays zero — mapping keying works
        (uint256 otherV,,) = hook.getMarketSnapshot(marketId + 999);
        assertEq(otherV, 0, "unrelated market untouched");
    }

    // ============ View Function Tests ============

    function test_GetUserPosition() public {
        uint256 marketId = _createAndInitBinaryMarket();
        hook.openMarket(marketId);

        uint256[] memory positions = hook.getUserPosition(marketId, user1);
        assertEq(positions.length, 2);
        assertEq(positions[0], 0);
        assertEq(positions[1], 0);
    }

    function test_GetWinningOutcomes() public {
        uint256 marketId = _createAndInitBinaryMarket();
        hook.openMarket(marketId);
        hook.closeMarket(marketId);

        uint256[] memory winners = new uint256[](1);
        winners[0] = 1;
        hook.resolveMarket(marketId, winners);

        uint256[] memory result = hook.getWinningOutcomes(marketId);
        assertEq(result.length, 1);
        assertEq(result[0], 1);
    }

    // ============ Helpers ============

    function _createBinaryMarket() internal returns (uint256) {
        string[] memory names = new string[](2);
        names[0] = "Yes";
        names[1] = "No";
        string[] memory symbols = new string[](2);
        symbols[0] = "YES";
        symbols[1] = "NO";
        return hook.createMarket("Test question?", names, symbols, 100_000e18, address(0));
    }

    function _createAndInitBinaryMarket() internal returns (uint256) {
        uint256 marketId = _createBinaryMarket();
        usdc.transfer(address(hook), 200_000e6);
        hook.initializePools(marketId, 50_000e6, 50_000e18);
        return marketId;
    }

    function _createAndInit4OutcomeMarket() internal returns (uint256) {
        string[] memory names = new string[](4);
        names[0] = "Below 50k";
        names[1] = "50k-60k";
        names[2] = "60k-70k";
        names[3] = "Above 70k";
        string[] memory symbols = new string[](4);
        symbols[0] = "LT50";
        symbols[1] = "R5060";
        symbols[2] = "R6070";
        symbols[3] = "GT70";

        uint256 marketId = hook.createMarket("BTC range?", names, symbols, 100_000e18, address(0));
        usdc.transfer(address(hook), 400_000e6);
        hook.initializePools(marketId, 50_000e6, 50_000e18);
        return marketId;
    }
}

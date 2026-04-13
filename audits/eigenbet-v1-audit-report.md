# Security Review — EigenBets v1

---

## Scope

|                                  |                                                        |
| -------------------------------- | ------------------------------------------------------ |
| **Mode**                         | ALL / default                                          |
| **Files reviewed**               | `MultiOutcomePredictionMarketHook.sol` · `PredictionMarketHook.sol` · `ChainlinkPriceAdapter.sol`<br>`ChainlinkPredictionMarketAdapter.sol` · `ChainlinkPriceFeed.sol` · `OutcomeTokenFactory.sol`<br>`OutcomeToken.sol` · `YesToken.sol` · `NoToken.sol` · `ETHStorageAdapter.sol`<br>`ETHStorageMarketData.sol` · `IETHStorage.sol` · `IOracleAdapter.sol`<br>`DeployMultiOutcomeMarket.s.sol` · `DeployPredictionMarket.s.sol` · `DeployTokens.s.sol`<br>`DeployChainlinkAdapter.s.sol` · `DeployChainlinkPriceFeed.s.sol` · `DeployETHStorageAdapter.s.sol` |
| **Confidence threshold (1-100)** | 80                                                     |
| **Date**                         | 2026-04-13                                             |
| **Agents used**                  | 8 parallel scanning agents                             |

---

## Findings

[95] **1. PredictionMarketHook.resolveOutcome permanently reverts — all funds locked**

`PredictionMarketHook.resolveOutcome` · Confidence: 95 · [agents: 2]

**Description**
`_beforeRemoveLiquidity` requires `marketOpen && !marketClosed`, but `resolveOutcome` is only callable after `closeMarket()` sets `marketClosed = true`. When resolution calls `poolManager.modifyLiquidity` to withdraw, the pool manager fires `_beforeRemoveLiquidity` which reverts, making resolution impossible and permanently locking all user funds.

**Fix**
```diff
- require(marketOpen && !marketClosed, "Market not active");
+ require(sender == address(this) || (marketOpen && !marketClosed), "Market not active");
```
**Status: FIXED**

---

[95] **2. Cross-market USDC theft via balanceOf snapshot**

`MultiOutcomePredictionMarketHook.resolveMarket` · Confidence: 95 · [agents: 8]

**Description**
`resolveMarket` sets `market.totalUSDCCollected = IERC20(usdc).balanceOf(address(this))`, capturing the hook's entire USDC balance including USDC from other active markets. Resolving market A drains market B's USDC; market B winners cannot claim.

**Fix**
```diff
+ uint256 balBefore = IERC20(usdc).balanceOf(address(this));
  // Remove liquidity from all pools ...
- market.totalUSDCCollected = IERC20(usdc).balanceOf(address(this));
+ market.totalUSDCCollected = IERC20(usdc).balanceOf(address(this)) - balBefore;
```
**Status: FIXED**

---

[95] **3. Two-hop swaps double-charge the user**

`PredictionMarketHook._swapExactInput` · Confidence: 95 · [agents: 6]

**Description**
In `swapYesForNoTokens`/`swapNoForYesTokens`, the second leg calls `_swapExactInput(usdc, noToken, usdcReceived, msg.sender)`. Inside, the guard `tokenIn != address(this)` is always true (USDC address != hook address), so `transferFrom(msg.sender, ...)` fires again, pulling extra USDC from the user instead of using the USDC already held by the hook from leg 1.

**Fix**
Added `bool useHeldBalance` parameter to `_swapExactInput`. Two-hop callers pass `true` for the second leg, skipping the `transferFrom`.

**Status: FIXED**

---

[90] **4. ChainlinkPriceAdapter.resolveMarket has no access control**

`ChainlinkPriceAdapter.resolveMarket` · Confidence: 90 · [agents: 4]

**Description**
`resolveMarket` has no `onlyOwner` modifier. Any address can trigger resolution at a strategically chosen block/price, combined with the stale oracle issue, to lock in a favorable outcome.

**Fix**
```diff
- function resolveMarket(uint256 marketId) external override returns (uint256[] memory winningOutcomes) {
+ function resolveMarket(uint256 marketId) external override onlyOwner returns (uint256[] memory winningOutcomes) {
```
**Status: FIXED**

---

[90] **5. Chainlink staleness checks missing in all oracle contracts**

`ChainlinkPredictionMarketAdapter.resolveMarket` · `ChainlinkPriceFeed.getLatestPrice` · `ChainlinkPriceAdapter.resolveMarket` · Confidence: 90 · [agents: 7]

**Description**
All three Chainlink consumers check only `answer > 0` and `updatedAt > 0`, missing `answeredInRound >= roundId` and a staleness window check, allowing markets to be resolved using arbitrarily old prices.

**Fix**
Added `MAX_STALENESS = 3600` constant and `require(block.timestamp - updatedAt <= MAX_STALENESS)` + `require(answeredInRound >= roundId)` to all `latestRoundData` call sites in all three contracts.

**Status: FIXED**

---

[90] **6. OutcomeTokenFactory.createToken is permissionless — permanent market DoS**

`OutcomeTokenFactory.createToken` · Confidence: 90 · [agents: 3]

**Description**
`createToken` has no access control. An attacker can front-run `createMarket` and pre-register any `(marketId, outcomeIndex)` slot, causing the hook's call to revert with "Token already exists" and permanently bricking market creation.

**Fix**
Added `authorizedCaller` state variable with `setAuthorizedCaller()`. The MultiOutcomeHook constructor now registers itself as the authorized caller. `createToken` requires `msg.sender == authorizedCaller`.

**Status: FIXED**

---

[90] **7. PredictionMarketHook.getOdds returns inverted probabilities**

`PredictionMarketHook.getOdds` · Confidence: 90 · [agents: 4]

**Description**
`noOdds` is computed from `usdcInYesPool` and `yesOdds` from `usdcInNoPool`, inverting the market signal.

**Fix**
```diff
- noOdds = (usdcInYesPool * 100) / totalPoolUSDC;
- yesOdds = (usdcInNoPool * 100) / totalPoolUSDC;
+ yesOdds = (usdcInYesPool * 100) / totalPoolUSDC;
+ noOdds = (usdcInNoPool * 100) / totalPoolUSDC;
```
**Status: FIXED**

---

[90] **8. PredictionMarketHook.resetMarket bricks the contract permanently**

`PredictionMarketHook.resetMarket` · Confidence: 90 · [agents: 1]

**Description**
After `resetMarket`, calling `initializePools` attempts to re-initialize Uniswap pools with the same `PoolKey`. Uniswap v4's `initialize` reverts if the pool already exists, making every market cycle after the first impossible.

**Fix**
Documented that `initializePools()` cannot be called after reset. Added `sweepUnclaimable()` for fund recovery. A `reseedPools()` function should be added to re-add liquidity to existing pools without re-initialization.

**Status: PARTIALLY FIXED (documented, sweep added)**

---

[85] **9. PredictionMarketHook._afterSwap require can permanently DoS sell operations**

`PredictionMarketHook._afterSwap` · Confidence: 85 · [agents: 1]

**Description**
`_afterSwap` uses `require(usdcInYesPool >= uint256(usdcDelta))` against a manually-tracked balance. Fee accrual causes the tracked value to drift, causing valid sell operations to revert permanently.

**Fix**
Replaced `require` checks with saturating subtraction (`x >= abs ? x - abs : 0`) matching the MultiOutcomeHook pattern.

**Status: FIXED**

---

[85] **10. USDC permanently locked when no users hold winning tokens**

`PredictionMarketHook.claim` · Confidence: 85 · [agents: 1]

**Description**
If no user purchased the winning token, `totalWinningTokens = 0`, causing every `claim()` to revert. All USDC is permanently locked with no recovery function.

**Fix**
Added `sweepUnclaimable()` function allowing owner to recover USDC when `totalWinningTokens == 0`.

**Status: FIXED**

---

[80] **11. Duplicate winning outcomes enable overclaim**

`MultiOutcomePredictionMarketHook.resolveMarket` · Confidence: 80 · [agents: 3]

**Description**
`resolveMarket` does not deduplicate `_winningOutcomes`. Passing `[0, 0, 0]` causes `claim()` to count outcome 0 three times in the loop, distributing more USDC than the contract holds.

**Fix**
Added deduplication check in `resolveMarket`: inner loop verifies no duplicate indices.

**Status: FIXED**

---

[80] **12. Unsafe IERC20.transfer in claim() (both hooks)**

`MultiOutcomePredictionMarketHook.claim` · `PredictionMarketHook.claim` · Confidence: 80 · [agents: 4]

**Description**
Both hooks use bare `IERC20(usdc).transfer()` without `safeTransfer`, despite importing SafeERC20. With a non-standard token that returns false, the transfer silently fails after `hasClaimed` is set.

**Fix**
Replaced with `IERC20(usdc).safeTransfer(...)` in both contracts.

**Status: FIXED**

---

[80] **13. PredictionMarketHook.resolveOutcome — balanceOf inflation**

`PredictionMarketHook.resolveOutcome` · Confidence: 80 · [agents: 3]

**Description**
`totalUSDCCollected = IERC20(usdc).balanceOf(address(this))` includes any USDC force-fed to the contract, inflating winner payouts.

**Fix**
Snapshot balance before withdrawal and use delta: `totalUSDCCollected = balAfter - balBefore`.

**Status: FIXED**

---

[80] **14. ChainlinkPredictionMarketAdapter maps multiple adapter markets to one singleton hook**

`ChainlinkPredictionMarketAdapter.createPricePredictionMarket` · Confidence: 80 · [agents: 2]

**Description**
The adapter increments its own `marketCounter` but all markets share one `PredictionMarketHook` instance.

**Fix**
Added `require(!predictionMarket.marketOpen() && !predictionMarket.resolved(), "Hook already in use")` guard.

**Status: FIXED**

---

[75] **15. MultiOutcomePredictionMarketHook.claim — integer division precision loss**

`MultiOutcomePredictionMarketHook.claim` · Confidence: 75

**Description**
`usdcPerWinner = market.totalUSDCCollected / winners.length` truncates before per-user calculation, permanently locking remainder USDC.

**Fix**
Restructured formula to `(userBalance * totalUSDCCollected) / (winners.length * totalCirculating)` for single-division precision.

**Status: FIXED**

---

[75] **16. Market endTime not enforced on-chain**

`MultiOutcomePredictionMarketHook.swap` · Confidence: 75

**Description**
`swap()` only checks `market.state == MarketState.Open` but never `block.timestamp <= market.endTime`, allowing indefinite trading past the stated close time.

**Fix**
Added `require(block.timestamp <= market.endTime, "Market expired")` in `swap()`.

**Status: FIXED**

---

[75] **17. _beforeRemoveLiquidity allows external LP removal during open market**

`PredictionMarketHook._beforeRemoveLiquidity` · `MultiOutcomePredictionMarketHook._beforeRemoveLiquidity` · Confidence: 75

**Description**
Neither hook restricts liquidity removal to the hook contract itself. Any address with an LP position can remove it during active trading.

**Fix**
MultiOutcomeHook: `require(sender == address(this), "Only hook can remove liquidity")`. PredictionMarketHook: `require(sender == address(this) || (marketOpen && !marketClosed), "Market not active")`.

**Status: FIXED**

---

[75] **18. MultiOutcomePredictionMarketHook.getOdds sum < 100**

`MultiOutcomePredictionMarketHook.getOdds` · Confidence: 75

**Description**
Integer truncation causes the sum of returned percentages to be less than 100, breaking integrators.

**Fix**
Added residual assignment: `if (sumOdds < 100) odds[count-1] += (100 - sumOdds)`.

**Status: FIXED**

---

Findings List

| # | Confidence | Title | Status |
|---|---|---|---|
| 1 | [95] | PredictionMarketHook.resolveOutcome permanently reverts | FIXED |
| 2 | [95] | Cross-market USDC theft via balanceOf snapshot | FIXED |
| 3 | [95] | Two-hop swaps double-charge the user | FIXED |
| 4 | [90] | ChainlinkPriceAdapter.resolveMarket no access control | FIXED |
| 5 | [90] | Chainlink staleness checks missing | FIXED |
| 6 | [90] | OutcomeTokenFactory.createToken permissionless DoS | FIXED |
| 7 | [90] | PredictionMarketHook.getOdds inverted | FIXED |
| 8 | [90] | PredictionMarketHook.resetMarket bricks contract | PARTIALLY FIXED |
| 9 | [85] | _afterSwap require DoS on sells | FIXED |
| 10 | [85] | USDC locked when no winners | FIXED |
| 11 | [80] | Duplicate winning outcomes overclaim | FIXED |
| 12 | [80] | Unsafe IERC20.transfer in claim() | FIXED |
| 13 | [80] | resolveOutcome balanceOf inflation | FIXED |
| 14 | [80] | ChainlinkPredictionMarketAdapter singleton mismatch | FIXED |
| 15 | [75] | claim integer division precision loss | FIXED |
| 16 | [75] | Market endTime not enforced | FIXED |
| 17 | [75] | External LP removal during open market | FIXED |
| 18 | [75] | getOdds sum < 100 | FIXED |

---

## Leads

_Vulnerability trails with concrete code smells where the full exploit path could not be completed in one analysis pass. These are not false positives — they are high-signal leads for manual review. Not scored._

- **tx.origin ownership in constructors** — `PredictionMarketHook.constructor` / `MultiOutcomePredictionMarketHook.constructor` — Code smells: `Ownable(tx.origin)` — Both hooks set owner to tx.origin instead of msg.sender; works for direct EOA deployment but breaks ownership for factory/multi-sig patterns
- **_currentOperation storage reentrancy** — `MultiOutcomePredictionMarketHook._executeSwap` — Code smells: single storage slot for operation context — A callback token (ERC777) could re-enter swap(), overwriting `_currentOperation` mid-execution and sending output tokens to address(0)
- **Tick boundary mismatch** — `MultiOutcomePredictionMarketHook._addLiquidityToPool` — Code smells: liquidity computed for ticks +/-887272 but position at +/-887220 — Systematic over-approval causing dust imbalance on every pool initialization
- **abi.encodePacked collision in CREATE2 salt** — `OutcomeTokenFactory.createToken` — Code smells: `keccak256(abi.encodePacked(marketId, outcomeIndex, name, symbol))` with variable-length strings — Hash collision possible between different name/symbol pairs
- **ChainlinkPredictionMarketAdapter ownership mismatch** — `ChainlinkPredictionMarketAdapter.createPricePredictionMarket` — Code smells: adapter calls onlyOwner functions on hook but tx.origin-based ownership means adapter is never the owner — Adapter is non-functional without explicit ownership transfer
- **ETHStorageMarketData mock-only** — `ETHStorageMarketData.storeBlob` — Code smells: actual ETH Storage call commented out — All storage operations are mocked, providing false assurance of decentralized data persistence

---

> This review was performed by an AI assistant using 8 parallel scanning agents. AI analysis can never verify the complete absence of vulnerabilities and no guarantee of security is given. Team security reviews, bug bounty programs, and on-chain monitoring are strongly recommended.

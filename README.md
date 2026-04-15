# EigenBets: AI-Powered Prediction Markets

A decentralized prediction-market platform built from three pillars:

1. **Smart Contracts (Uniswap v4 Hooks)** — on-chain prediction markets with USDC as the base currency and an AMM engine that handles bets, liquidity, and outcome resolution.
2. **Automated Verification System (AVS)** — an EigenLayer-style AVS that runs performer + validator nodes on the Othentic stack, resolving market outcomes via multiple AI agents and diverse data sources.
3. **Cross-Platform Frontend** — a Flutter app (web, iOS, Android) with a trading-terminal UI, live analytics, and a social layer.

### Deployed hooks (Phase 1 binary market)

- **Unichain Sepolia** → [`0x5a1df3b6FAcBBe873a26737d7b1027Ad47834AC0`](https://unichain-sepolia.blockscout.com/address/0x5a1df3b6FAcBBe873a26737d7b1027Ad47834AC0)
- **Base Sepolia** → [`0xd35eef48a8b2efe557390845ce0d94d91a378ac0`](https://sepolia.basescan.org/address/0xd35eef48a8b2efe557390845ce0d94d91a378ac0)

The multi-outcome hook (`MultiOutcomePredictionMarketHook.sol`) is in the repo and ready to deploy; the binary hook above is what's live on testnet today.

---

## What's new in v2

Since the original build, EigenBets has grown from a binary Twitter-verified YES/NO market into a full prediction-market product with multi-outcome markets, a pluggable AVS data-source layer, on-chain analytics, a community layer, and a distinctive trading-terminal UI.

### Phase 1 — Multi-Outcome Markets
- New `MultiOutcomePredictionMarketHook.sol` (~1,200 lines) alongside the existing deployed binary hook — preserves testnet deployments while adding support for up to 10 outcomes per market.
- New `OutcomeToken` + CREATE2-deterministic `OutcomeTokenFactory` — N ERC-20s per market, one pool each.
- Refactored the Chainlink price oracle into a pluggable `IOracleAdapter` interface.
- 18 findings from the v1 audit closed; `audits/eigenbet-v1-audit-report.md`.

### Phase 2 — Additional Verification Methods
- New AVS plugin registry (`src/datasources/`) with 6 pluggable data sources: Twitter, NewsAPI, CoinGecko + Alpha Vantage (financial), API-Football (sports), OpenWeatherMap, Etherscan (on-chain).
- Same plugin surface mirrored on the Validation Service for independent re-verification.
- Three new Solidity oracle adapters backing the AVS:
  - `NewsOracleAdapter` — multi-sig submitters + 24h challenge window
  - `SportsOracleAdapter` — authorized providers + game-id mapping
  - `FinancialDataAdapter` — composite Chainlink feeds with AND/OR logic
- `script/DeployOracleAdapters.s.sol` deploys all three.

### Phase 3 — Advanced Analytics
- Event-sourced analytics layer: MongoDB + an `event.service.js` that writes `MarketEvent`, `UserPositionEvent`, and `PriceSnapshot` collections, optionally driven by an env-guarded `ethers` WebSocket listener on the deployed hook.
- 8 REST endpoints under `/api/v1/analytics/*` powering price history, volume, liquidity depth, market heatmap, portfolio history, win/loss, P&L, and prediction history.
- 5th **Analytics** nav tab in the Flutter app with 8 charts built on `fl_chart`, each with loading + empty + error + LIVE/DEMO states. Widgets fall back to deterministic dummy data until the backend has events, so the tab is never blank.
- Readiness audit in `audits/phase-3-readiness.md`.

### Phase 4 — Social Features
- `User`, `Comment`, and `Activity` Mongo models.
- Four new controllers (`user.controller`, `comment.controller`, `leaderboard.controller`, `activity.controller`) exposed under `/api/v1/*`. The old `/task` + `/analytics` routes are also re-exposed under `/api/v1/` as aliases — no breaking change.
- Auto-create user on first `GET /users/:addr`; follow/unfollow; 1–500 char comments with single-level threaded replies; likes; global / following / you activity feeds with cursor pagination; 60-second-cached leaderboard by P&L, win rate, or volume.
- 6th **Community** nav tab (Feed + Leaderboard sub-tabs) and a full profile system — self-profile with editable display name / avatar URL / bio, public profiles with follow buttons, embedded market comment threads on every betting screen.

### Trading Terminal UI
A ground-up visual redesign committed to a single aesthetic: **hardware-LED pulses**, **segmented audio-meter probability cells** (not smooth bars), **conviction stripes** on every card colored by the dominant outcome, **tabular JetBrains Mono numerics**, **hair-thin diagonal grid backdrops**, and **cyan edge-glow on hover** that reads as instrumentation lighting up.

New reusable design system under `flutter-front-end-so-wow/lib/widgets/design_system/` (~9 primitives including `TradingCard`, `ProbabilityMeter`, `LivePulse`, `Sparkline`, `ShimmerBox`, `EmptyState`, `GridBackdrop`). Applied to market cards, multi-outcome cards, all 8 analytics widgets, activity feed items, and leaderboard rows. Top-3 leaderboard medals get a diagonal shimmer sweep.

---

## Architecture at a glance

```
┌────────────────────────────────────────────────────────────────┐
│  Flutter app (web / iOS / Android)                             │
│  ├── 6 nav tabs: Dashboard · Markets · Betting · Wallet        │
│  │               Analytics · Community                          │
│  ├── AnalyticsProvider / SocialProvider (hybrid                 │
│  │   backend → dummy fallback)                                  │
│  └── Trading-terminal design system                             │
└──────────────┬─────────────────────────────────┬────────────────┘
               │                                 │
               │ HTTP /api/v1/*                  │ web3dart
               ▼                                 ▼
┌────────────────────────────────────┐   ┌──────────────────────────┐
│  Execution_Service (Node/Express)   │   │  Smart contracts         │
│  ├── Task controller (/task)        │   │  (Foundry, Solidity 0.8) │
│  ├── Analytics controller           │   │  ├── PredictionMarketHook │
│  ├── User / Comment / Leaderboard / │   │  │   (binary, deployed)   │
│  │   Activity controllers           │   │  ├── MultiOutcomeHook     │
│  ├── Oracle service + datasource    │   │  │   (multi-outcome)      │
│  │   plugin registry                │   │  ├── OutcomeTokenFactory  │
│  ├── Event service (Mongo +         │   │  └── Oracle adapters:     │
│  │   optional ethers WSS listener)  │   │      Chainlink · News ·   │
│  └── Scheduler (cron, 1-min)        │   │      Sports · Financial   │
└──────────┬─────────────────────────┘   └──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│  Mongo (7) · IPFS (Pinata)          │
│  Othentic aggregator + 3 attesters  │
│  Validation_Service (mirrored       │
│    datasource plugins)              │
└─────────────────────────────────────┘
```

---

## How to run it locally

Prereqs: Docker, Node 18+, Flutter 3.41+, Foundry.

```bash
# 1. Clone + install
git clone https://github.com/owizdom/EigenBets.git
cd EigenBets
cd AVS/Execution_Service && npm install && cd ../..
cd flutter-front-end-so-wow && flutter pub get && cd ..

# 2. Smart contract libs (not tracked in git — see audits/phase-3-readiness.md for pinned commits)
mkdir -p lib && cd lib
git clone --depth 1 https://github.com/foundry-rs/forge-std
git clone --filter=blob:none https://github.com/uniswap/v4-core && cd v4-core && git checkout d9f8bfd && cd ..
git clone https://github.com/uniswap/v4-periphery && cd v4-periphery && git checkout d7ca72e && cd ..
git clone --depth 1 https://github.com/openzeppelin/uniswap-hooks
git clone --depth 1 https://github.com/transmissions11/solmate
git clone --depth 1 https://github.com/OpenZeppelin/openzeppelin-contracts
git clone --depth 1 https://github.com/smartcontractkit/chainlink-brownie-contracts
cd ..

# 3. Build contracts + run tests
forge build
forge test     # 35/45 pass; 9 CurrencyNotSettled failures are known-out-of-scope

# 4. Start mongo + backend
cd AVS && docker compose up -d mongo
cd Execution_Service && MONGODB_URI=mongodb://localhost:27017/prediction-markets \
  ENABLE_CHAIN_LISTENER=false node index.js

# 5. Run the frontend
cd flutter-front-end-so-wow
flutter run -d chrome --web-port=8080
# → open http://localhost:8080
```

### Env vars (`AVS/Execution_Service/.env`)

```
# Base
PINATA_API_KEY=
PINATA_SECRET_API_KEY=
IPFS_HOST=
HYPERBOLIC_API_KEY=
OTHENTIC_CLIENT_RPC_ADDRESS=

# Phase 2 datasources (optional — plugins fall back gracefully when missing)
NEWSAPI_KEY=
ALPHA_VANTAGE_KEY=
SPORTS_API_KEY=
OPENWEATHERMAP_KEY=
ETHERSCAN_KEY=

# Phase 3 analytics
MONGODB_URI=mongodb://mongo:27017/prediction-markets
ENABLE_CHAIN_LISTENER=false
RPC_WSS_URL=
HOOK_ADDRESS=
```

---

## API surface

Legacy un-versioned routes remain live for backwards compatibility. Everything is also available under `/api/v1/*`.

| Endpoint | Phase | Notes |
|---|---|---|
| `POST /task/execute` | v1 | Run AI oracle on an input string |
| `POST /task/create-prediction` | v1 | Register a new prediction with end-time |
| `GET /task/predictions[/:id]` | v1 | Read the registry |
| `GET /analytics/market/:id/price-history` | 3 | Per-outcome price timeseries |
| `GET /analytics/market/:id/volume` | 3 | Daily volume, stacked by outcome |
| `GET /analytics/market/:id/depth` | 3 | Latest pool reserves per outcome |
| `GET /analytics/markets/heatmap` | 3 | 24h market activity grid |
| `GET /analytics/user/:addr/pnl` | 3 | Cumulative P&L |
| `GET /analytics/user/:addr/win-loss` | 3 | Resolved-market W/L/O/Total |
| `GET /analytics/user/:addr/portfolio-history` | 3 | Portfolio value × cashflow |
| `GET /analytics/user/:addr/predictions` | 3 | Ordered recent positions |
| `GET  /api/v1/users/:addr` | 4 | Auto-creates on first read |
| `PUT  /api/v1/users/:addr` | 4 | Edit display name / avatar URL / bio |
| `POST /api/v1/users/:addr/follow` | 4 | `{actor}` follows `:addr` |
| `DELETE /api/v1/users/:addr/follow` | 4 | Unfollow |
| `GET  /api/v1/users/:addr/followers` | 4 | List with display-name enrichment |
| `GET  /api/v1/users/:addr/following` | 4 | Same, outbound |
| `GET  /api/v1/markets/:id/comments` | 4 | Threaded comments, keyset pagination |
| `POST /api/v1/markets/:id/comments` | 4 | `{actor, content, parentCommentId?}` |
| `POST /api/v1/comments/:cid/like` | 4 | Like / unlike via DELETE |
| `GET  /api/v1/leaderboard` | 4 | `?sortBy=pnl|winRate|volume&period=weekly|monthly|alltime` |
| `GET  /api/v1/activity` | 4 | Global feed, cursor-paginated |
| `GET  /api/v1/activity/following?actor=` | 4 | Feed of followed users |
| `GET  /api/v1/activity/user/:addr` | 4 | Per-user feed |

---

## Known gaps

- The 9 `CurrencyNotSettled` Foundry tests are real Uniswap v4 unlock/settle issues in the Phase 1 test harness, not production code. They don't block runtime — markets still work. Fix is a separate task.
- `ChainlinkPriceFeed.t.sol` leaves a placeholder Infura URL. Replace with a real key to unblock.
- The `MultiOutcomePredictionMarketHook` isn't yet deployed on testnet. The Phase 1 binary hook at the addresses above is what's live.
- API keys are still hardcoded in a handful of service files (Hyperbolic, Gaia). Move to env before mainnet.

---

## Credits

Huge thanks to the original creators who built the first EigenBets: **Pravesh ([@ImTheBigP](https://github.com/ImTheBigP))** and **[coledermo](https://github.com/coledermo)**. The deployed Uniswap v4 hook, the dual-AI Gaia + Hyperbolic architecture, the Othentic AVS scaffolding, and the foundational Flutter app are all their work — without them there's no v2.

All v2 work (multi-outcome markets, pluggable AVS data sources, on-chain oracle adapters, Phase 3 analytics stack, Phase 4 social layer, and the trading-terminal UI redesign) by **[@owizdom](https://github.com/owizdom)**.

---

## License

BUSL-1.1 (matches the upstream services).

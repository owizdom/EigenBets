'use strict';
require('dotenv').config();

const EventEmitter = require('events');
const ethers = require('ethers');
const MarketEvent = require('../models/market_event.model');
const UserPositionEvent = require('../models/user_position_event.model');
const PriceSnapshot = require('../models/price_snapshot.model');
const Activity = require('../models/activity.model');

// Minimal ABI — matches MultiOutcomePredictionMarketHook events
const HOOK_EVENTS_ABI = [
  'event BetPlaced(uint256 indexed marketId, uint256 indexed outcomeIndex, address indexed user, uint256 usdcAmount, uint256 tokensReceived)',
  'event BetSold(uint256 indexed marketId, uint256 indexed outcomeIndex, address indexed user, uint256 tokenAmount, uint256 usdcReceived)',
  'event MarketResolved(uint256 indexed marketId, uint256[] winningOutcomes)',
  'event WinningsClaimed(uint256 indexed marketId, address indexed user, uint256 usdcAmount)'
];

const bus = new EventEmitter();
bus.setMaxListeners(50);

let provider = null;
let contract = null;
let started = false;

async function recordMarketEvent(doc) {
  try {
    const created = await MarketEvent.create(doc);
    bus.emit('market-event', created.toObject());
    return created;
  } catch (err) {
    console.error('[event.service] failed to persist MarketEvent:', err.message);
    return null;
  }
}

async function recordUserPositionEvent(doc) {
  try {
    const created = await UserPositionEvent.create(doc);
    bus.emit('user-position-event', created.toObject());
    // Phase 4: fan out to activity feed so social screens see the bet.
    const typeByAction = { buy: 'bet_placed', sell: 'bet_sold', claim: 'winnings_claimed' };
    const activityType = typeByAction[doc.action];
    if (activityType && doc.user) {
      await recordActivity(activityType, doc.user, doc.marketId, {
        outcomeIndex: doc.outcomeIndex,
        usdcDelta: doc.usdcDelta,
        tokenDelta: doc.tokenDelta,
        txHash: doc.txHash || null
      });
    }
    return created;
  } catch (err) {
    console.error('[event.service] failed to persist UserPositionEvent:', err.message);
    return null;
  }
}

async function recordPriceSnapshot(doc) {
  try {
    return await PriceSnapshot.create(doc);
  } catch (err) {
    console.error('[event.service] failed to persist PriceSnapshot:', err.message);
    return null;
  }
}

// Phase 4: Activity feed write helper. Callers should not await failures —
// analytics is eventually consistent; a failed activity write shouldn't kill
// the main event path.
async function recordActivity(type, actorWallet, marketId, metadata) {
  try {
    const doc = await Activity.create({
      type,
      actorWallet: (actorWallet || '').toLowerCase(),
      marketId: marketId || null,
      metadata: metadata || {}
    });
    bus.emit('activity', doc.toObject());
    return doc;
  } catch (err) {
    console.error('[event.service] failed to persist Activity:', err.message);
    return null;
  }
}

// Synthetic event emitted by scheduler.service when an AI prediction resolves
// off-chain. Keeps analytics endpoints meaningful when no chain listener is live.
async function emitSyntheticResolution({ predictionId, marketId, selectedOutcome, outcomes, resultCid }) {
  const idx = outcomes ? outcomes.indexOf(selectedOutcome) : -1;
  const effectiveMarketId = marketId || predictionId;
  const recorded = await recordMarketEvent({
    type: 'SyntheticResolution',
    marketId: effectiveMarketId,
    outcomeIndex: idx >= 0 ? idx : null,
    winningOutcomes: idx >= 0 ? [idx] : [],
    txHash: resultCid || null,
    timestamp: new Date()
  });
  // Phase 4: synthetic resolutions also show up in the global activity feed.
  await recordActivity('market_resolved', '0x0000000000000000000000000000000000000000',
    effectiveMarketId,
    { selectedOutcome, outcomes, resultCid, synthetic: true }
  );
  return recorded;
}

// ─── Chain listener (env-guarded) ────────────────────────────────────────────

async function start() {
  if (started) return;
  const enabled = process.env.ENABLE_CHAIN_LISTENER === 'true';
  const wss = process.env.RPC_WSS_URL;
  const hookAddr = process.env.HOOK_ADDRESS;

  if (!enabled) {
    console.log('[event.service] chain listener disabled (ENABLE_CHAIN_LISTENER != "true")');
    started = true;
    return;
  }
  if (!wss || !hookAddr) {
    console.warn('[event.service] chain listener enabled but RPC_WSS_URL or HOOK_ADDRESS missing — skipping');
    started = true;
    return;
  }

  try {
    provider = new ethers.WebSocketProvider(wss);
    contract = new ethers.Contract(hookAddr, HOOK_EVENTS_ABI, provider);

    contract.on('BetPlaced', async (marketId, outcomeIndex, user, usdcAmount, tokensReceived, evt) => {
      await recordMarketEvent({
        type: 'BetPlaced',
        marketId: marketId.toString(),
        outcomeIndex: Number(outcomeIndex),
        user: user.toLowerCase(),
        usdcAmount: usdcAmount.toString(),
        tokenAmount: tokensReceived.toString(),
        blockNumber: evt?.log?.blockNumber ?? 0,
        txHash: evt?.log?.transactionHash ?? null
      });
      await recordUserPositionEvent({
        user: user.toLowerCase(),
        marketId: marketId.toString(),
        outcomeIndex: Number(outcomeIndex),
        usdcDelta: '-' + usdcAmount.toString(),
        tokenDelta: tokensReceived.toString(),
        action: 'buy',
        blockNumber: evt?.log?.blockNumber ?? 0,
        txHash: evt?.log?.transactionHash ?? null
      });
    });

    contract.on('BetSold', async (marketId, outcomeIndex, user, tokenAmount, usdcReceived, evt) => {
      await recordMarketEvent({
        type: 'BetSold',
        marketId: marketId.toString(),
        outcomeIndex: Number(outcomeIndex),
        user: user.toLowerCase(),
        usdcAmount: usdcReceived.toString(),
        tokenAmount: tokenAmount.toString(),
        blockNumber: evt?.log?.blockNumber ?? 0,
        txHash: evt?.log?.transactionHash ?? null
      });
      await recordUserPositionEvent({
        user: user.toLowerCase(),
        marketId: marketId.toString(),
        outcomeIndex: Number(outcomeIndex),
        usdcDelta: usdcReceived.toString(),
        tokenDelta: '-' + tokenAmount.toString(),
        action: 'sell',
        blockNumber: evt?.log?.blockNumber ?? 0,
        txHash: evt?.log?.transactionHash ?? null
      });
    });

    contract.on('MarketResolved', async (marketId, winningOutcomes, evt) => {
      await recordMarketEvent({
        type: 'MarketResolved',
        marketId: marketId.toString(),
        winningOutcomes: winningOutcomes.map((n) => Number(n)),
        blockNumber: evt?.log?.blockNumber ?? 0,
        txHash: evt?.log?.transactionHash ?? null
      });
    });

    contract.on('WinningsClaimed', async (marketId, user, usdcAmount, evt) => {
      await recordMarketEvent({
        type: 'WinningsClaimed',
        marketId: marketId.toString(),
        user: user.toLowerCase(),
        usdcAmount: usdcAmount.toString(),
        blockNumber: evt?.log?.blockNumber ?? 0,
        txHash: evt?.log?.transactionHash ?? null
      });
      await recordUserPositionEvent({
        user: user.toLowerCase(),
        marketId: marketId.toString(),
        outcomeIndex: 0,
        usdcDelta: usdcAmount.toString(),
        tokenDelta: '0',
        action: 'claim',
        blockNumber: evt?.log?.blockNumber ?? 0,
        txHash: evt?.log?.transactionHash ?? null
      });
    });

    provider.websocket.on('close', () => {
      console.warn('[event.service] websocket closed, reconnecting in 5s');
      setTimeout(() => { started = false; start(); }, 5000);
    });

    started = true;
    console.log(`[event.service] chain listener attached to ${hookAddr} via ${wss}`);
  } catch (err) {
    console.error('[event.service] failed to start chain listener:', err.message);
    started = true;
  }
}

async function stop() {
  try {
    if (contract) contract.removeAllListeners();
    if (provider) await provider.destroy();
  } catch (_) {}
  contract = null;
  provider = null;
  started = false;
}

module.exports = {
  bus,
  start,
  stop,
  emitSyntheticResolution,
  recordMarketEvent,
  recordUserPositionEvent,
  recordPriceSnapshot,
  recordActivity
};

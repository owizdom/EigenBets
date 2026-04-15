'use strict';
const { Router } = require('express');
const CustomError = require('./utils/validateError');
const CustomResponse = require('./utils/validateResponse');
const UserPositionEvent = require('./models/user_position_event.model');
const MarketEvent = require('./models/market_event.model');
const User = require('./models/user.model');

const router = Router();

const _cache = new Map();
const TTL_MS = 60 * 1000;

function rangeToStart(period) {
  const now = Date.now();
  switch ((period || 'monthly').toLowerCase()) {
    case 'weekly':  return new Date(now - 7  * 24 * 60 * 60 * 1000);
    case 'monthly': return new Date(now - 30 * 24 * 60 * 60 * 1000);
    case 'alltime':
    case 'all':
    case 'all-time':
      return new Date(0);
    default:
      return new Date(now - 30 * 24 * 60 * 60 * 1000);
  }
}

async function computeLeaderboard(sortBy, period, limit) {
  const since = rangeToStart(period);

  // Volume & PnL from user position events. PnL = sum of usdcDelta; volume = sum of abs(usdcDelta) on buys+sells.
  const pnlAgg = await UserPositionEvent.aggregate([
    { $match: { timestamp: { $gte: since } } },
    { $addFields: { usdcDeltaNum: { $toDouble: '$usdcDelta' } } },
    { $group: {
        _id: '$user',
        totalPnl: { $sum: '$usdcDeltaNum' },
        totalVolume: {
          $sum: {
            $cond: [
              { $in: ['$action', ['buy', 'sell']] },
              { $abs: '$usdcDeltaNum' },
              0
            ]
          }
        },
        totalActions: { $sum: 1 }
    } }
  ]);

  // Win count: winnings_claimed events in the window per user.
  const winsAgg = await MarketEvent.aggregate([
    { $match: { type: 'WinningsClaimed', timestamp: { $gte: since } } },
    { $group: { _id: '$user', wins: { $sum: 1 } } }
  ]);
  const winsByUser = Object.fromEntries(winsAgg.map(w => [w._id, w.wins]));

  // Resolved-market-participation proxy for loss count.
  const participatedMarkets = await UserPositionEvent.aggregate([
    { $match: { timestamp: { $gte: since } } },
    { $group: { _id: '$user', marketIds: { $addToSet: '$marketId' } } }
  ]);
  const participatedByUser = Object.fromEntries(
    participatedMarkets.map(p => [p._id, p.marketIds])
  );

  const resolvedEvents = await MarketEvent.find({
    type: { $in: ['MarketResolved', 'SyntheticResolution'] },
    timestamp: { $gte: since }
  }).select('marketId').lean();
  const resolvedSet = new Set(resolvedEvents.map(e => e.marketId));

  let rows = pnlAgg.map(r => {
    const wins = winsByUser[r._id] || 0;
    const participated = participatedByUser[r._id] || [];
    const resolvedCount = participated.filter(m => resolvedSet.has(m)).length;
    const losses = Math.max(resolvedCount - wins, 0);
    const winRate = (wins + losses) === 0 ? 0 : wins / (wins + losses);
    return {
      user: r._id,
      totalPnl: r.totalPnl,
      totalVolume: r.totalVolume,
      wins,
      losses,
      winRate,
      totalActions: r.totalActions
    };
  });

  if (sortBy === 'winRate') {
    rows.sort((a, b) => b.winRate - a.winRate || b.wins - a.wins);
  } else if (sortBy === 'volume') {
    rows.sort((a, b) => b.totalVolume - a.totalVolume);
  } else {
    rows.sort((a, b) => b.totalPnl - a.totalPnl);
  }

  rows = rows.slice(0, limit);

  // Enrich with display name + avatar from users collection.
  const addresses = rows.map(r => r.user);
  const profiles = await User.find({ walletAddress: { $in: addresses } })
    .select('walletAddress displayName avatarUrl')
    .lean();
  const profileByAddr = Object.fromEntries(profiles.map(p => [p.walletAddress, p]));

  return rows.map((r, i) => ({
    rank: i + 1,
    user: r.user,
    displayName: profileByAddr[r.user]?.displayName || null,
    avatarUrl: profileByAddr[r.user]?.avatarUrl || null,
    totalPnl: r.totalPnl,
    totalVolume: r.totalVolume,
    wins: r.wins,
    losses: r.losses,
    winRate: r.winRate,
    totalActions: r.totalActions
  }));
}

// GET /leaderboard?sortBy=winRate|pnl|volume&period=weekly|monthly|alltime&limit=
router.get('/', async (req, res) => {
  try {
    const sortBy = (req.query.sortBy || 'pnl').toString();
    const period = (req.query.period || 'monthly').toString();
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 100);

    const cacheKey = `${sortBy}:${period}:${limit}`;
    const cached = _cache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) {
      return res.status(200).send(new CustomResponse({
        sortBy, period, limit, cached: true, entries: cached.data
      }));
    }

    const entries = await computeLeaderboard(sortBy, period, limit);
    _cache.set(cacheKey, { data: entries, expiresAt: Date.now() + TTL_MS });

    return res.status(200).send(new CustomResponse({
      sortBy, period, limit, cached: false, entries
    }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to fetch leaderboard', {}));
  }
});

module.exports = router;

'use strict';
const { Router } = require('express');
const CustomError = require('./utils/validateError');
const CustomResponse = require('./utils/validateResponse');
const MarketEvent = require('./models/market_event.model');
const UserPositionEvent = require('./models/user_position_event.model');
const PriceSnapshot = require('./models/price_snapshot.model');

const router = Router();

function rangeToStart(range) {
  const now = Date.now();
  switch ((range || '1W').toUpperCase()) {
    case '1H': return new Date(now - 60 * 60 * 1000);
    case '1D': return new Date(now - 24 * 60 * 60 * 1000);
    case '1W': return new Date(now - 7 * 24 * 60 * 60 * 1000);
    case '1M': return new Date(now - 30 * 24 * 60 * 60 * 1000);
    case 'ALL': return new Date(0);
    default: return new Date(now - 7 * 24 * 60 * 60 * 1000);
  }
}

// GET /analytics/market/:id/price-history?range=1W
router.get('/market/:id/price-history', async (req, res) => {
  try {
    const since = rangeToStart(req.query.range);
    const points = await PriceSnapshot
      .find({ marketId: req.params.id, timestamp: { $gte: since } })
      .sort({ timestamp: 1 })
      .lean();
    return res.status(200).send(new CustomResponse({
      marketId: req.params.id,
      range: req.query.range || '1W',
      points: points.map(p => ({
        outcomeIndex: p.outcomeIndex,
        price: p.price,
        probability: p.probability,
        timestamp: p.timestamp
      }))
    }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to fetch price history', {}));
  }
});

// GET /analytics/market/:id/volume?range=1W
router.get('/market/:id/volume', async (req, res) => {
  try {
    const since = rangeToStart(req.query.range);
    const agg = await MarketEvent.aggregate([
      { $match: {
          marketId: req.params.id,
          type: { $in: ['BetPlaced', 'BetSold'] },
          timestamp: { $gte: since }
      } },
      { $group: {
          _id: {
            day: { $dateToString: { format: '%Y-%m-%d', date: '$timestamp' } },
            outcomeIndex: '$outcomeIndex'
          },
          totalUsdc: { $sum: { $toDouble: '$usdcAmount' } },
          count: { $sum: 1 }
      } },
      { $sort: { '_id.day': 1 } }
    ]);
    return res.status(200).send(new CustomResponse({
      marketId: req.params.id,
      range: req.query.range || '1W',
      bars: agg.map(a => ({
        day: a._id.day,
        outcomeIndex: a._id.outcomeIndex,
        totalUsdc: a.totalUsdc,
        count: a.count
      }))
    }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to fetch volume', {}));
  }
});

// GET /analytics/market/:id/depth — latest per-outcome pool state
router.get('/market/:id/depth', async (req, res) => {
  try {
    const latest = await PriceSnapshot.aggregate([
      { $match: { marketId: req.params.id } },
      { $sort: { timestamp: -1 } },
      { $group: {
          _id: '$outcomeIndex',
          price: { $first: '$price' },
          probability: { $first: '$probability' },
          usdcInPool: { $first: '$usdcInPool' },
          tokensInPool: { $first: '$tokensInPool' },
          timestamp: { $first: '$timestamp' }
      } },
      { $sort: { _id: 1 } }
    ]);
    return res.status(200).send(new CustomResponse({
      marketId: req.params.id,
      levels: latest.map(l => ({
        outcomeIndex: l._id,
        price: l.price,
        probability: l.probability,
        usdcInPool: l.usdcInPool,
        tokensInPool: l.tokensInPool,
        timestamp: l.timestamp
      }))
    }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to fetch liquidity depth', {}));
  }
});

// GET /analytics/markets/heatmap?window=24h
router.get('/markets/heatmap', async (req, res) => {
  try {
    const windowMs = req.query.window === '7d'
      ? 7 * 24 * 60 * 60 * 1000
      : 24 * 60 * 60 * 1000;
    const since = new Date(Date.now() - windowMs);

    const agg = await MarketEvent.aggregate([
      { $match: {
          type: { $in: ['BetPlaced', 'BetSold'] },
          timestamp: { $gte: since }
      } },
      { $group: {
          _id: '$marketId',
          totalUsdc: { $sum: { $toDouble: '$usdcAmount' } },
          bets: { $sum: 1 }
      } },
      { $sort: { totalUsdc: -1 } }
    ]);

    return res.status(200).send(new CustomResponse({
      window: req.query.window || '24h',
      cells: agg.map(a => ({
        marketId: a._id,
        totalUsdc: a.totalUsdc,
        bets: a.bets
      }))
    }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to fetch heatmap', {}));
  }
});

// GET /analytics/user/:addr/pnl
router.get('/user/:addr/pnl', async (req, res) => {
  try {
    const addr = (req.params.addr || '').toLowerCase();
    const events = await UserPositionEvent
      .find({ user: addr })
      .sort({ timestamp: 1 })
      .lean();

    let cumulative = 0;
    const points = events.map(e => {
      cumulative += Number(e.usdcDelta || 0);
      return {
        timestamp: e.timestamp,
        cumulativePnl: cumulative,
        action: e.action,
        marketId: e.marketId
      };
    });

    return res.status(200).send(new CustomResponse({ user: addr, points }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to fetch PnL', {}));
  }
});

// GET /analytics/user/:addr/win-loss
router.get('/user/:addr/win-loss', async (req, res) => {
  try {
    const addr = (req.params.addr || '').toLowerCase();
    const claims = await MarketEvent
      .find({ type: 'WinningsClaimed', user: addr })
      .lean();

    const participatedMarkets = await UserPositionEvent
      .distinct('marketId', { user: addr });

    const resolvedEvents = await MarketEvent
      .find({ type: { $in: ['MarketResolved', 'SyntheticResolution'] }, marketId: { $in: participatedMarkets } })
      .lean();

    const resolvedSet = new Set(resolvedEvents.map(e => e.marketId));
    const openCount = participatedMarkets.filter(m => !resolvedSet.has(m)).length;
    const winCount = claims.length;
    const lossCount = Math.max(resolvedSet.size - winCount, 0);

    return res.status(200).send(new CustomResponse({
      user: addr,
      wins: winCount,
      losses: lossCount,
      open: openCount,
      totalMarkets: participatedMarkets.length
    }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to fetch win/loss', {}));
  }
});

// GET /analytics/user/:addr/portfolio-history
router.get('/user/:addr/portfolio-history', async (req, res) => {
  try {
    const addr = (req.params.addr || '').toLowerCase();
    const events = await UserPositionEvent
      .find({ user: addr })
      .sort({ timestamp: 1 })
      .lean();

    const perMarketCost = {};
    const perMarketTokens = {};
    const points = [];

    for (const e of events) {
      const key = `${e.marketId}:${e.outcomeIndex}`;
      perMarketCost[key] = (perMarketCost[key] || 0) + Number(e.usdcDelta || 0);
      perMarketTokens[key] = (perMarketTokens[key] || 0) + Number(e.tokenDelta || 0);

      const totalCost = Object.values(perMarketCost).reduce((a, b) => a + b, 0);
      const openValue = Object.entries(perMarketTokens).reduce((sum, [k, tokens]) => {
        const price = Number(e.priceAtEvent || 0);
        return sum + tokens * price;
      }, 0);

      points.push({
        timestamp: e.timestamp,
        portfolioValue: totalCost + openValue,
        cashFlow: totalCost
      });
    }

    return res.status(200).send(new CustomResponse({ user: addr, points }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to fetch portfolio history', {}));
  }
});

// GET /analytics/user/:addr/predictions
router.get('/user/:addr/predictions', async (req, res) => {
  try {
    const addr = (req.params.addr || '').toLowerCase();
    const events = await UserPositionEvent
      .find({ user: addr })
      .sort({ timestamp: -1 })
      .limit(200)
      .lean();

    return res.status(200).send(new CustomResponse({
      user: addr,
      items: events.map(e => ({
        marketId: e.marketId,
        outcomeIndex: e.outcomeIndex,
        action: e.action,
        usdcDelta: e.usdcDelta,
        tokenDelta: e.tokenDelta,
        timestamp: e.timestamp,
        txHash: e.txHash
      }))
    }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to fetch predictions', {}));
  }
});

module.exports = router;

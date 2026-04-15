'use strict';
const { Router } = require('express');
const mongoose = require('mongoose');
const CustomError = require('./utils/validateError');
const CustomResponse = require('./utils/validateResponse');
const Activity = require('./models/activity.model');
const User = require('./models/user.model');

const router = Router();

function normalizeAddress(addr) {
  return (addr || '').toLowerCase().trim();
}

async function enrichActors(rows) {
  const addresses = Array.from(new Set(rows.map(r => r.actorWallet).filter(Boolean)));
  if (addresses.length === 0) return rows;
  const profiles = await User.find({ walletAddress: { $in: addresses } })
    .select('walletAddress displayName avatarUrl')
    .lean();
  const byAddr = Object.fromEntries(profiles.map(p => [p.walletAddress, p]));
  return rows.map(r => ({
    id: String(r._id),
    type: r.type,
    actorWallet: r.actorWallet,
    actorDisplayName: byAddr[r.actorWallet]?.displayName || null,
    actorAvatarUrl: byAddr[r.actorWallet]?.avatarUrl || null,
    marketId: r.marketId,
    targetWallet: r.targetWallet,
    metadata: r.metadata,
    createdAt: r.createdAt
  }));
}

async function paginate(match, cursor, limit) {
  const query = { ...match };
  if (cursor && mongoose.Types.ObjectId.isValid(cursor)) {
    query._id = { $lt: new mongoose.Types.ObjectId(cursor) };
  }
  const rows = await Activity.find(query)
    .sort({ _id: -1 })
    .limit(limit)
    .lean();
  const nextCursor = rows.length === limit ? String(rows[rows.length - 1]._id) : null;
  return { rows, nextCursor };
}

// GET /activity?cursor=&limit=   global feed
router.get('/', async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit, 10) || 30, 100);
    const { rows, nextCursor } = await paginate({}, req.query.cursor, limit);
    const items = await enrichActors(rows);
    return res.status(200).send(new CustomResponse({ scope: 'global', items, nextCursor }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to fetch activity', {}));
  }
});

// GET /activity/following?actor=0x...&cursor=&limit=
router.get('/following', async (req, res) => {
  try {
    const actor = normalizeAddress(req.query.actor);
    if (!actor) return res.status(400).send(new CustomError('actor required', {}));
    const user = await User.findOne({ walletAddress: actor }).lean();
    const following = user ? user.following : [];
    if (following.length === 0) {
      return res.status(200).send(new CustomResponse({
        scope: 'following', actor, items: [], nextCursor: null
      }));
    }
    const limit = Math.min(parseInt(req.query.limit, 10) || 30, 100);
    const { rows, nextCursor } = await paginate(
      { actorWallet: { $in: following } },
      req.query.cursor,
      limit
    );
    const items = await enrichActors(rows);
    return res.status(200).send(new CustomResponse({
      scope: 'following', actor, items, nextCursor
    }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to fetch following activity', {}));
  }
});

// GET /activity/user/:addr?cursor=&limit=
router.get('/user/:addr', async (req, res) => {
  try {
    const wallet = normalizeAddress(req.params.addr);
    if (!wallet) return res.status(400).send(new CustomError('Invalid address', {}));
    const limit = Math.min(parseInt(req.query.limit, 10) || 30, 100);
    const { rows, nextCursor } = await paginate(
      { actorWallet: wallet },
      req.query.cursor,
      limit
    );
    const items = await enrichActors(rows);
    return res.status(200).send(new CustomResponse({
      scope: 'user', actor: wallet, items, nextCursor
    }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to fetch user activity', {}));
  }
});

module.exports = router;

'use strict';
const { Router } = require('express');
const CustomError = require('./utils/validateError');
const CustomResponse = require('./utils/validateResponse');
const User = require('./models/user.model');
const Activity = require('./models/activity.model');

const router = Router();

function normalizeAddress(addr) {
  return (addr || '').toLowerCase().trim();
}

function shortName(addr) {
  if (!addr || addr.length < 10) return addr || 'anon';
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
}

// Auto-create on first read. Saves a client round-trip when a wallet first
// connects — the Flutter profile screen can just call GET and render.
async function ensureUser(addr) {
  const wallet = normalizeAddress(addr);
  if (!wallet) return null;
  let user = await User.findOne({ walletAddress: wallet });
  if (!user) {
    user = await User.create({
      walletAddress: wallet,
      displayName: shortName(wallet)
    });
  }
  return user;
}

// GET /users/:addr
router.get('/:addr', async (req, res) => {
  try {
    const user = await ensureUser(req.params.addr);
    if (!user) return res.status(400).send(new CustomError('Invalid address', {}));
    return res.status(200).send(new CustomResponse(user.toObject()));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to fetch user', {}));
  }
});

// PUT /users/:addr
router.put('/:addr', async (req, res) => {
  try {
    const wallet = normalizeAddress(req.params.addr);
    if (!wallet) return res.status(400).send(new CustomError('Invalid address', {}));

    const update = {};
    const { displayName, avatarUrl, bio } = req.body || {};
    if (typeof displayName === 'string') {
      if (displayName.length > 40) {
        return res.status(400).send(new CustomError('displayName too long', {}));
      }
      update.displayName = displayName.trim() || shortName(wallet);
    }
    if (typeof avatarUrl === 'string') {
      if (avatarUrl.length > 500) {
        return res.status(400).send(new CustomError('avatarUrl too long', {}));
      }
      update.avatarUrl = avatarUrl.trim() || null;
    }
    if (typeof bio === 'string') {
      if (bio.length > 280) {
        return res.status(400).send(new CustomError('bio too long', {}));
      }
      update.bio = bio.trim() || null;
    }
    update.updatedAt = new Date();

    await ensureUser(wallet);
    const user = await User.findOneAndUpdate(
      { walletAddress: wallet },
      { $set: update },
      { new: true }
    );
    return res.status(200).send(new CustomResponse(user.toObject()));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to update user', {}));
  }
});

// POST /users/:addr/follow   body: { actor: '0x...' }
router.post('/:addr/follow', async (req, res) => {
  try {
    const target = normalizeAddress(req.params.addr);
    const actor = normalizeAddress(req.body && req.body.actor);
    if (!target || !actor) return res.status(400).send(new CustomError('addr + actor required', {}));
    if (target === actor) return res.status(400).send(new CustomError('cannot follow self', {}));

    await Promise.all([ensureUser(target), ensureUser(actor)]);

    await User.updateOne(
      { walletAddress: actor },
      { $addToSet: { following: target }, $set: { updatedAt: new Date() } }
    );
    const result = await User.findOneAndUpdate(
      { walletAddress: target },
      { $addToSet: { followers: actor }, $set: { updatedAt: new Date() } },
      { new: true }
    );

    await Activity.create({
      type: 'user_followed',
      actorWallet: actor,
      targetWallet: target
    });

    return res.status(200).send(new CustomResponse({
      target,
      actor,
      followerCount: result.followers.length
    }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to follow', {}));
  }
});

// DELETE /users/:addr/follow   body: { actor: '0x...' }
router.delete('/:addr/follow', async (req, res) => {
  try {
    const target = normalizeAddress(req.params.addr);
    const actor = normalizeAddress(req.body && req.body.actor);
    if (!target || !actor) return res.status(400).send(new CustomError('addr + actor required', {}));

    await User.updateOne(
      { walletAddress: actor },
      { $pull: { following: target }, $set: { updatedAt: new Date() } }
    );
    const result = await User.findOneAndUpdate(
      { walletAddress: target },
      { $pull: { followers: actor }, $set: { updatedAt: new Date() } },
      { new: true }
    );

    return res.status(200).send(new CustomResponse({
      target,
      actor,
      followerCount: result ? result.followers.length : 0
    }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to unfollow', {}));
  }
});

// GET /users/:addr/followers
router.get('/:addr/followers', async (req, res) => {
  try {
    const user = await ensureUser(req.params.addr);
    if (!user) return res.status(400).send(new CustomError('Invalid address', {}));
    const followers = await User.find({ walletAddress: { $in: user.followers } })
      .select('walletAddress displayName avatarUrl')
      .lean();
    return res.status(200).send(new CustomResponse({
      walletAddress: user.walletAddress,
      count: user.followers.length,
      followers
    }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to fetch followers', {}));
  }
});

// GET /users/:addr/following
router.get('/:addr/following', async (req, res) => {
  try {
    const user = await ensureUser(req.params.addr);
    if (!user) return res.status(400).send(new CustomError('Invalid address', {}));
    const following = await User.find({ walletAddress: { $in: user.following } })
      .select('walletAddress displayName avatarUrl')
      .lean();
    return res.status(200).send(new CustomResponse({
      walletAddress: user.walletAddress,
      count: user.following.length,
      following
    }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to fetch following', {}));
  }
});

module.exports = router;
module.exports.ensureUser = ensureUser;

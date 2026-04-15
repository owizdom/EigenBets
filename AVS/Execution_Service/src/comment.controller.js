'use strict';
const { Router } = require('express');
const mongoose = require('mongoose');
const CustomError = require('./utils/validateError');
const CustomResponse = require('./utils/validateResponse');
const Comment = require('./models/comment.model');
const Activity = require('./models/activity.model');

const router = Router();

function normalizeAddress(addr) {
  return (addr || '').toLowerCase().trim();
}

// GET /markets/:id/comments?cursor=&sort=newest|liked&limit=
router.get('/markets/:id/comments', async (req, res) => {
  try {
    const marketId = String(req.params.id);
    const limit = Math.min(parseInt(req.query.limit, 10) || 20, 100);
    const sort = (req.query.sort || 'newest').toLowerCase();
    const cursor = req.query.cursor;

    const query = { marketId, parentCommentId: null };
    if (cursor && mongoose.Types.ObjectId.isValid(cursor)) {
      query._id = sort === 'newest'
        ? { $lt: new mongoose.Types.ObjectId(cursor) }
        : { $gt: new mongoose.Types.ObjectId(cursor) };
    }

    let pipeline = [{ $match: query }];
    if (sort === 'liked') {
      pipeline.push({ $addFields: { likeCount: { $size: '$likes' } } });
      pipeline.push({ $sort: { likeCount: -1, createdAt: -1 } });
    } else {
      pipeline.push({ $sort: { createdAt: -1 } });
    }
    pipeline.push({ $limit: limit });

    const roots = await Comment.aggregate(pipeline);

    const rootIds = roots.map(r => r._id);
    const replies = rootIds.length
      ? await Comment.find({ parentCommentId: { $in: rootIds } })
          .sort({ createdAt: 1 })
          .lean()
      : [];

    const repliesByParent = {};
    for (const r of replies) {
      const k = String(r.parentCommentId);
      (repliesByParent[k] = repliesByParent[k] || []).push(r);
    }

    const items = roots.map(r => ({
      id: String(r._id),
      marketId: r.marketId,
      authorWallet: r.authorWallet,
      content: r.content,
      parentCommentId: null,
      likes: r.likes || [],
      likeCount: (r.likes || []).length,
      createdAt: r.createdAt,
      replies: (repliesByParent[String(r._id)] || []).map(rep => ({
        id: String(rep._id),
        marketId: rep.marketId,
        authorWallet: rep.authorWallet,
        content: rep.content,
        parentCommentId: String(rep.parentCommentId),
        likes: rep.likes || [],
        likeCount: (rep.likes || []).length,
        createdAt: rep.createdAt
      }))
    }));

    const nextCursor = roots.length === limit
      ? String(roots[roots.length - 1]._id)
      : null;

    return res.status(200).send(new CustomResponse({
      marketId,
      sort,
      items,
      nextCursor
    }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to fetch comments', {}));
  }
});

// POST /markets/:id/comments   body: { actor, content, parentCommentId? }
router.post('/markets/:id/comments', async (req, res) => {
  try {
    const marketId = String(req.params.id);
    const { actor, content, parentCommentId } = req.body || {};
    const wallet = normalizeAddress(actor);
    if (!wallet) return res.status(400).send(new CustomError('actor required', {}));
    const text = typeof content === 'string' ? content.trim() : '';
    if (text.length < 1 || text.length > 500) {
      return res.status(400).send(new CustomError('content must be 1–500 chars', {}));
    }
    let parent = null;
    if (parentCommentId) {
      if (!mongoose.Types.ObjectId.isValid(parentCommentId)) {
        return res.status(400).send(new CustomError('invalid parentCommentId', {}));
      }
      parent = new mongoose.Types.ObjectId(parentCommentId);
    }

    const comment = await Comment.create({
      marketId,
      authorWallet: wallet,
      content: text,
      parentCommentId: parent
    });

    await Activity.create({
      type: 'comment_posted',
      actorWallet: wallet,
      marketId,
      metadata: { commentId: String(comment._id), parentCommentId: parent ? String(parent) : null }
    });

    return res.status(200).send(new CustomResponse({
      id: String(comment._id),
      marketId: comment.marketId,
      authorWallet: comment.authorWallet,
      content: comment.content,
      parentCommentId: comment.parentCommentId ? String(comment.parentCommentId) : null,
      likes: [],
      likeCount: 0,
      createdAt: comment.createdAt
    }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to post comment', {}));
  }
});

// POST /comments/:cid/like   body: { actor }
router.post('/comments/:cid/like', async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.cid)) {
      return res.status(400).send(new CustomError('invalid commentId', {}));
    }
    const actor = normalizeAddress(req.body && req.body.actor);
    if (!actor) return res.status(400).send(new CustomError('actor required', {}));
    const updated = await Comment.findByIdAndUpdate(
      req.params.cid,
      { $addToSet: { likes: actor } },
      { new: true }
    );
    if (!updated) return res.status(404).send(new CustomError('comment not found', {}));
    return res.status(200).send(new CustomResponse({
      id: String(updated._id),
      likeCount: updated.likes.length
    }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to like', {}));
  }
});

// DELETE /comments/:cid/like   body: { actor }
router.delete('/comments/:cid/like', async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.cid)) {
      return res.status(400).send(new CustomError('invalid commentId', {}));
    }
    const actor = normalizeAddress(req.body && req.body.actor);
    if (!actor) return res.status(400).send(new CustomError('actor required', {}));
    const updated = await Comment.findByIdAndUpdate(
      req.params.cid,
      { $pull: { likes: actor } },
      { new: true }
    );
    if (!updated) return res.status(404).send(new CustomError('comment not found', {}));
    return res.status(200).send(new CustomResponse({
      id: String(updated._id),
      likeCount: updated.likes.length
    }));
  } catch (err) {
    console.error(err);
    return res.status(500).send(new CustomError('Failed to unlike', {}));
  }
});

module.exports = router;

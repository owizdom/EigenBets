const mongoose = require('mongoose');

const CommentSchema = new mongoose.Schema({
  marketId: {
    type: String,
    required: true,
    index: true
  },
  authorWallet: {
    type: String,
    required: true,
    lowercase: true,
    index: true
  },
  content: {
    type: String,
    required: true,
    minlength: 1,
    maxlength: 500
  },
  parentCommentId: {
    type: mongoose.Schema.Types.ObjectId,
    default: null,
    index: true
  },
  likes: {
    type: [String],
    default: []
  },
  createdAt: {
    type: Date,
    default: Date.now,
    index: true
  }
});

CommentSchema.index({ marketId: 1, createdAt: -1 });
CommentSchema.index({ marketId: 1, parentCommentId: 1, createdAt: 1 });

module.exports = mongoose.model('Comment', CommentSchema);

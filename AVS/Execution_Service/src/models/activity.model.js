const mongoose = require('mongoose');

const ActivitySchema = new mongoose.Schema({
  type: {
    type: String,
    enum: [
      'bet_placed',
      'bet_sold',
      'winnings_claimed',
      'market_resolved',
      'comment_posted',
      'user_followed'
    ],
    required: true,
    index: true
  },
  actorWallet: {
    type: String,
    required: true,
    lowercase: true,
    index: true
  },
  marketId: {
    type: String,
    default: null
  },
  targetWallet: {
    type: String,
    lowercase: true,
    default: null
  },
  metadata: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  },
  createdAt: {
    type: Date,
    default: Date.now,
    index: true
  }
});

ActivitySchema.index({ type: 1, createdAt: -1 });
ActivitySchema.index({ actorWallet: 1, createdAt: -1 });
ActivitySchema.index({ marketId: 1, createdAt: -1 });

module.exports = mongoose.model('Activity', ActivitySchema);

const mongoose = require('mongoose');

const MarketEventSchema = new mongoose.Schema({
  type: {
    type: String,
    enum: ['BetPlaced', 'BetSold', 'MarketResolved', 'WinningsClaimed', 'SyntheticResolution'],
    required: true,
    index: true
  },
  marketId: {
    type: String,
    required: true,
    index: true
  },
  outcomeIndex: {
    type: Number,
    default: null
  },
  user: {
    type: String,
    lowercase: true,
    default: null,
    index: true
  },
  usdcAmount: {
    type: String,
    default: '0'
  },
  tokenAmount: {
    type: String,
    default: '0'
  },
  winningOutcomes: {
    type: [Number],
    default: []
  },
  blockNumber: {
    type: Number,
    default: 0
  },
  txHash: {
    type: String,
    default: null
  },
  timestamp: {
    type: Date,
    default: Date.now,
    index: true
  }
});

MarketEventSchema.index({ marketId: 1, blockNumber: 1 });
MarketEventSchema.index({ marketId: 1, timestamp: 1 });

module.exports = mongoose.model('MarketEvent', MarketEventSchema);

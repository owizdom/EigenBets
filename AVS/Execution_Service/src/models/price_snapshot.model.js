const mongoose = require('mongoose');

const PriceSnapshotSchema = new mongoose.Schema({
  marketId: {
    type: String,
    required: true,
    index: true
  },
  outcomeIndex: {
    type: Number,
    required: true
  },
  price: {
    type: String,
    required: true
  },
  probability: {
    type: Number,
    default: 0
  },
  usdcInPool: {
    type: String,
    default: '0'
  },
  tokensInPool: {
    type: String,
    default: '0'
  },
  blockNumber: {
    type: Number,
    default: 0
  },
  timestamp: {
    type: Date,
    default: Date.now,
    index: true
  }
});

PriceSnapshotSchema.index({ marketId: 1, outcomeIndex: 1, timestamp: 1 });
PriceSnapshotSchema.index({ marketId: 1, timestamp: -1 });

module.exports = mongoose.model('PriceSnapshot', PriceSnapshotSchema);

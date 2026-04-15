const mongoose = require('mongoose');

const UserPositionEventSchema = new mongoose.Schema({
  user: {
    type: String,
    lowercase: true,
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
    required: true
  },
  usdcDelta: {
    type: String,
    default: '0'
  },
  tokenDelta: {
    type: String,
    default: '0'
  },
  priceAtEvent: {
    type: String,
    default: '0'
  },
  action: {
    type: String,
    enum: ['buy', 'sell', 'claim', 'resolve'],
    required: true
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

UserPositionEventSchema.index({ user: 1, timestamp: 1 });
UserPositionEventSchema.index({ user: 1, marketId: 1, timestamp: 1 });

module.exports = mongoose.model('UserPositionEvent', UserPositionEventSchema);

const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
  walletAddress: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    index: true
  },
  displayName: {
    type: String,
    default: null,
    maxlength: 40
  },
  avatarUrl: {
    type: String,
    default: null,
    maxlength: 500
  },
  bio: {
    type: String,
    default: null,
    maxlength: 280
  },
  stats: {
    totalBets: { type: Number, default: 0 },
    wins: { type: Number, default: 0 },
    losses: { type: Number, default: 0 },
    totalVolume: { type: String, default: '0' },
    totalPnl: { type: String, default: '0' }
  },
  following: {
    type: [String],
    default: []
  },
  followers: {
    type: [String],
    default: []
  },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

UserSchema.pre('save', function (next) {
  this.updatedAt = new Date();
  next();
});

UserSchema.index({ 'stats.totalVolume': -1 });

module.exports = mongoose.model('User', UserSchema);

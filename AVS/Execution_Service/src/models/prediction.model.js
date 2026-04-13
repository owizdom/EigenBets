const mongoose = require('mongoose');

const PredictionSchema = new mongoose.Schema({
  inputString: {
    type: String,
    required: true,
  },
  ipfsCid: {
    type: String,
    required: true,
  },
  status: {
    type: String,
    enum: ['pending', 'executed', 'validated', 'failed'],
    default: 'pending'
  },
  result: {
    type: String,
    default: null
  },
  // Multi-outcome support: list of possible outcomes for this market
  outcomes: {
    type: [String],
    default: ['yes', 'no']
  },
  // The selected outcome after AI analysis
  selectedOutcome: {
    type: String,
    default: null
  },
  // Data source type for verification (twitter, news, financial, sports, weather, onchain)
  dataSourceType: {
    type: String,
    default: 'twitter'
  },
  // Data source-specific parameters (e.g., stock ticker, team names, location)
  dataParams: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  },
  // Market category for filtering
  marketCategory: {
    type: String,
    default: 'general'
  },
  endTime: {
    type: Date,
    required: true
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  executedAt: {
    type: Date,
    default: null
  },
  taskDefinitionId: {
    type: Number,
    default: 0
  },
  tweetIds: {
    type: [String],
    default: []
  }
});

// Create index for finding pending predictions that need execution
PredictionSchema.index({ status: 1, endTime: 1 });

module.exports = mongoose.model('Prediction', PredictionSchema);
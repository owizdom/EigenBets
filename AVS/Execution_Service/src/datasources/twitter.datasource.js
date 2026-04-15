const BaseDatasource = require('./base.datasource');
const { buildSystemPrompt } = require('../oracle.service');

class TwitterDatasource extends BaseDatasource {
  static get type() {
    return 'twitter';
  }

  async fetchData(condition, params) {
    return require('../services/twitter.service').fetchRelevantTweets(condition);
  }

  formatForAI(data, condition) {
    const tweets = Array.isArray(data) ? data : [];
    return `Condition: ${condition}\nX post: ${tweets.map(t => t.text).join('\n---\n')}`;
  }

  getSystemPrompt(outcomeOptions) {
    return buildSystemPrompt(outcomeOptions);
  }

  async healthCheck() {
    return { ok: true, reason: 'Twitter scraper (Nitter) active' };
  }
}

module.exports = TwitterDatasource;

const BaseDatasource = require('./base.datasource');
const { buildSystemPrompt } = require('../oracle.service');

/**
 * Twitter datasource — Validation Service side.
 *
 * Unlike the Execution side, the validator does NOT re-scrape Twitter.
 * Scraping Nitter is non-deterministic (tweet order changes, some become
 * deleted), so two independent scrapes would rarely agree. Instead the
 * validator uses the same formatted input the performer used (fetched
 * from IPFS by validator.service.js) and runs the same AI prompt on it.
 *
 * This plugin's fetchData/formatForAI are therefore pass-throughs.
 */
class TwitterDatasource extends BaseDatasource {
  static get type() {
    return 'twitter';
  }

  async fetchData(condition, params) {
    // Validator receives performer's formatted input via IPFS; no re-fetch.
    return null;
  }

  formatForAI(data, condition) {
    // Caller (validator.service) passes the performer's formattedInput directly;
    // this method is a no-op for Twitter on the validation side.
    return `Condition: ${condition}`;
  }

  getSystemPrompt(outcomeOptions) {
    return buildSystemPrompt(outcomeOptions);
  }

  async healthCheck() {
    return { ok: true, reason: 'Twitter validation uses performer-supplied data (no re-scrape)' };
  }
}

module.exports = TwitterDatasource;

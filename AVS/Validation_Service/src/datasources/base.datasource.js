/**
 * BaseDatasource — Abstract base class for all data source plugins.
 *
 * Every data source (twitter, news, financial, sports, weather, onchain) must
 * extend this class and implement all four abstract methods.
 *
 * The registry.js file auto-loads all plugins on import.
 */
class BaseDatasource {
  /**
   * Unique type identifier (e.g. 'twitter', 'news', 'financial').
   * @returns {string}
   */
  static get type() {
    throw new Error(`${this.name} must implement static get type()`);
  }

  /**
   * Fetch raw data from the underlying source.
   * @param {string} condition - The prediction condition to evaluate
   * @param {object} params - Source-specific parameters (e.g. { ticker: 'AAPL' })
   * @returns {Promise<any>} raw data, or null/fallback on failure
   */
  async fetchData(condition, params) {
    throw new Error(`${this.constructor.name} must implement fetchData()`);
  }

  /**
   * Convert raw data into a string the AI can analyze.
   * @param {any} data - Output of fetchData()
   * @param {string} condition - The prediction condition
   * @returns {string} formatted prompt input
   */
  formatForAI(data, condition) {
    throw new Error(`${this.constructor.name} must implement formatForAI()`);
  }

  /**
   * Return the AI system prompt appropriate for this data type.
   * Must preserve binary yes/no behaviour when outcomeOptions = ['yes','no'].
   * @param {string[]} outcomeOptions - Possible outcomes
   * @returns {string} system prompt
   */
  getSystemPrompt(outcomeOptions) {
    throw new Error(`${this.constructor.name} must implement getSystemPrompt()`);
  }

  /**
   * Verify the plugin is properly configured (API key, endpoint reachable).
   * Called on startup and via an admin endpoint.
   * @returns {Promise<{ok: boolean, reason?: string}>}
   */
  async healthCheck() {
    throw new Error(`${this.constructor.name} must implement healthCheck()`);
  }
}

module.exports = BaseDatasource;

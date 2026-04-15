require('dotenv').config();
const axios = require('axios');
const BaseDatasource = require('./base.datasource');
const { buildSystemPrompt } = require('../oracle.service');

const STOPWORDS = ['the', 'and', 'or', 'a', 'an', 'is', 'was', 'will',
                   'be', 'of', 'to', 'in', 'on', 'for', 'with'];

/**
 * Extract top 5 meaningful keywords from the condition string.
 * @param {string} condition
 * @returns {string[]}
 */
function extractKeywords(condition) {
  if (!condition) return [];
  return condition.toLowerCase()
    .replace(/[^\w\s]/g, ' ')
    .split(/\s+/)
    .filter(w => w.length > 2 && !STOPWORDS.includes(w))
    .slice(0, 5);
}

class NewsDatasource extends BaseDatasource {
  static get type() {
    return 'news';
  }

  async fetchData(condition, params) {
    try {
      const apiKey = process.env.NEWSAPI_KEY;
      if (!apiKey) {
        console.warn('NewsDatasource: NEWSAPI_KEY not set, returning []');
        return [];
      }

      const query = (params && params.query)
        ? params.query
        : extractKeywords(condition).join(' ');

      if (!query) return [];

      const url = `https://newsapi.org/v2/everything?q=${encodeURIComponent(query)}&sortBy=publishedAt&pageSize=10&language=en`;
      const response = await axios.get(url, {
        headers: { 'X-Api-Key': apiKey }
      });

      const articles = (response.data && response.data.articles) || [];
      return articles.slice(0, 5).map(a => ({
        title: a.title,
        description: a.description,
        source: a.source && a.source.name ? a.source.name : 'unknown',
        publishedAt: a.publishedAt
      }));
    } catch (error) {
      console.error(`NewsDatasource fetchData error: ${error.message}`);
      return [];
    }
  }

  formatForAI(data, condition) {
    if (!data || data.length === 0) {
      return `Condition: ${condition}\nNews articles: (none found)`;
    }
    return `Condition: ${condition}\nNews articles:\n${data.map(a => '- [' + a.source + ' ' + a.publishedAt + '] ' + a.title + ': ' + a.description).join('\n')}`;
  }

  getSystemPrompt(outcomeOptions) {
    return buildSystemPrompt(outcomeOptions);
  }

  async healthCheck() {
    if (!process.env.NEWSAPI_KEY) {
      return { ok: false, reason: 'NEWSAPI_KEY not set' };
    }
    return { ok: true, reason: 'NewsAPI configured' };
  }
}

module.exports = NewsDatasource;

const axios = require('axios');
const BaseDatasource = require('./base.datasource');
const { buildSystemPrompt } = require('../oracle.service');

const KNOWN_CRYPTOS = ['bitcoin', 'ethereum', 'solana', 'cardano', 'dogecoin', 'polygon', 'chainlink', 'uniswap'];

class FinancialDatasource extends BaseDatasource {
  static get type() {
    return 'financial';
  }

  async fetchData(condition, params) {
    params = params || {};
    const assetType = params.assetType || this._inferAssetType(condition);
    try {
      let symbols = Array.isArray(params.symbols) ? params.symbols : null;
      if (!symbols || symbols.length === 0) {
        symbols = this._extractSymbols(condition, assetType);
      }
      if (!symbols || symbols.length === 0) {
        return { assetType, prices: [] };
      }

      if (assetType === 'crypto') {
        return await this._fetchCrypto(symbols);
      }
      if (assetType === 'stock') {
        return await this._fetchStocks(symbols);
      }
      return { assetType, prices: [] };
    } catch (err) {
      console.error('FinancialDatasource.fetchData error:', err.message);
      return { assetType: assetType || 'unknown', prices: [] };
    }
  }

  async _fetchCrypto(symbols) {
    const ids = symbols.map(s => String(s).toLowerCase()).join(',');
    const url = `https://api.coingecko.com/api/v3/simple/price?ids=${ids}&vs_currencies=usd&include_24hr_change=true&include_market_cap=true`;
    const res = await axios.get(url, { timeout: 10000 });
    const prices = [];
    for (const sym of symbols) {
      const key = String(sym).toLowerCase();
      const entry = res.data && res.data[key];
      if (entry && typeof entry.usd === 'number') {
        prices.push({
          symbol: key,
          price: entry.usd,
          change24h: typeof entry.usd_24h_change === 'number' ? entry.usd_24h_change : null,
          marketCap: typeof entry.usd_market_cap === 'number' ? entry.usd_market_cap : null
        });
      }
    }
    return { assetType: 'crypto', prices };
  }

  async _fetchStocks(symbols) {
    const key = process.env.ALPHA_VANTAGE_KEY;
    if (!key) {
      return { assetType: 'stock', prices: [] };
    }
    const prices = [];
    for (const ticker of symbols) {
      try {
        const url = `https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=${encodeURIComponent(ticker)}&apikey=${key}`;
        const res = await axios.get(url, { timeout: 10000 });
        const quote = res.data && res.data['Global Quote'];
        if (quote && quote['05. price']) {
          const price = parseFloat(quote['05. price']);
          const pctRaw = quote['10. change percent'];
          const change24h = pctRaw ? parseFloat(String(pctRaw).replace('%', '')) : null;
          prices.push({ symbol: String(ticker).toUpperCase(), price, change24h });
        }
      } catch (err) {
        console.error(`Alpha Vantage fetch failed for ${ticker}:`, err.message);
      }
    }
    return { assetType: 'stock', prices };
  }

  _inferAssetType(condition) {
    const lower = String(condition || '').toLowerCase();
    if (KNOWN_CRYPTOS.some(c => lower.includes(c))) return 'crypto';
    return 'stock';
  }

  _extractSymbols(condition, assetType) {
    const text = String(condition || '');
    if (assetType === 'crypto') {
      const lower = text.toLowerCase();
      return KNOWN_CRYPTOS.filter(c => lower.includes(c));
    }
    const matches = text.match(/\b[A-Z]{2,5}\b/g) || [];
    return Array.from(new Set(matches));
  }

  formatForAI(data, condition) {
    const prices = data && Array.isArray(data.prices) ? data.prices : [];
    if (prices.length === 0) {
      return `Condition: ${condition}\nFinancial data: (unavailable)`;
    }
    const lines = prices.map(p => '- ' + p.symbol + ': $' + p.price + (p.change24h ? ' (' + p.change24h.toFixed(2) + '% 24h)' : '')).join('\n');
    return `Condition: ${condition}\nFinancial data (${data.assetType}):\n${lines}`;
  }

  getSystemPrompt(outcomeOptions) {
    return buildSystemPrompt(outcomeOptions);
  }

  async healthCheck() {
    const reason = 'CoinGecko ready' + (process.env.ALPHA_VANTAGE_KEY
      ? ', Alpha Vantage configured'
      : ', Alpha Vantage key missing (stocks disabled)');
    return { ok: true, reason };
  }
}

module.exports = FinancialDatasource;

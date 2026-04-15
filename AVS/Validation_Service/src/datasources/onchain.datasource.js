const axios = require('axios');
const BaseDatasource = require('./base.datasource');
const { buildSystemPrompt } = require('../oracle.service');

const ETHERSCAN_BASE = 'https://api.etherscan.io/api';

class OnchainDatasource extends BaseDatasource {
  static get type() {
    return 'onchain';
  }

  async fetchData(condition, params) {
    params = params || {};
    try {
      const address = params.address || this._extractAddress(condition);
      if (!address) {
        return { error: 'No address' };
      }
      const queryType = params.queryType || 'balance';
      const key = process.env.ETHERSCAN_KEY || '';

      if (queryType === 'balance') {
        const url = `${ETHERSCAN_BASE}?module=account&action=balance&address=${address}&tag=latest&apikey=${key}`;
        const res = await axios.get(url, { timeout: 10000 });
        const wei = (res.data && res.data.result) ? String(res.data.result) : '0';
        const balanceEth = parseFloat(wei) / 1e18;
        return { type: 'balance', address, balanceWei: wei, balanceEth };
      }

      if (queryType === 'transactions') {
        const url = `${ETHERSCAN_BASE}?module=account&action=txlist&address=${address}&startblock=0&endblock=99999999&page=1&offset=10&sort=desc&apikey=${key}`;
        const res = await axios.get(url, { timeout: 10000 });
        const raw = (res.data && Array.isArray(res.data.result)) ? res.data.result : [];
        const txs = raw.slice(0, 5).map(t => ({
          hash: t.hash,
          from: t.from,
          to: t.to,
          value: t.value,
          timestamp: new Date(parseInt(t.timeStamp, 10) * 1000).toISOString()
        }));
        return { type: 'transactions', address, txs };
      }

      if (queryType === 'events') {
        const startBlock = params.startBlock || 0;
        const topic0 = params.topic0 || '';
        const url = `${ETHERSCAN_BASE}?module=logs&action=getLogs&fromBlock=${startBlock}&toBlock=latest&address=${address}&topic0=${topic0}&apikey=${key}`;
        const res = await axios.get(url, { timeout: 10000 });
        const raw = (res.data && Array.isArray(res.data.result)) ? res.data.result : [];
        const events = raw.slice(0, 5).map(e => ({
          txHash: e.transactionHash,
          blockNumber: e.blockNumber,
          data: e.data
        }));
        return { type: 'events', address, events };
      }

      return { type: 'unknown', error: 'Unsupported queryType' };
    } catch (err) {
      console.error('OnchainDatasource.fetchData error:', err.message);
      return { type: 'unknown', error: err.message };
    }
  }

  _extractAddress(condition) {
    const text = String(condition || '');
    const match = text.match(/0x[a-fA-F0-9]{40}/);
    return match ? match[0] : null;
  }

  formatForAI(data, condition) {
    if (!data || data.error || data.type === 'unknown') {
      return `Condition: ${condition}\nOn-chain data: (unavailable: ${(data && data.error) || 'unknown error'})`;
    }
    if (data.type === 'balance') {
      return `Condition: ${condition}\nOn-chain balance: ${data.address} has ${data.balanceEth} ETH`;
    }
    if (data.type === 'transactions') {
      const lines = (data.txs || []).map(t => '- ' + t.timestamp + ': ' + t.from.slice(0, 10) + '... \u2192 ' + t.to.slice(0, 10) + '... value=' + t.value).join('\n');
      return `Condition: ${condition}\nRecent transactions for ${data.address}:\n${lines}`;
    }
    if (data.type === 'events') {
      const lines = (data.events || []).map(e => '- block ' + e.blockNumber + ' tx ' + e.txHash.slice(0, 10) + '...').join('\n');
      return `Condition: ${condition}\nContract events at ${data.address}:\n${lines}`;
    }
    return `Condition: ${condition}\nOn-chain data: (unavailable: unknown error)`;
  }

  getSystemPrompt(outcomeOptions) {
    return buildSystemPrompt(outcomeOptions);
  }

  async healthCheck() {
    if (!process.env.ETHERSCAN_KEY) {
      return { ok: false, reason: 'ETHERSCAN_KEY not set' };
    }
    return { ok: true, reason: 'Etherscan configured' };
  }
}

module.exports = OnchainDatasource;

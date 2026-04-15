require('dotenv').config();
const axios = require('axios');
const BaseDatasource = require('./base.datasource');
const { buildSystemPrompt } = require('../oracle.service');

const BASE_URL = 'https://v3.football.api-sports.io';

class SportsDatasource extends BaseDatasource {
  static get type() {
    return 'sports';
  }

  async fetchData(condition, params) {
    try {
      const apiKey = process.env.SPORTS_API_KEY;
      if (!apiKey) {
        console.warn('SportsDatasource: SPORTS_API_KEY not set, returning []');
        return [];
      }

      params = params || {};
      let url;
      if (params.date) {
        url = `${BASE_URL}/fixtures?date=${encodeURIComponent(params.date)}`;
      } else if (params.teamId) {
        const season = params.season || new Date().getFullYear();
        url = `${BASE_URL}/fixtures?team=${encodeURIComponent(params.teamId)}&season=${encodeURIComponent(season)}`;
      } else {
        const today = new Date().toISOString().slice(0, 10);
        url = `${BASE_URL}/fixtures?date=${today}`;
      }

      const response = await axios.get(url, {
        headers: { 'x-apisports-key': apiKey }
      });

      const fixtures = (response.data && response.data.response) || [];
      return fixtures.slice(0, 10).map(f => ({
        homeTeam: f.teams && f.teams.home ? f.teams.home.name : 'unknown',
        awayTeam: f.teams && f.teams.away ? f.teams.away.name : 'unknown',
        homeScore: f.goals ? f.goals.home : null,
        awayScore: f.goals ? f.goals.away : null,
        status: f.fixture && f.fixture.status ? (f.fixture.status.short || f.fixture.status.long || 'unknown') : 'unknown',
        league: f.league && f.league.name ? f.league.name : 'unknown',
        date: f.fixture && f.fixture.date ? f.fixture.date : 'unknown'
      }));
    } catch (error) {
      console.error(`SportsDatasource fetchData error: ${error.message}`);
      return [];
    }
  }

  formatForAI(data, condition) {
    if (!data || data.length === 0) {
      return `Condition: ${condition}\nSports fixtures: (none found)`;
    }
    return `Condition: ${condition}\nSports fixtures:\n${data.map(f => '- ' + f.league + ': ' + f.homeTeam + ' ' + (f.homeScore ?? '-') + ' vs ' + (f.awayScore ?? '-') + ' ' + f.awayTeam + ' (' + f.status + ', ' + f.date + ')').join('\n')}`;
  }

  getSystemPrompt(outcomeOptions) {
    return buildSystemPrompt(outcomeOptions);
  }

  async healthCheck() {
    if (!process.env.SPORTS_API_KEY) {
      return { ok: false, reason: 'SPORTS_API_KEY not set' };
    }
    return { ok: true, reason: 'API-Football configured' };
  }
}

module.exports = SportsDatasource;

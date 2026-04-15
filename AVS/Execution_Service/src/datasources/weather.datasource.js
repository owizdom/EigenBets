require('dotenv').config();
const axios = require('axios');
const BaseDatasource = require('./base.datasource');
const { buildSystemPrompt } = require('../oracle.service');

class WeatherDatasource extends BaseDatasource {
  static get type() {
    return 'weather';
  }

  async fetchData(condition, params = {}) {
    try {
      const key = process.env.OPENWEATHERMAP_KEY;
      if (!key) throw new Error('OPENWEATHERMAP_KEY not set');

      let city = params.city;
      if (!city) {
        const matches = (condition || '').match(/\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\b/g);
        city = (matches && matches[0]) || 'New York';
      }

      if (params.forecast === true) {
        const url = `https://api.openweathermap.org/data/2.5/forecast?q=${encodeURIComponent(city)}&appid=${key}&units=metric`;
        const res = await axios.get(url);
        const list = (res.data && res.data.list) || [];
        const daily = list.filter(item => item.dt_txt && item.dt_txt.includes('12:00:00')).slice(0, 5);
        const forecast = daily.map(item => ({
          date: item.dt_txt.split(' ')[0],
          temp: item.main.temp,
          condition: item.weather[0].main + ' - ' + item.weather[0].description,
          humidity: item.main.humidity,
          windSpeed: item.wind.speed
        }));
        return { city: res.data.city ? res.data.city.name : city, forecast };
      }

      const url = `https://api.openweathermap.org/data/2.5/weather?q=${encodeURIComponent(city)}&appid=${key}&units=metric`;
      const res = await axios.get(url);
      const d = res.data;
      return {
        city: d.name || city,
        current: {
          temp: d.main.temp,
          condition: d.weather[0].main + ' - ' + d.weather[0].description,
          humidity: d.main.humidity,
          windSpeed: d.wind.speed
        }
      };
    } catch (err) {
      console.error('WeatherDatasource.fetchData error:', err.message);
      return { city: 'unknown', current: null, forecast: null };
    }
  }

  formatForAI(data, condition) {
    if (!data || (!data.current && !data.forecast)) {
      return `Condition: ${condition}\nWeather data: (unavailable)`;
    }
    if (data.forecast) {
      return `Condition: ${condition}\nWeather forecast for ${data.city}:\n${data.forecast.map(f => '- ' + f.date + ': ' + f.condition + ', ' + f.temp + '°C').join('\n')}`;
    }
    return `Condition: ${condition}\nWeather in ${data.city}: ${data.current.condition}, ${data.current.temp}°C, humidity ${data.current.humidity}%, wind ${data.current.windSpeed} m/s`;
  }

  getSystemPrompt(outcomeOptions) {
    return buildSystemPrompt(outcomeOptions);
  }

  async healthCheck() {
    if (!process.env.OPENWEATHERMAP_KEY) {
      return { ok: false, reason: 'OPENWEATHERMAP_KEY not set' };
    }
    return { ok: true, reason: 'OpenWeatherMap configured' };
  }
}

module.exports = WeatherDatasource;

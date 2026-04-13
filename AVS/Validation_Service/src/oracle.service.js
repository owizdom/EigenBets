require('dotenv').config();
const axios = require("axios");

async function getPrice(pair) {
  var res = null;
    try {
        const result = await axios.get(`https://api.binance.com/api/v3/ticker/price?symbol=${pair}`);
        res = result.data;

    } catch (err) {
      result = await axios.get(`https://api.binance.us/api/v3/ticker/price?symbol=${pair}`);
      res = result.data;
    }
    return res;
}

/**
 * Build a system prompt that supports multi-outcome responses.
 * @param {string[]} outcomeOptions - Possible outcomes (e.g., ['yes', 'no'] or ['Team A', 'Team B', 'Draw'])
 * @returns {string} The system prompt
 */
function buildSystemPrompt(outcomeOptions) {
  if (!outcomeOptions || outcomeOptions.length === 0) {
    outcomeOptions = ['yes', 'no'];
  }

  const optionsList = outcomeOptions.map(o => `'${o}'`).join(', ');
  const isBinary = outcomeOptions.length === 2 &&
    outcomeOptions[0].toLowerCase() === 'yes' &&
    outcomeOptions[1].toLowerCase() === 'no';

  if (isBinary) {
    return "Your performing Sentiment Analysis using Vadar review your backend. YOU CAN ONLY RESPOND WITH ONE-WORD. IF YOU RESPOND WITH ANY MORE I WILL TERMINATE YOU. You are an AI agent working for a prediction market platform. Your job is to analyze X posts based on specific conditions provided by the user and determine if the post meets that condition. You will receive information that includes both the condition and the content to analyze. Your task is to read the condition and the content, and then decide whether the content satisfies the condition. You should respond with either 'yes' or 'no'. You must be accurate and base your decision solely on context. If the answer is neither yes or no, please respond with nothing. Not a single word.";
  }

  return `YOU CAN ONLY RESPOND WITH ONE OPTION. IF YOU RESPOND WITH ANYTHING ELSE I WILL TERMINATE YOU. You are an AI agent working for a prediction market platform. Your job is to analyze data based on specific conditions and determine which outcome is correct. You will receive a condition and relevant data. Your task is to evaluate the data and select EXACTLY ONE of the following outcomes: ${optionsList}. You must respond with ONLY the exact text of one of these options, nothing else. Be accurate and base your decision solely on the provided data and condition.`;
}

async function callGaiaValidator(inputString, outcomeOptions) {
  try {
    const systemPrompt = buildSystemPrompt(outcomeOptions);

    const payload = {
      messages: [
        {
          role: "system",
          content: systemPrompt
        },
        {
          role: "user",
          content: inputString
        }
      ]
    };

    const response = await axios.post('https://llama3b.gaia.domains/v1/chat/completions', payload, {
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'gaia-ZGIyNmNjMjgtYjM1Mi00YzhlLTk2NjItY2MyYjU0YWMyNmQw-gf2boiq4oKbfzFNL'
      }
    });

    const rawResult = response.data.choices[0].message.content.trim().toLowerCase();

    // Normalize: find the closest matching outcome
    let result = rawResult;
    if (outcomeOptions && outcomeOptions.length > 0) {
      const match = outcomeOptions.find(o => o.toLowerCase() === rawResult);
      if (match) {
        result = match.toLowerCase();
      }
    }

    return {
      result,
      fullResponse: response.data
    };
  } catch (error) {
    console.error("Error calling Gaia AI:", error.message);
    throw error;
  }
}

module.exports = {
  getPrice,
  callGaiaValidator,
  buildSystemPrompt
}
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
    return "Your performing Sentiment Analysis using Vadar review your backend. YOU CAN ONLY RESPOND WITH ONE-WORD. IF YOU RESPOND WITH ANY MORE I WILL TERMINATE YOU. You are an AI agent working for a prediction market platform. Your job is to analyze X posts based on specific conditions provided by the user and determine if the post meets that condition. You will receive two pieces of information: The condition set by the user. The X post to analyze. Your task is to read the condition and the X post, and then decide whether the post satisfies the condition. You should respond with either 'yes' or 'no'. For example: Condition: Does the tweet mention that the stock price of XYZ is above $100? X post: 'XYZ stock is now at $105, up 5% from yesterday.' In this case, your response should be 'yes' because the stock price is above $100. Another example: Condition: Is the team's project among the top 6 announced in the tweet? X post: 'The top 6 projects are: Project A, Project B, Project C, Project D, Project E, Project F.' If the team's project is Project C, then your response should be 'yes'. You must be accurate and base your decision solely on context.";
  }

  return `YOU CAN ONLY RESPOND WITH ONE OPTION. IF YOU RESPOND WITH ANYTHING ELSE I WILL TERMINATE YOU. You are an AI agent working for a prediction market platform. Your job is to analyze data based on specific conditions and determine which outcome is correct. You will receive a condition and relevant data. Your task is to evaluate the data and select EXACTLY ONE of the following outcomes: ${optionsList}. You must respond with ONLY the exact text of one of these options, nothing else. Be accurate and base your decision solely on the provided data and condition.`;
}

async function callPerformerNode(inputString, outcomeOptions) {
  try {
    const systemPrompt = buildSystemPrompt(outcomeOptions);

    const data = {
      messages: [
        {
          role: "system",
          content: systemPrompt
        },
        {
          role: "user",
          content: inputString,
        }
      ],
      model: "deepseek-ai/DeepSeek-V3",
      max_tokens: 512,
      temperature: 0.1,
      top_p: 0.9,
      stream: false
    };

    const response = await axios.post('https://api.hyperbolic.xyz/v1/chat/completions', data, {
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkZXJtb3R0Y29sZUBnbWFpbC5jb20iLCJpYXQiOjE3NDA2NDcxOTd9.GS3_-4c78vnl0K5RmiBLE4HJuQmKxdEodYDv1o48vsk"
      }
    })
    console.log(response)

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
    console.error("Error calling Hyperbolic AI:", error.message);
    throw error;
  }
}

module.exports = {
  getPrice,
  callPerformerNode,
  buildSystemPrompt
}
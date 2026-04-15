require('dotenv').config();
const cron = require('node-cron');
const axios = require('axios');
const twitterService = require('./twitter.service');
const oracleService = require('../oracle.service');
const dalService = require('../dal.service');

// Store prediction registry on IPFS
let predictionsRegistryCid = null;

// Initialize the scheduler
function init() {
  console.log('Initializing scheduler service...');
  
  // First load the current registry
  loadPredictionRegistry();
  
  // Run every minute to check for predictions that need execution
  cron.schedule('* * * * *', async () => {
    await checkPendingPredictions();
  });
  
  console.log('Scheduler service initialized');
}

// Load prediction registry from IPFS
async function loadPredictionRegistry() {
  try {
    // Check if we have a registry CID in environment
    const registryCid = process.env.PREDICTIONS_REGISTRY_CID;
    
    if (registryCid) {
      console.log(`Loading predictions registry from IPFS: ${registryCid}`);
      try {
        const response = await axios.get(`${process.env.IPFS_HOST}${registryCid}`);
        predictionsRegistryCid = registryCid;
        console.log(`Loaded ${response.data.predictions.length} predictions from registry`);
      } catch (error) {
        console.warn('Could not load existing registry, will create new one', error.message);
      }
    } else {
      console.log('No registry CID found, will create new registry on first prediction');
    }
  } catch (error) {
    console.error('Error loading prediction registry:', error);
  }
}

// Save prediction registry to IPFS
async function savePredictionRegistry(predictions) {
  try {
    // Create registry object
    const registry = {
      predictions: predictions || [],
      lastUpdated: new Date().toISOString()
    };
    
    // Save to IPFS
    const cid = await dalService.publishJSONToIpfs(registry);
    predictionsRegistryCid = cid;
    
    console.log(`Updated prediction registry saved to IPFS: ${cid}`);
    console.log('IMPORTANT: Save this CID in your environment as PREDICTIONS_REGISTRY_CID');
    
    return cid;
  } catch (error) {
    console.error('Error saving prediction registry:', error);
    throw error;
  }
}

// Get predictions from registry
async function getPredictions() {
  if (!predictionsRegistryCid) {
    return [];
  }
  
  try {
    const response = await axios.get(`${process.env.IPFS_HOST}${predictionsRegistryCid}`);
    return response.data.predictions || [];
  } catch (error) {
    console.error('Error fetching predictions from registry:', error);
    return [];
  }
}

// Add prediction to registry
async function addPrediction(prediction) {
  try {
    // Get current predictions
    const predictions = await getPredictions();
    
    // Add new prediction
    predictions.push(prediction);
    
    // Save updated registry
    await savePredictionRegistry(predictions);
    
    return prediction;
  } catch (error) {
    console.error('Error adding prediction to registry:', error);
    throw error;
  }
}

// Update prediction in registry
async function updatePrediction(predictionId, updates) {
  try {
    // Get current predictions
    const predictions = await getPredictions();
    
    // Find and update the prediction
    const updatedPredictions = predictions.map(p => {
      if (p.id === predictionId) {
        return { ...p, ...updates };
      }
      return p;
    });
    
    // Save updated registry
    await savePredictionRegistry(updatedPredictions);
    
    return updatedPredictions.find(p => p.id === predictionId);
  } catch (error) {
    console.error(`Error updating prediction ${predictionId}:`, error);
    throw error;
  }
}

// Check for predictions that have reached their end time and need execution
async function checkPendingPredictions() {
  try {
    const now = new Date();
    
    // Get all predictions
    const predictions = await getPredictions();
    
    // Find pending predictions that have reached their end time
    const pendingPredictions = predictions.filter(p => 
      p.status === 'pending' && new Date(p.endTime) <= now
    );
    
    console.log(`Found ${pendingPredictions.length} pending predictions to execute`);
    
    // Process each prediction
    for (const prediction of pendingPredictions) {
      await executePrediction(prediction);
    }
  } catch (error) {
    console.error('Error checking pending predictions:', error);
  }
}

// Execute a prediction by getting tweets and calling AI
async function executePrediction(prediction) {
  try {
    console.log(`Executing prediction ${prediction.id} (source: ${prediction.dataSourceType || 'twitter'})`);

    // Extract the condition from the input string
    // Assuming format: "Condition: {condition}\nX post: {tweet}" (legacy) or just "Condition: {condition}"
    const conditionMatch = prediction.inputString.match(/Condition: (.*?)(?:\n|$)/);
    const condition = conditionMatch ? conditionMatch[1].trim() : '';

    if (!condition) {
      throw new Error('Could not extract condition from input string');
    }

    // Route through the plugin registry based on dataSourceType
    const dataSourceType = prediction.dataSourceType || 'twitter';
    const params = prediction.dataParams || {};
    const outcomeOptions = prediction.outcomes || ['yes', 'no'];

    // executeVerification: fetch → format → call AI (via the right plugin)
    const aiResult = await oracleService.executeVerification(
      dataSourceType,
      condition,
      params,
      outcomeOptions
    );

    const inputForAI = aiResult.formattedInput;

    // Prepare data for IPFS — include outcomes so validator can re-verify correctly
    const resultData = {
      inputString: inputForAI,
      originalPredictionId: prediction.id,
      result: aiResult.result,
      outcomes: outcomeOptions,
      dataSourceType,
      dataParams: params,
      condition,
      timestamp: new Date().toISOString()
    };

    // Publish result to IPFS
    const resultCid = await dalService.publishJSONToIpfs(resultData);

    // Send the task to the network
    const data = JSON.stringify({
      inputString: inputForAI,
      result: aiResult.result,
      outcomes: outcomeOptions,
      dataSourceType
    });

    await dalService.sendTask(resultCid, data, prediction.taskDefinitionId);
    
    // Update prediction status in registry
    await updatePrediction(prediction.id, {
      status: 'executed',
      selectedOutcome: aiResult.result,
      result: aiResult.result,
      resultCid: resultCid,
      executedAt: new Date().toISOString(),
      // Preserve tweetIds for backward compat when source is Twitter
      tweetIds: (dataSourceType === 'twitter' && Array.isArray(aiResult.rawData))
        ? aiResult.rawData.map(t => t.id).filter(Boolean)
        : []
    });
    
    console.log(`Prediction ${prediction.id} executed successfully with result: ${aiResult.result}`);
    
  } catch (error) {
    console.error(`Error executing prediction ${prediction.id}:`, error);
    
    // Update prediction as failed
    await updatePrediction(prediction.id, {
      status: 'failed',
      error: error.message
    });
  }
}

module.exports = {
  init,
  getPredictions,
  addPrediction,
  updatePrediction,
  checkPendingPredictions,
  executePrediction
};
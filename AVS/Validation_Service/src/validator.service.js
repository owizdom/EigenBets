require('dotenv').config();
const dalService = require("./dal.service");
const oracleService = require("./oracle.service");

async function validate(proofOfTask) {
  try {
    // Get the task data from IPFS (published by the performer)
    const taskResult = await dalService.getIPfsTask(proofOfTask);

    const performerResult = taskResult.result;
    const outcomeOptions = taskResult.outcomes || ['yes', 'no'];
    const dataSourceType = taskResult.dataSourceType || 'twitter';
    const dataParams = taskResult.dataParams || {};
    const condition = taskResult.condition || '';

    console.log(`Validating prediction (source: ${dataSourceType}, outcomes: ${outcomeOptions.join(',')})`);
    console.log(`Performer node result: ${performerResult}`);

    // Independent validation path: re-fetch data via the plugin, run our own AI
    let validatorInputString;
    try {
      const registry = require('./datasources/registry');
      const datasource = registry.get(dataSourceType);
      // For data sources other than twitter, re-fetch independently
      if (dataSourceType !== 'twitter') {
        const freshData = await datasource.fetchData(condition, dataParams);
        validatorInputString = datasource.formatForAI(freshData, condition);
      } else {
        // Twitter: use performer's formatted input (see comment in validation-side twitter plugin)
        validatorInputString = taskResult.inputString;
      }
    } catch (err) {
      console.warn(`[validator] plugin re-fetch failed, falling back to performer input: ${err.message}`);
      validatorInputString = taskResult.inputString;
    }

    // Call Gaia validator AI with the (possibly re-fetched) data
    const validatorResponse = await oracleService.callGaiaValidator(validatorInputString, outcomeOptions);
    const validatorResult = validatorResponse.result;

    console.log(`Validator node result: ${validatorResult}`);

    // Compare results with normalization for multi-outcome
    const normalizedPerformer = performerResult.trim().toLowerCase();
    const normalizedValidator = validatorResult.trim().toLowerCase();
    let isApproved = normalizedValidator === normalizedPerformer;

    console.log(`Validation ${isApproved ? 'approved' : 'rejected'}: Performer: ${performerResult}, Validator: ${validatorResult}`);

    return {
      isApproved,
      validatorResult,
      performerResult,
      inputString: taskResult.inputString,
      dataSourceType
    };
  } catch (err) {
    console.error(err?.message);
    return {
      isApproved: false,
      error: err?.message
    };
  }
}
  
module.exports = {
  validate,
}
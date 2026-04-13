require('dotenv').config();
const dalService = require("./dal.service");
const oracleService = require("./oracle.service");

async function validate(proofOfTask) {
  try {
    // Get the task data from IPFS
    const taskResult = await dalService.getIPfsTask(proofOfTask);
    
    // Extract the input string from the task result
    const inputString = taskResult.inputString;
    const performerResult = taskResult.result;
    
    console.log(`Validating prediction with input: ${inputString.substring(0, 100)}...`);
    console.log(`Performer node result: ${performerResult}`);
    
    // Extract outcome options if available (for multi-outcome markets)
    const outcomeOptions = taskResult.outcomes || ['yes', 'no'];

    // Call the Gaia validator AI to independently validate
    const validatorResponse = await oracleService.callGaiaValidator(inputString, outcomeOptions);
    const validatorResult = validatorResponse.result;

    console.log(`Validator node result: ${validatorResult}`);
    console.log(`Outcome options: ${outcomeOptions.join(', ')}`);

    // Compare results with normalization (trim, lowercase) for multi-outcome
    const normalizedPerformer = performerResult.trim().toLowerCase();
    const normalizedValidator = validatorResult.trim().toLowerCase();
    let isApproved = normalizedValidator === normalizedPerformer;
    
    // Log the validation result
    console.log(`Validation ${isApproved ? 'approved' : 'rejected'}: Performer: ${performerResult}, Validator: ${validatorResult}`);
    
    return {
      isApproved,
      validatorResult,
      performerResult,
      inputString
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
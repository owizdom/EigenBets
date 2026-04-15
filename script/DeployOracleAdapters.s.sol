// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {NewsOracleAdapter} from "../src/oracles/NewsOracleAdapter.sol";
import {SportsOracleAdapter} from "../src/oracles/SportsOracleAdapter.sol";
import {FinancialDataAdapter} from "../src/oracles/FinancialDataAdapter.sol";
import {ChainlinkPriceAdapter} from "../src/oracles/ChainlinkPriceAdapter.sol";

/// @notice Deploys all Phase 2 oracle adapters and prints their addresses.
/// @dev Each adapter must be registered with the hook via the resolver address in createMarket.
contract DeployOracleAdaptersScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address hookAddress = vm.envAddress("MULTI_OUTCOME_HOOK_ADDRESS");
        require(hookAddress != address(0), "Set MULTI_OUTCOME_HOOK_ADDRESS");

        console.log("Deployer:", deployer);
        console.log("Hook:", hookAddress);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Chainlink price adapter (Phase 1, redeploy if needed)
        ChainlinkPriceAdapter chainlink = new ChainlinkPriceAdapter(hookAddress);
        console.log("ChainlinkPriceAdapter:", address(chainlink));

        // 2. News oracle (multi-sig submitters + challenge period)
        NewsOracleAdapter news = new NewsOracleAdapter(hookAddress);
        console.log("NewsOracleAdapter:", address(news));

        // 3. Sports oracle (authorized data providers)
        SportsOracleAdapter sports = new SportsOracleAdapter(hookAddress);
        console.log("SportsOracleAdapter:", address(sports));

        // 4. Financial data composite adapter
        FinancialDataAdapter financial = new FinancialDataAdapter(hookAddress);
        console.log("FinancialDataAdapter:", address(financial));

        vm.stopBroadcast();

        console.log("All oracle adapters deployed. Register resolvers in hook via createMarket.");
    }
}

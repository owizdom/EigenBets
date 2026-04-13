// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MultiOutcomePredictionMarketHook} from "../src/Hooks/MultiOutcomePredictionMarketHook.sol";
import {OutcomeTokenFactory} from "../src/tokens/OutcomeTokenFactory.sol";
import {HookMiner} from "lib/v4-periphery/src/utils/HookMiner.sol";
import {IPoolManager} from "@v4-core/interfaces/IPoolManager.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract DeployMultiOutcomeMarketScript is Script {
    function run() external {
        console.log("Starting MultiOutcomePredictionMarketHook deployment");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer:", deployer);

        uint160 flags = uint160(
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG |
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.AFTER_SWAP_FLAG
        );

        address poolManagerAddress = vm.envOr(
            "POOL_MANAGER_ADDRESS",
            address(0x00B036B58a818B1BC34d502D3fE730Db729e62AC)
        );
        address create2Deployer = vm.envOr(
            "CREATE2_DEPLOYER_ADDRESS",
            address(0x4e59b44847b379578588920cA78FbF26c0B4956C)
        );

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy mock USDC
        ERC20Mock usdc = new ERC20Mock();
        usdc.mint(deployer, 1_000_000e6);
        console.log("USDC:", address(usdc));

        // 2. Deploy OutcomeTokenFactory
        OutcomeTokenFactory factory = new OutcomeTokenFactory();
        console.log("TokenFactory:", address(factory));

        // 3. Mine hook address and deploy
        console.log("Mining hook address...");
        (address predictedHook, bytes32 salt) = HookMiner.find(
            create2Deployer,
            flags,
            type(MultiOutcomePredictionMarketHook).creationCode,
            abi.encode(
                IPoolManager(poolManagerAddress),
                address(usdc),
                address(factory)
            )
        );

        MultiOutcomePredictionMarketHook hook = new MultiOutcomePredictionMarketHook{salt: salt}(
            IPoolManager(poolManagerAddress),
            address(usdc),
            factory
        );
        console.log("Hook deployed at:", address(hook));
        require(address(hook) == predictedHook, "Address mismatch");

        // 4. Transfer USDC to hook for pool seeding
        usdc.transfer(address(hook), 500_000e6);

        // 5. Create a sample binary market
        string[] memory binaryNames = new string[](2);
        binaryNames[0] = "Yes";
        binaryNames[1] = "No";
        string[] memory binarySymbols = new string[](2);
        binarySymbols[0] = "YES";
        binarySymbols[1] = "NO";

        uint256 binaryId = hook.createMarket(
            "Will ETH be above $5000 by end of Q2 2026?",
            binaryNames,
            binarySymbols,
            100_000e18,
            address(0) // owner resolves
        );
        console.log("Binary market created, ID:", binaryId);

        // Initialize binary market pools
        hook.initializePools(binaryId, 50_000e6, 50_000e18);
        console.log("Binary market pools initialized");

        // 6. Create a sample 4-outcome market
        string[] memory multiNames = new string[](4);
        multiNames[0] = "Below 50k";
        multiNames[1] = "50k-60k";
        multiNames[2] = "60k-70k";
        multiNames[3] = "Above 70k";
        string[] memory multiSymbols = new string[](4);
        multiSymbols[0] = "BTC_LT50";
        multiSymbols[1] = "BTC_5060";
        multiSymbols[2] = "BTC_6070";
        multiSymbols[3] = "BTC_GT70";

        uint256 multiId = hook.createMarket(
            "BTC price range at end of June 2026?",
            multiNames,
            multiSymbols,
            100_000e18,
            address(0) // owner resolves
        );
        console.log("Multi-outcome market created, ID:", multiId);

        // Need more USDC for 4 pools
        usdc.mint(deployer, 500_000e6);
        usdc.transfer(address(hook), 200_000e6);

        hook.initializePools(multiId, 50_000e6, 50_000e18);
        console.log("Multi-outcome market pools initialized");

        vm.stopBroadcast();
        console.log("Deployment complete");
    }
}

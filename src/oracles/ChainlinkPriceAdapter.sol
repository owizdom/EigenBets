// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracleAdapter} from "./IOracleAdapter.sol";
import {MultiOutcomePredictionMarketHook} from "../Hooks/MultiOutcomePredictionMarketHook.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title ChainlinkPriceAdapter
/// @notice Oracle adapter that resolves prediction markets based on Chainlink price feeds
/// @dev Supports both binary (above/below target) and range-based (which price band) markets
contract ChainlinkPriceAdapter is IOracleAdapter, Ownable {
    MultiOutcomePredictionMarketHook public immutable hook;

    // Supported price feeds: symbol => Chainlink aggregator
    mapping(string => address) public priceFeeds;

    // Market configuration
    struct PriceMarketConfig {
        address priceFeed;
        string asset;
        uint256[] thresholds; // Price thresholds defining outcome boundaries
        bool configured;
    }

    // marketId => config
    mapping(uint256 => PriceMarketConfig) public marketConfigs;

    event PriceFeedAdded(string symbol, address feed);
    event MarketConfigured(uint256 indexed marketId, string asset, uint256[] thresholds);

    constructor(address _hook) Ownable(msg.sender) {
        hook = MultiOutcomePredictionMarketHook(_hook);

        // Sepolia testnet defaults
        priceFeeds["ETH/USD"] = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
        priceFeeds["BTC/USD"] = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
        priceFeeds["LINK/USD"] = 0xc59E3633BAAC79493d908e63626716e204A45EdF;
    }

    /// @notice Add or update a Chainlink price feed
    function addPriceFeed(string memory symbol, address feed) external onlyOwner {
        require(feed != address(0), "Zero address");
        priceFeeds[symbol] = feed;
        emit PriceFeedAdded(symbol, feed);
    }

    /// @notice Configure a market for price-based resolution
    /// @param marketId The market to configure
    /// @param asset The asset symbol (e.g., "ETH/USD")
    /// @param thresholds Price thresholds that divide outcomes
    /// @dev For a binary market ("Will ETH be above $3000?"), thresholds = [3000e8]
    ///      Outcome 0 wins if price < threshold[0], Outcome 1 wins if price >= threshold[0]
    /// @dev For a range market with 4 outcomes ("<50k", "50-60k", "60-70k", ">70k"),
    ///      thresholds = [50000e8, 60000e8, 70000e8]
    ///      Outcome count should be thresholds.length + 1
    function configureMarket(
        uint256 marketId,
        string calldata asset,
        uint256[] calldata thresholds
    ) external onlyOwner {
        address feed = priceFeeds[asset];
        require(feed != address(0), "Unknown asset");
        require(thresholds.length > 0, "No thresholds");

        // Verify thresholds are sorted ascending
        for (uint256 i = 1; i < thresholds.length; i++) {
            require(thresholds[i] > thresholds[i - 1], "Thresholds not sorted");
        }

        // Verify outcome count matches: should be thresholds.length + 1
        (,, uint256 outcomeCount,,,,) = hook.getMarketSummary(marketId);
        require(outcomeCount == thresholds.length + 1, "Outcome count mismatch");

        marketConfigs[marketId] = PriceMarketConfig({
            priceFeed: feed,
            asset: asset,
            thresholds: thresholds,
            configured: true
        });

        emit MarketConfigured(marketId, asset, thresholds);
    }

    /// @inheritdoc IOracleAdapter
    function resolveMarket(uint256 marketId) external override returns (uint256[] memory winningOutcomes) {
        PriceMarketConfig storage config = marketConfigs[marketId];
        require(config.configured, "Market not configured");

        // Fetch current price
        AggregatorV3Interface feed = AggregatorV3Interface(config.priceFeed);
        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();
        require(answer > 0, "Invalid price");
        require(updatedAt > 0, "Stale price");

        uint256 price = uint256(answer);

        // Determine which outcome band the price falls into
        uint256 winningIndex = config.thresholds.length; // Default: highest band
        for (uint256 i = 0; i < config.thresholds.length; i++) {
            if (price < config.thresholds[i]) {
                winningIndex = i;
                break;
            }
        }

        winningOutcomes = new uint256[](1);
        winningOutcomes[0] = winningIndex;

        // Resolve on the hook
        hook.resolveMarket(marketId, winningOutcomes);
    }

    /// @inheritdoc IOracleAdapter
    function canResolve(uint256 marketId) external view override returns (bool) {
        PriceMarketConfig storage config = marketConfigs[marketId];
        if (!config.configured) return false;

        // Check market is in Closed state
        (, MultiOutcomePredictionMarketHook.MarketState state,,,,,) = hook.getMarketSummary(marketId);
        if (state != MultiOutcomePredictionMarketHook.MarketState.Closed) return false;

        // Check price feed is responsive
        AggregatorV3Interface feed = AggregatorV3Interface(config.priceFeed);
        try feed.latestRoundData() returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80) {
            return answer > 0 && updatedAt > 0;
        } catch {
            return false;
        }
    }

    /// @inheritdoc IOracleAdapter
    function getAdapterType() external pure override returns (string memory) {
        return "chainlink_price";
    }

    /// @notice Get latest price for an asset
    function getLatestPrice(string memory asset) external view returns (int256 price, uint8 decimals) {
        address feedAddr = priceFeeds[asset];
        require(feedAddr != address(0), "Unknown asset");
        AggregatorV3Interface feed = AggregatorV3Interface(feedAddr);
        (, price,,,) = feed.latestRoundData();
        decimals = feed.decimals();
    }

    /// @notice Preview which outcome would win at current price
    function previewResolution(uint256 marketId) external view returns (uint256 winningIndex, int256 currentPrice) {
        PriceMarketConfig storage config = marketConfigs[marketId];
        require(config.configured, "Not configured");

        AggregatorV3Interface feed = AggregatorV3Interface(config.priceFeed);
        (, currentPrice,,,) = feed.latestRoundData();

        uint256 price = uint256(currentPrice);
        winningIndex = config.thresholds.length;
        for (uint256 i = 0; i < config.thresholds.length; i++) {
            if (price < config.thresholds[i]) {
                winningIndex = i;
                break;
            }
        }
    }
}

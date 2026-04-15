// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracleAdapter} from "./IOracleAdapter.sol";
import {MultiOutcomePredictionMarketHook} from "../Hooks/MultiOutcomePredictionMarketHook.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title FinancialDataAdapter
/// @notice Composite oracle adapter that evaluates multiple Chainlink price feeds with AND/OR logic
/// @dev Useful for markets like "Will ETH be above $3000 AND BTC be above $60000?"
contract FinancialDataAdapter is IOracleAdapter, Ownable {
    uint256 public constant MAX_STALENESS = 3600; // 1 hour

    MultiOutcomePredictionMarketHook public immutable hook;

    enum Operator { GREATER_THAN, LESS_THAN, GREATER_EQUAL, LESS_EQUAL }
    enum CombineLogic { AND, OR }

    struct Condition {
        address priceFeed;
        uint256 threshold;
        Operator op;
    }

    struct MarketConfig {
        Condition[] conditions;
        CombineLogic logic;
        bool configured;
    }

    // marketId => config
    mapping(uint256 => MarketConfig) public marketConfigs;

    event MarketConfigured(uint256 indexed marketId, uint256 conditionCount, CombineLogic logic);
    event MarketResolved(uint256 indexed marketId, bool result, uint256 winningOutcome);

    constructor(address _hook) Ownable(msg.sender) {
        hook = MultiOutcomePredictionMarketHook(_hook);
    }

    /// @notice Configure a market with multiple price conditions combined via AND/OR
    /// @param marketId The market to configure
    /// @param priceFeeds Parallel array of Chainlink aggregator addresses
    /// @param thresholds Parallel array of price thresholds (matching feed decimals)
    /// @param ops Parallel array of Operator values (0=GT, 1=LT, 2=GTE, 3=LTE)
    /// @param logic Combine logic: 0=AND, 1=OR
    function configureMarket(
        uint256 marketId,
        address[] calldata priceFeeds,
        uint256[] calldata thresholds,
        uint8[] calldata ops,
        uint8 logic
    ) external onlyOwner {
        require(priceFeeds.length > 0, "No conditions");
        require(priceFeeds.length == thresholds.length, "Length mismatch");
        require(priceFeeds.length == ops.length, "Length mismatch");
        require(logic <= uint8(CombineLogic.OR), "Invalid logic");

        MarketConfig storage config = marketConfigs[marketId];
        // Clear any prior conditions
        delete config.conditions;

        for (uint256 i = 0; i < priceFeeds.length; i++) {
            require(priceFeeds[i] != address(0), "Zero feed");
            require(ops[i] <= uint8(Operator.LESS_EQUAL), "Invalid op");
            config.conditions.push(Condition({
                priceFeed: priceFeeds[i],
                threshold: thresholds[i],
                op: Operator(ops[i])
            }));
        }

        config.logic = CombineLogic(logic);
        config.configured = true;

        emit MarketConfigured(marketId, priceFeeds.length, CombineLogic(logic));
    }

    /// @notice Fetch a feed's latest price, validated for freshness and completeness
    function _getPrice(address feed) internal view returns (uint256) {
        AggregatorV3Interface agg = AggregatorV3Interface(feed);
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = agg.latestRoundData();
        require(answer > 0, "Invalid price");
        require(updatedAt > 0 && block.timestamp - updatedAt <= MAX_STALENESS, "Stale price");
        require(answeredInRound >= roundId, "Incomplete round");
        return uint256(answer);
    }

    /// @notice Evaluate a single condition against the live feed price
    function _evaluateCondition(Condition memory c) internal view returns (bool) {
        uint256 price = _getPrice(c.priceFeed);
        if (c.op == Operator.GREATER_THAN) return price > c.threshold;
        if (c.op == Operator.LESS_THAN) return price < c.threshold;
        if (c.op == Operator.GREATER_EQUAL) return price >= c.threshold;
        return price <= c.threshold; // LESS_EQUAL
    }

    /// @inheritdoc IOracleAdapter
    function resolveMarket(uint256 marketId) external override returns (uint256[] memory winningOutcomes) {
        MarketConfig storage config = marketConfigs[marketId];
        require(config.configured, "Market not configured");

        bool result;
        if (config.logic == CombineLogic.AND) {
            result = true;
            for (uint256 i = 0; i < config.conditions.length; i++) {
                if (!_evaluateCondition(config.conditions[i])) {
                    result = false;
                    break;
                }
            }
        } else {
            // OR
            result = false;
            for (uint256 i = 0; i < config.conditions.length; i++) {
                if (_evaluateCondition(config.conditions[i])) {
                    result = true;
                    break;
                }
            }
        }

        // Binary resolution: outcome 0 = yes/condition met, outcome 1 = no
        winningOutcomes = new uint256[](1);
        winningOutcomes[0] = result ? 0 : 1;

        hook.resolveMarket(marketId, winningOutcomes);

        emit MarketResolved(marketId, result, winningOutcomes[0]);
    }

    /// @inheritdoc IOracleAdapter
    function canResolve(uint256 marketId) external view override returns (bool) {
        MarketConfig storage config = marketConfigs[marketId];
        if (!config.configured) return false;

        // Market must be Closed
        (, MultiOutcomePredictionMarketHook.MarketState state,,,,,) = hook.getMarketSummary(marketId);
        if (state != MultiOutcomePredictionMarketHook.MarketState.Closed) return false;

        // All feeds must respond with fresh, complete data
        for (uint256 i = 0; i < config.conditions.length; i++) {
            AggregatorV3Interface feed = AggregatorV3Interface(config.conditions[i].priceFeed);
            try feed.latestRoundData() returns (uint80 roundId, int256 answer, uint256, uint256 updatedAt, uint80 answeredInRound) {
                if (answer <= 0) return false;
                if (updatedAt == 0 || block.timestamp - updatedAt > MAX_STALENESS) return false;
                if (answeredInRound < roundId) return false;
            } catch {
                return false;
            }
        }
        return true;
    }

    /// @inheritdoc IOracleAdapter
    function getAdapterType() external pure override returns (string memory) {
        return "financial";
    }

    /// @notice Get the number of conditions configured for a market
    function getConditionCount(uint256 marketId) external view returns (uint256) {
        return marketConfigs[marketId].conditions.length;
    }

    /// @notice Read a specific condition for a market
    function getCondition(uint256 marketId, uint256 index) external view returns (address feed, uint256 threshold, Operator op) {
        Condition storage c = marketConfigs[marketId].conditions[index];
        return (c.priceFeed, c.threshold, c.op);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracleAdapter} from "./IOracleAdapter.sol";
import {MultiOutcomePredictionMarketHook} from "../Hooks/MultiOutcomePredictionMarketHook.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title SportsOracleAdapter
/// @notice Oracle adapter that resolves prediction markets based on sports game results
/// @dev Authorized providers submit final scores + winning outcomes; challenge period precedes finality
contract SportsOracleAdapter is IOracleAdapter, Ownable {
    uint256 public constant CHALLENGE_PERIOD = 12 hours; // sports results settle faster
    uint256 public constant REQUIRED_APPROVALS = 2;

    MultiOutcomePredictionMarketHook public immutable hook;

    // Authorized data providers (e.g. API-Football relayers)
    mapping(address => bool) public authorizedProviders;

    struct GameResult {
        uint256 gameId;
        uint256 homeScore;
        uint256 awayScore;
        uint256[] winningOutcomes;
        uint256 submittedAt;
        uint256 approvals;
        bool finalized;
        bool challenged;
    }

    // marketId => pending result
    mapping(uint256 => GameResult) public pendingResults;

    // marketId => provider => approved
    mapping(uint256 => mapping(address => bool)) public hasApproved;

    // marketId => gameId (from API-Football)
    mapping(uint256 => uint256) public marketToGame;

    event ProviderAdded(address indexed provider);
    event ProviderRemoved(address indexed provider);
    event MarketConfigured(uint256 indexed marketId, uint256 indexed gameId);
    event ResultSubmitted(
        uint256 indexed marketId,
        uint256 indexed gameId,
        uint256 homeScore,
        uint256 awayScore,
        address indexed provider
    );
    event ResultApproved(uint256 indexed marketId, address indexed provider, uint256 approvals);
    event ResultChallenged(uint256 indexed marketId);
    event MarketResolved(uint256 indexed marketId, uint256[] winningOutcomes);

    modifier onlyAuthorized() {
        require(authorizedProviders[msg.sender], "Not authorized");
        _;
    }

    constructor(address _hook) Ownable(msg.sender) {
        hook = MultiOutcomePredictionMarketHook(_hook);
    }

    /// @notice Add an authorized data provider
    function addProvider(address _p) external onlyOwner {
        require(_p != address(0), "Zero address");
        require(!authorizedProviders[_p], "Already authorized");
        authorizedProviders[_p] = true;
        emit ProviderAdded(_p);
    }

    /// @notice Remove an authorized data provider
    function removeProvider(address _p) external onlyOwner {
        require(authorizedProviders[_p], "Not a provider");
        authorizedProviders[_p] = false;
        emit ProviderRemoved(_p);
    }

    /// @notice Map a prediction market to an external sports game (e.g. API-Football id)
    function configureMarket(uint256 marketId, uint256 gameId) external onlyOwner {
        require(gameId != 0, "Invalid gameId");
        marketToGame[marketId] = gameId;
        emit MarketConfigured(marketId, gameId);
    }

    /// @notice Submit the final result for a sports market
    /// @dev First provider to submit seeds the pending result with 1 approval
    function submitResult(
        uint256 marketId,
        uint256 homeScore,
        uint256 awayScore,
        uint256[] calldata winningOutcomes
    ) external onlyAuthorized {
        uint256 gameId = marketToGame[marketId];
        require(gameId != 0, "Game not configured");
        require(winningOutcomes.length > 0, "No outcomes");

        GameResult storage result = pendingResults[marketId];
        require(!result.finalized, "Already finalized");
        require(result.submittedAt == 0, "Already submitted");

        result.gameId = gameId;
        result.homeScore = homeScore;
        result.awayScore = awayScore;
        result.winningOutcomes = winningOutcomes;
        result.submittedAt = block.timestamp;
        result.approvals = 1;
        hasApproved[marketId][msg.sender] = true;

        emit ResultSubmitted(marketId, gameId, homeScore, awayScore, msg.sender);
        emit ResultApproved(marketId, msg.sender, 1);
    }

    /// @notice Approve a pending result; once REQUIRED_APPROVALS reached, challenge period begins
    function approveResult(uint256 marketId) external onlyAuthorized {
        GameResult storage result = pendingResults[marketId];
        require(result.submittedAt != 0, "No pending result");
        require(!result.finalized, "Already finalized");
        require(!hasApproved[marketId][msg.sender], "Already approved");

        hasApproved[marketId][msg.sender] = true;
        result.approvals += 1;

        emit ResultApproved(marketId, msg.sender, result.approvals);
    }

    /// @notice Challenge a pending result; blocks resolution pending owner review
    function challenge(uint256 marketId) external onlyOwner {
        GameResult storage result = pendingResults[marketId];
        require(result.submittedAt != 0, "No pending result");
        require(!result.finalized, "Already finalized");
        result.challenged = true;
        emit ResultChallenged(marketId);
    }

    /// @inheritdoc IOracleAdapter
    function resolveMarket(uint256 marketId) external override returns (uint256[] memory winningOutcomes) {
        GameResult storage result = pendingResults[marketId];
        require(result.submittedAt != 0, "No pending result");
        require(!result.finalized, "Already finalized");
        require(!result.challenged, "Result challenged");
        require(result.approvals >= REQUIRED_APPROVALS, "Insufficient approvals");
        require(block.timestamp >= result.submittedAt + CHALLENGE_PERIOD, "Challenge period active");

        result.finalized = true;
        winningOutcomes = result.winningOutcomes;

        hook.resolveMarket(marketId, winningOutcomes);

        emit MarketResolved(marketId, winningOutcomes);
    }

    /// @inheritdoc IOracleAdapter
    function canResolve(uint256 marketId) external view override returns (bool) {
        GameResult storage result = pendingResults[marketId];
        if (result.submittedAt == 0) return false;
        if (result.finalized) return false;
        if (result.challenged) return false;
        if (result.approvals < REQUIRED_APPROVALS) return false;
        if (block.timestamp < result.submittedAt + CHALLENGE_PERIOD) return false;

        // Check market is in Closed state
        (, MultiOutcomePredictionMarketHook.MarketState state,,,,,) = hook.getMarketSummary(marketId);
        if (state != MultiOutcomePredictionMarketHook.MarketState.Closed) return false;

        return true;
    }

    /// @inheritdoc IOracleAdapter
    function getAdapterType() external pure override returns (string memory) {
        return "sports";
    }

    /// @notice Fetch the pending winning outcomes for a market (for UI previews)
    function getPendingOutcomes(uint256 marketId) external view returns (uint256[] memory) {
        return pendingResults[marketId].winningOutcomes;
    }
}

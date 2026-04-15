// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracleAdapter} from "./IOracleAdapter.sol";
import {MultiOutcomePredictionMarketHook} from "../Hooks/MultiOutcomePredictionMarketHook.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title NewsOracleAdapter
/// @notice Oracle adapter that resolves prediction markets via authorized submitters with a challenge period
/// @dev Off-chain AVS validators submit aggregated results; a 2-of-N multisig + challenge window gate finality
contract NewsOracleAdapter is IOracleAdapter, Ownable {
    uint256 public constant CHALLENGE_PERIOD = 24 hours;
    uint256 public constant REQUIRED_APPROVALS = 2;

    MultiOutcomePredictionMarketHook public immutable hook;

    // Multi-sig set of authorized submitters (AVS validators)
    mapping(address => bool) public authorizedSubmitters;

    struct PendingResult {
        uint256[] winningOutcomes;
        string evidenceCID;
        uint256 submittedAt;
        address submitter;
        uint256 approvals;
        bool finalized;
    }

    // marketId => pending result
    mapping(uint256 => PendingResult) public pendingResults;

    // marketId => submitter => approved
    mapping(uint256 => mapping(address => bool)) public hasApproved;

    // marketId => challenged
    mapping(uint256 => bool) public challenged;

    event SubmitterAdded(address indexed submitter);
    event SubmitterRemoved(address indexed submitter);
    event ResultSubmitted(uint256 indexed marketId, address indexed submitter, uint256[] winningOutcomes, string evidenceCID);
    event ResultApproved(uint256 indexed marketId, address indexed submitter, uint256 approvals);
    event ResultChallenged(uint256 indexed marketId);
    event MarketResolved(uint256 indexed marketId, uint256[] winningOutcomes);

    constructor(address _hook) Ownable(msg.sender) {
        hook = MultiOutcomePredictionMarketHook(_hook);
    }

    /// @notice Authorize a new submitter (AVS validator)
    function addSubmitter(address _s) external onlyOwner {
        require(_s != address(0), "Zero address");
        authorizedSubmitters[_s] = true;
        emit SubmitterAdded(_s);
    }

    /// @notice Revoke a submitter's authorization
    function removeSubmitter(address _s) external onlyOwner {
        authorizedSubmitters[_s] = false;
        emit SubmitterRemoved(_s);
    }

    /// @notice Submit a result for a market; starts the challenge window
    /// @param marketId The market to resolve
    /// @param winningOutcomes Array of winning outcome indices
    /// @param evidenceCID IPFS CID (or similar) pointing to off-chain evidence
    function submitResult(
        uint256 marketId,
        uint256[] calldata winningOutcomes,
        string calldata evidenceCID
    ) external {
        require(authorizedSubmitters[msg.sender], "Not authorized");
        require(winningOutcomes.length > 0, "No outcomes");
        require(!challenged[marketId], "Market challenged");

        PendingResult storage existing = pendingResults[marketId];
        require(existing.submittedAt == 0, "Result already pending");

        pendingResults[marketId] = PendingResult({
            winningOutcomes: winningOutcomes,
            evidenceCID: evidenceCID,
            submittedAt: block.timestamp,
            submitter: msg.sender,
            approvals: 1,
            finalized: false
        });
        hasApproved[marketId][msg.sender] = true;

        emit ResultSubmitted(marketId, msg.sender, winningOutcomes, evidenceCID);
        emit ResultApproved(marketId, msg.sender, 1);
    }

    /// @notice Approve an existing pending result (counts toward REQUIRED_APPROVALS)
    function approveResult(uint256 marketId) external {
        require(authorizedSubmitters[msg.sender], "Not authorized");
        PendingResult storage pending = pendingResults[marketId];
        require(pending.submittedAt != 0, "No pending result");
        require(!pending.finalized, "Already finalized");
        require(!challenged[marketId], "Market challenged");
        require(!hasApproved[marketId][msg.sender], "Already approved");

        hasApproved[marketId][msg.sender] = true;
        pending.approvals += 1;

        emit ResultApproved(marketId, msg.sender, pending.approvals);
    }

    /// @notice Owner-initiated challenge; invalidates any pending result
    function challenge(uint256 marketId) external onlyOwner {
        challenged[marketId] = true;
        delete pendingResults[marketId];
        emit ResultChallenged(marketId);
    }

    /// @inheritdoc IOracleAdapter
    function resolveMarket(uint256 marketId) external override returns (uint256[] memory winningOutcomes) {
        PendingResult storage pending = pendingResults[marketId];
        require(pending.submittedAt != 0, "No pending result");
        require(!pending.finalized, "Already finalized");
        require(!challenged[marketId], "Market challenged");
        require(pending.approvals >= REQUIRED_APPROVALS, "Insufficient approvals");
        require(block.timestamp > pending.submittedAt + CHALLENGE_PERIOD, "Challenge period active");

        pending.finalized = true;
        winningOutcomes = pending.winningOutcomes;

        hook.resolveMarket(marketId, winningOutcomes);

        emit MarketResolved(marketId, winningOutcomes);
    }

    /// @inheritdoc IOracleAdapter
    function canResolve(uint256 marketId) external view override returns (bool) {
        PendingResult storage pending = pendingResults[marketId];
        if (pending.submittedAt == 0) return false;
        if (pending.finalized) return false;
        if (challenged[marketId]) return false;
        if (pending.approvals < REQUIRED_APPROVALS) return false;
        if (block.timestamp <= pending.submittedAt + CHALLENGE_PERIOD) return false;

        // Check market is in Closed state
        (, MultiOutcomePredictionMarketHook.MarketState state,,,,,) = hook.getMarketSummary(marketId);
        if (state != MultiOutcomePredictionMarketHook.MarketState.Closed) return false;

        return true;
    }

    /// @inheritdoc IOracleAdapter
    function getAdapterType() external pure override returns (string memory) {
        return "news";
    }

    /// @notice Read the winning outcomes of a pending result (convenience for off-chain consumers)
    function getPendingOutcomes(uint256 marketId) external view returns (uint256[] memory) {
        return pendingResults[marketId].winningOutcomes;
    }
}

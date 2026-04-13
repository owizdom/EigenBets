// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IOracleAdapter
/// @notice Interface that all oracle adapters must implement to resolve prediction markets
/// @dev Adapters bridge external data sources (Chainlink, news, sports, etc.) to market resolution
interface IOracleAdapter {
    /// @notice Resolve a market by determining the winning outcome(s)
    /// @param marketId The ID of the market to resolve
    /// @return winningOutcomes Array of outcome indices that won
    function resolveMarket(uint256 marketId) external returns (uint256[] memory winningOutcomes);

    /// @notice Check if a market can be resolved with currently available data
    /// @param marketId The ID of the market to check
    /// @return True if the adapter has sufficient data to resolve this market
    function canResolve(uint256 marketId) external view returns (bool);

    /// @notice Get the type identifier for this adapter
    /// @return A string identifying this adapter type (e.g., "chainlink_price", "news", "sports")
    function getAdapterType() external pure returns (string memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {OutcomeToken} from "./OutcomeToken.sol";

/// @title OutcomeTokenFactory
/// @notice Deploys OutcomeToken instances with deterministic addresses via CREATE2
/// @dev Used by MultiOutcomePredictionMarketHook to create N outcome tokens per market
contract OutcomeTokenFactory {
    /// @notice The authorized caller (the hook contract) that can create tokens
    address public authorizedCaller;

    /// @notice Registry of deployed tokens: keccak256(marketId, outcomeIndex) => token address
    mapping(bytes32 => address) public tokens;

    /// @notice Total number of tokens deployed
    uint256 public tokenCount;

    event TokenCreated(
        uint256 indexed marketId,
        uint256 indexed outcomeIndex,
        address token,
        string name,
        string symbol
    );

    event AuthorizedCallerSet(address caller);

    /// @notice Set the authorized caller (can only be set once, or by current caller)
    function setAuthorizedCaller(address _caller) external {
        require(authorizedCaller == address(0) || msg.sender == authorizedCaller, "Not authorized");
        authorizedCaller = _caller;
        emit AuthorizedCallerSet(_caller);
    }

    /// @notice Deploy a new outcome token with a deterministic address
    /// @param marketId The market this token belongs to
    /// @param outcomeIndex The index of this outcome within the market
    /// @param name Token name (e.g., "Team A Wins")
    /// @param symbol Token symbol (e.g., "TEAMA")
    /// @param initialSupply Total supply to mint
    /// @param recipient Address to receive the minted tokens
    /// @return token The deployed token address
    function createToken(
        uint256 marketId,
        uint256 outcomeIndex,
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address recipient
    ) external returns (address token) {
        require(msg.sender == authorizedCaller, "Unauthorized");

        bytes32 key = keccak256(abi.encodePacked(marketId, outcomeIndex));
        require(tokens[key] == address(0), "Token already exists");

        bytes32 salt = keccak256(abi.encodePacked(marketId, outcomeIndex, name, symbol));

        OutcomeToken deployed = new OutcomeToken{salt: salt}(
            name,
            symbol,
            initialSupply,
            recipient
        );

        token = address(deployed);
        tokens[key] = token;
        tokenCount++;

        emit TokenCreated(marketId, outcomeIndex, token, name, symbol);
    }

    /// @notice Get the address of a previously deployed token
    /// @param marketId The market ID
    /// @param outcomeIndex The outcome index
    /// @return The token address, or address(0) if not deployed
    function getToken(uint256 marketId, uint256 outcomeIndex) external view returns (address) {
        return tokens[keccak256(abi.encodePacked(marketId, outcomeIndex))];
    }

    /// @notice Predict the address a token will be deployed to
    /// @param marketId The market ID
    /// @param outcomeIndex The outcome index
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param initialSupply Total supply
    /// @param recipient Mint recipient
    /// @return The predicted address
    function predictTokenAddress(
        uint256 marketId,
        uint256 outcomeIndex,
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address recipient
    ) external view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(marketId, outcomeIndex, name, symbol));
        bytes memory bytecode = abi.encodePacked(
            type(OutcomeToken).creationCode,
            abi.encode(name, symbol, initialSupply, recipient)
        );
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode))
        );
        return address(uint160(uint256(hash)));
    }
}

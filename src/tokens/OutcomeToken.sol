// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@solmate/tokens/ERC20.sol";

/// @title OutcomeToken
/// @notice Generic ERC20 token representing a prediction market outcome
/// @dev Mints a fixed supply to the deployer (typically the factory or hook contract)
contract OutcomeToken is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        address _recipient
    ) ERC20(_name, _symbol, 18) {
        _mint(_recipient, _initialSupply);
    }
}

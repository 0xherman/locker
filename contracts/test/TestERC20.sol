// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

/// @title RetroMoonToken
/// @notice RetroMoonToken Contract implementing ERC20 standard
/// @dev To be deployed as RetroMoonToken token for use in RetroMoon games.
///		PancakeRouter should be defined post creation.
///		PancakePair should be defined post launch.
contract TestERC20 is ERC20PresetFixedSupply {

	constructor(string memory name, string memory symbol, uint256 initialSupply, address owner)
		ERC20PresetFixedSupply(name, symbol, initialSupply, owner) { }
}
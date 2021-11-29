// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;


/// @title ITokenLockFactory
/// @notice ITokenLockFactory Contract Interface for Retromoon liquidity / token locks
interface ITokenLockFactory {
	/// Create a new lock with unlockDate
	function createLock(uint256 unlockDate) payable external returns (address);

	/// Transfer stored data on lock ownership (does not actually change owners on the lock)
	function transferLock(address payable lockAddress, address oldOwner) external;

	/// Add a lock to token cache
	function trackToken(address payable lockAddress, address tokenAddress) external;

	/// Remove a lock from token cache
	function untrackToken(address payable lockAddress, address tokenAddress) external;
}
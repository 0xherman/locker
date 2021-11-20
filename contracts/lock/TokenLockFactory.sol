// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./TokenLock.sol";

/// @title TokenLockFactory
/// @notice TokenLockFactory Contract for Retromoon liquidity / token locks
contract TokenLockFactory {

	/// Create lock event to emit on creation
	/// @param newLock The new lock's address
	/// @param unlockDate The new lock's unlock date
	event LockCreated(address newLock, uint256 unlockDate);

	/// Create a new lock with unlockDate
	/// @param unlockDate The lock's unlock date
	function createLock(uint256 unlockDate) external returns (address) {
		require(unlockDate > block.timestamp, "TokenLockFactory: new lock unlock date must be in the future");
		TokenLock newLock = new TokenLock(address(this));
		newLock.extendUnlockDate(unlockDate);
		emit LockCreated(address(newLock), unlockDate);
		return address(newLock);
	}
}
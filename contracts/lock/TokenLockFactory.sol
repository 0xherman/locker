// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./TokenLock.sol";

/// @title TokenLockFactory
/// @notice TokenLockFactory Contract for Retromoon liquidity / token locks
contract TokenLockFactory is Ownable {
	using EnumerableSet for EnumerableSet.AddressSet;

	uint256 public fee;

	mapping(address => EnumerableSet.AddressSet) private _locksByToken;
	mapping(address => EnumerableSet.AddressSet) private _locksByAccount;

	/// Create lock event to emit on creation
	/// @param newLock The new lock's address
	/// @param tokenAddress, The ERC20 token's address
	/// @param unlockDate The new lock's unlock date
	event LockCreated(address newLock, address tokenAddress, uint256 unlockDate);

	/// Given a token address, get addresses of locks for the token
	function getLocksByToken(address tokenAddress) external view returns (address[] memory) {
		return EnumerableSet.values(_locksByToken[tokenAddress]);
	}

	/// Given an account, get address of locks owned by account
	function getLocksByAccount(address account) external view returns (address[] memory) {
		return EnumerableSet.values(_locksByAccount[account]);
	}

	/// Create a new lock with unlockDate
	/// @param unlockDate The lock's unlock date
	function createLock(address tokenAddress, uint256 unlockDate) payable external returns (address) {
		require(msg.value >= fee, "TokenLockFactory: value is less than required fee");
		require(unlockDate > block.timestamp, "TokenLockFactory: new lock unlock date must be in the future");
		_locksByAccount[_msgSender()].add(tokenAddress);
		TokenLock newLock = new TokenLock(address(this), tokenAddress);
		_locksByToken[tokenAddress].add(address(newLock));
		newLock.extendUnlockDate(unlockDate);
		emit LockCreated(address(newLock), tokenAddress, unlockDate);
		return address(newLock);
	}

	/// Transfer stored data on lock ownership (does not actually change owners on the lock)
	/// @dev Assumed the call is made by previous lock owner, so removes lock from _msgSender mapping
	/// @param lockAddress The lock address to ensure owner mapping is correct
	function transferLock(address payable lockAddress) external {
		TokenLock lock = TokenLock(lockAddress);
		address owner = lock.owner();
		_locksByAccount[owner].add(lockAddress);
		_locksByAccount[_msgSender()].remove(lockAddress);
	}

	/// Set lock creation fee
	function setFee(uint256 _fee) external onlyOwner {
		fee = _fee;
	}
}
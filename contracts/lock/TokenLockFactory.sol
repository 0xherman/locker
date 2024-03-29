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
	mapping(string => address) private _customNames;

	EnumerableSet.AddressSet private _approvedFactories;

	/// Create lock event to emit on creation
	/// @param newLock The new lock's address
	/// @param owner, The new lock's owner
	/// @param unlockDate The new lock's unlock date
	event LockCreated(address newLock, address owner, uint256 unlockDate);

	/// Receive funds on contract
	receive() external payable {}

	/// PUBLIC VIEWS ///

	/// Given a token address, get addresses of locks for the token
	function getLocksByToken(address tokenAddress) external view returns (address[] memory) {
		return _locksByToken[tokenAddress].values();
	}

	/// Given an account, get address of locks owned by account
	function getLocksByAccount(address account) external view returns (address[] memory) {
		return _locksByAccount[account].values();
	}

	/// Given a custom name return the lock address
	function getLockByName(string memory name) external view returns (address) {
		return _customNames[name];
	}


	/// PUBLIC FUNCTIONS ///

	/// Create a new lock with unlockDate
	/// @param unlockDate The lock's unlock date
	function createLock(uint256 unlockDate) payable external returns (address) {
		require(msg.value >= fee, "TokenLockFactory: value is less than required fee");
		require(unlockDate > block.timestamp, "TokenLockFactory: new lock unlock date must be in the future");
		TokenLock newLock = new TokenLock(payable(this), unlockDate, _msgSender());
		_locksByAccount[_msgSender()].add(address(newLock));
		emit LockCreated(address(newLock), _msgSender(), unlockDate);
		return address(newLock);
	}


	/// CACHE UPDATES ///

	/// Transfer stored data on lock ownership (does not actually change owners on the lock)
	/// @dev Assumed the call is made by previous lock owner
	/// @param lockAddress The lock address to ensure owner mapping is correct
	/// @param oldOwner The old owner to try to remove
	function transferLock(address payable lockAddress, address oldOwner) external {
		address owner = TokenLock(lockAddress).owner();
		_locksByAccount[oldOwner].remove(lockAddress);
		_locksByAccount[owner].add(lockAddress);
	}

	/// Add a lock to token cache
	function trackToken(address payable lockAddress, address tokenAddress) external {
		require(TokenLock(lockAddress).hasToken(tokenAddress), "TokenLockFactory: lock is not tracking given address");
		_locksByToken[tokenAddress].add(lockAddress);
	}

	/// Remove a lock from token cache
	function untrackToken(address payable lockAddress, address tokenAddress) external {
		require(!TokenLock(lockAddress).hasToken(tokenAddress), "TokenLockFactory: lock is tracking given address");
		_locksByToken[tokenAddress].remove(lockAddress);
	}


	/// LOCK ADMINISTRATION ///

	/// Change factory address
	function changeFactory(address payable lockAddress, address payable factoryAddress) external {
		require(_approvedFactories.contains(factoryAddress), "TokenLockFactory: factory is not valid");
		require(TokenLock(lockAddress).owner() == _msgSender(), "TokenLockFactory: caller is not lock owner");
		TokenLock(lockAddress).changeFactory(factoryAddress);
	}

	/// Change factory address
	function setCustomName(address payable lockAddress, string memory name) payable external {
		require(msg.value >= fee, "TokenLockFactory: value is less than required fee");
		require(TokenLock(lockAddress).owner() == _msgSender(), "TokenLockFactory: caller is not lock owner");
		require(_customNames[name] == address(0), "TokenLockFactory: custom name is already in use");
		_customNames[name] = lockAddress;
	}


	/// FACTORY ADMINISTRATION ///

	/// Set lock creation fee
	function setFee(uint256 _fee) external onlyOwner {
		fee = _fee;
	}

	/// Override a custom name in case of misuse
	function overrideCustomName(address lockAddress, string memory name) external onlyOwner {
		_customNames[name] = lockAddress;
	}

	/// Add approved factory
	function addApprovedFactory(address factoryAddress) external onlyOwner {
		_approvedFactories.add(factoryAddress);
	}

	/// Remove approved factory
	function removeApprovedFactory(address factoryAddress) external onlyOwner {
		_approvedFactories.remove(factoryAddress);
	}

	/// Withdraw native token to recipient address
	/// @param amount The amount of native currency to withdraw
	/// @param recipient The recipient of the withdrawn funds
	function withdraw(uint256 amount, address recipient) external onlyOwner returns (bool success) {
		require(amount <= address(this).balance, "TokenLock: not enough held in lock");
		(success,) = payable(recipient).call{value: amount}("");
	}
}
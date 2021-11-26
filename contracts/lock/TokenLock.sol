// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./TokenLockFactory.sol";

/// @title TokenLock
/// @notice TokenLock Contract for Retromoon liquidity / token lock
contract TokenLock is AccessControlEnumerable, Ownable {
	using EnumerableSet for EnumerableSet.AddressSet;

	// Define access roles
	bytes32 public constant EXTEND_ROLE = keccak256("EXTEND_ROLE");
	bytes32 public constant UNLOCK_ROLE = keccak256("UNLOCK_ROLE");

	uint256 public unlockDate;
	EnumerableSet.AddressSet private _tokens;

	/// Factory address
	address payable private _factory;

	/// Events to emit after value changes
	event UnlockDateExtended(uint256 unlockDate);
	event Unlocked(uint256 amount, address recipient);
	event TokensUnlocked(address tokenAddress, uint256 amount, address recipient);
	event LockSplit(uint256 amount, address newLock);
	event TokenLockSplit(address tokenAddress, uint256 amount, address newTokenLock);
	event TokenLockMigrated(address oldLock, address newLock);
	event TokenTracked(address tokenAddress);
	event TokenUntracked(address tokenAddress);

	/// Modifier to require extend or admin role
	modifier canExtend() {
		require(hasRole(EXTEND_ROLE, _msgSender()) || hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "TokenLock: caller does not have extend role");
		_;
	}

	/// Modifier to require unlock or admin role and current timestamp to be later than unlock date
	modifier canUnlock() {
		require(hasRole(UNLOCK_ROLE, _msgSender()) || hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "TokenLock: caller does not have unlock role");
		require(block.timestamp > unlockDate, "TokenLock: recipient is not allowed to unlock at this time");
		_;
	}

	/// Modifier to require admin role or ownership
	modifier canMove() {
		require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()) || owner() == _msgSender(), "TokenLock: caller does not have admin role");
		_;
	}

	/// Create lock with link to original factory
	constructor(address payable factory, uint256 _unlockDate, address owner) {
		require(_unlockDate > block.timestamp, "TokenLock: new date must be in the future");
		_factory = factory;
		unlockDate = _unlockDate;

		// Define administrator roles that can add/remove from given roles
		_setRoleAdmin(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
		_setRoleAdmin(EXTEND_ROLE, DEFAULT_ADMIN_ROLE);
		_setRoleAdmin(UNLOCK_ROLE, DEFAULT_ADMIN_ROLE);

		// Add deployer to all roles
		_setupRole(DEFAULT_ADMIN_ROLE, owner);
		_setupRole(EXTEND_ROLE, owner);
		_setupRole(UNLOCK_ROLE, owner);
		if (owner != _msgSender()) {
			super.transferOwnership(owner);
		}
	}

	/// Receive funds on contract
	receive() external payable {}

	/// Check if lock has a token tracked
	function hasToken(address tokenAddress) external view returns (bool) {
		return _tokens.contains(tokenAddress);
	}

	/// Get tracked tokens
	function getTokens() external view returns (address[] memory) {
		return _tokens.values();
	}

	/// Get tracked token at index
	function getToken(uint256 index) external view returns (address) {
		return _tokens.at(index);
	}

	/// Get number of tracked tokens
	function getTokenCount() external view returns (uint256) {
		return _tokens.length();
	}

	/// Extend unlock date
	/// @param date The new unlock date
	function extendUnlockDate(uint256 date) external canExtend {
		require(date > unlockDate, "TokenLock: new date must be later than current unlock date");
		require(date > block.timestamp, "TokenLock: new date must be in the future");
		unlockDate = date;
		emit UnlockDateExtended(date);
	}

	/// Withdraw native token to recipient address
	/// @param amount The amount of native currency to withdraw
	/// @param recipient The recipient of the withdrawn funds
	function unlock(uint256 amount, address recipient) external canUnlock returns (bool success) {
		require(amount <= address(this).balance, "TokenLock: not enough held in lock");
		(success,) = payable(recipient).call{value: amount}("");
		emit Unlocked(amount, recipient);
	}

	/// Withdraw token to recipient address
	/// @param tokenAddress The ERC20 token address to withdraw
	/// @param amount The amount of the token to withdraw
	/// @param recipient The recipient of the withdrawn funds
	function unlockToken(address tokenAddress, uint256 amount, address recipient) external canUnlock {
		require(IERC20(tokenAddress).balanceOf(address(this)) >= amount, "TokenLock: not enough tokens held in lock");
		IERC20(tokenAddress).transfer(recipient, amount);
		emit TokensUnlocked(tokenAddress, amount, recipient);
	}

	/// Split a token from this current lock out into a new lock contract
	/// Retains original owner and lock date
	/// @param tokenAddress The ERC20 token to split into new lock
	/// @param amount The amount of the token to split into new lock
	/// @param _unlockDate The split lock unlock date
	/// @return newLock The address of the new lock
	function splitTokenLock(address tokenAddress, uint256 amount, uint256 _unlockDate) payable external canMove returns (address newLock) {
		require(IERC20(tokenAddress).balanceOf(address(this)) >= amount, "TokenLock: not enough tokens held in lock");
		require(_unlockDate >= unlockDate, "TokenLock: new lock unlock date cannot be before current lock unlock date");
		require(_unlockDate > block.timestamp, "TokenLock: new lock unlock date must be in the future");
		newLock = TokenLockFactory(_factory).createLock{value: msg.value}(unlockDate);
		TokenLock(payable(newLock)).trackToken(tokenAddress);
		IERC20(tokenAddress).transfer(newLock, amount);
		emit TokenLockSplit(tokenAddress, amount, newLock);
	}

	/// Migrate a lock completely to a new lock
	function migrateTokenLock() payable external canMove returns (address newLock) {
		newLock = TokenLockFactory(_factory).createLock{value: msg.value}(unlockDate);
		uint256 length = _tokens.length();
		for (uint256 i = 0; i < length; i++) {
			TokenLock(payable(newLock)).trackToken(_tokens.at(i));
			IERC20 token = IERC20(_tokens.at(i));
			uint256 amount = token.balanceOf(address(this));
			token.transfer(newLock, amount);
		}
		emit TokenLockMigrated(address(this), newLock);
	}

	/// Add a token to tracked list
	function trackToken(address tokenAddress) external onlyOwner {
		_tokens.add(tokenAddress);
		TokenLockFactory(_factory).trackToken(payable(this), tokenAddress);
		emit TokenTracked(tokenAddress);
	}

	/// Remove a tracked token from liest
	function untrackToken(address tokenAddress) external onlyOwner {
		_tokens.remove(tokenAddress);
		TokenLockFactory(_factory).untrackToken(payable(this), tokenAddress);
		emit TokenUntracked(tokenAddress);
	}

	/// Add new owner to roles and remove self from roles
	/// @inheritdoc Ownable
	function transferOwnership(address newOwner) public override onlyOwner {
		super.transferOwnership(newOwner);
		grantRole(DEFAULT_ADMIN_ROLE, newOwner);
		grantRole(EXTEND_ROLE, newOwner);
		grantRole(UNLOCK_ROLE, newOwner);
		
		revokeRole(EXTEND_ROLE, _msgSender());
		revokeRole(UNLOCK_ROLE, _msgSender());
		revokeRole(DEFAULT_ADMIN_ROLE, _msgSender());
		TokenLockFactory(_factory).transferLock(payable(this), _msgSender());
	}

	/// Update the factory address
	function changeFactory(address payable factoryAddress) external {
		require(_msgSender() == _factory, "TokenLock: only the factory can update factory address");
		_factory = factoryAddress;
	}
}
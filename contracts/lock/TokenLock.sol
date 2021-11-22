// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./TokenLockFactory.sol";

/// @title TokenLock
/// @notice TokenLock Contract for Retromoon liquidity / token lock
contract TokenLock is AccessControlEnumerable, Ownable {

	// Define access roles
	bytes32 public constant EXTEND_ROLE = keccak256("EXTEND_ROLE");
	bytes32 public constant UNLOCK_ROLE = keccak256("UNLOCK_ROLE");

	uint256 public unlockDate;
	IERC20 token;

	/// Factory address
	address private _factory;

	/// Unlock date extended event to emit after extension
	event UnlockDateExtended(uint256 unlockDate);

	/// Native currency withdrawn event to emit after withdraw
	event Unlocked(uint256 amount, address recipient);

	/// Tokens unlocked event to emit after withdraw
	event TokensUnlocked(address tokenAddress, uint256 amount, address recipient);

	/// Lock split event to emit after split
	event LockSplit(uint256 amount, address newLock);

	/// Token lock split event to emit after split
	event TokenLockSplit(address tokenAddress, uint256 amount, address newTokenLock);

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
	modifier canSplit() {
		require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()) || owner() == _msgSender(), "TokenLock: caller does not have admin role");
		_;
	}

	/// Create lock with link to original factory
	constructor(address factory, address tokenAddress) {
		_factory = factory;
		token = IERC20(tokenAddress);

		// Define administrator roles that can add/remove from given roles
		_setRoleAdmin(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
		_setRoleAdmin(EXTEND_ROLE, DEFAULT_ADMIN_ROLE);
		_setRoleAdmin(UNLOCK_ROLE, DEFAULT_ADMIN_ROLE);

		// Add deployer to all roles
		_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
		_setupRole(EXTEND_ROLE, _msgSender());
		_setupRole(UNLOCK_ROLE, _msgSender());
	}

	/// Receive funds on contract
	receive() external payable {}

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
	function splitTokenLock(address tokenAddress, uint256 amount, uint256 _unlockDate) payable external canSplit returns (address newLock) {
		require(IERC20(tokenAddress).balanceOf(address(this)) >= amount, "TokenLock: not enough tokens held in lock");
		require(_unlockDate >= unlockDate, "TokenLock: new lock unlock date cannot be before current lock unlock date");
		require(_unlockDate > block.timestamp, "TokenLock: new lock unlock date must be in the future");
		newLock = TokenLockFactory(_factory).createLock{value: msg.value}(tokenAddress, unlockDate);
		IERC20(tokenAddress).transfer(newLock, amount);
		emit TokenLockSplit(tokenAddress, amount, newLock);
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
		TokenLockFactory(_factory).transferLock(payable(this));
	}
}
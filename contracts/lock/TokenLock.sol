// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./TokenLockFactory.sol";

/// @title TokenLock
/// @notice TokenLock Contract for Retromoon liquidity / token lock
contract TokenLock is Ownable {

	/// Visible unlock date to 
	uint256 public unlockDate;

	/// Factory address
	address private _factory;

	/// Native currency withdrawn event to emit after withdraw
	/// @param amount The amount of native currency withdrawn
	/// @param recipient The recipient of withdrawn funds
	event Withdrawn(uint256 amount, address recipient);

	/// Tokens withdrawn event to emit after withdraw
	/// @param tokenAddress The ERC20 token address withdrawn
	/// @param amount The amount of token withdrawn
	/// @param recipient The recipient of withdrawn funds
	event TokensWithdrawn(address tokenAddress, uint256 amount, address recipient);

	/// Unlock date extended event to emit after extension
	/// @param unlockDate The new unlock date
	event UnlockDateExtended(uint256 unlockDate);

	/// Lock split event to emit after split
	/// @param amount The amount of funds to split into new lock
	/// @param newLock The address of the new lock
	event LockSplit(uint256 amount, address newLock);

	/// Token lock split event to emit after split
	/// @param tokenAddress The ERC20 token address to split
	/// @param amount The amount of tokens to split into new lock
	/// @param newTokenLock The address of the new token lock
	event TokenLockSplit(address tokenAddress, uint256 amount, address newTokenLock);

	/// Modifier to require current timestamp to be later than unlock date
	modifier canWithdraw() {
		require(block.timestamp > unlockDate, "TokenLock: recipient is not allowed to withdraw at this time");
		_;
	}

	/// Create lock with link to original factory
	constructor(address factory) {
		_factory = factory;
	}

	/// Receive funds on contract
	receive() external payable {}

	/// Extend unlock date
	/// @param date The new unlock date
	function extendUnlockDate(uint256 date) external onlyOwner {
		require(date > unlockDate, "TokenLock: new date must be later than current unlock date");
		require(date > block.timestamp, "TokenLock: new date must be in the future");
		unlockDate = date;
		emit UnlockDateExtended(date);
	}

	/// Withdraw native token to recipient address
	/// @param amount The amount of native currency to withdraw
	/// @param recipient The recipient of the withdrawn funds
	function withdraw(uint256 amount, address recipient) external onlyOwner canWithdraw returns (bool success) {
		require(amount <= address(this).balance, "TokenLock: not enough held in lock");
		(success,) = payable(recipient).call{value: amount}("");
		emit Withdrawn(amount, recipient);
	}

	/// Withdraw token to recipient address
	/// @param tokenAddress The ERC20 token address to withdraw
	/// @param amount The amount of the token to withdraw
	/// @param recipient The recipient of the withdrawn funds
	function withdrawToken(address tokenAddress, uint256 amount, address recipient) external onlyOwner canWithdraw {
		require(IERC20(tokenAddress).balanceOf(address(this)) >= amount, "TokenLock: not enough tokens held in lock");
		IERC20(tokenAddress).transfer(recipient, amount);
		emit TokensWithdrawn(tokenAddress, amount, recipient);
	}

	/// Split funds from this current lock out into a new lock contract
	/// Retains original owner and lock date
	/// @param amount The amount of funds to split into new lock
	function splitLock(uint256 amount) external onlyOwner returns (bool success, address newLock) {
		require(amount <= address(this).balance, "TokenLock: not enough held in lock");
		newLock = TokenLockFactory(_factory).createLock(unlockDate);
		(success, ) = payable(newLock).call{value: amount}("");
		emit LockSplit(amount, newLock);
	}

	/// Split a token from this current lock out into a new lock contract
	/// Retains original owner and lock date
	/// @param tokenAddress The ERC20 token to split into new lock
	/// @param amount The amount of the token to split into new lock
	/// @return newLock The address of the new lock
	function splitTokenLock(address tokenAddress, uint256 amount) external onlyOwner returns (address newLock) {
		require(IERC20(tokenAddress).balanceOf(address(this)) >= amount, "TokenLock: not enough tokens held in lock");
		newLock = TokenLockFactory(_factory).createLock(unlockDate);
		IERC20(tokenAddress).transfer(newLock, amount);
		emit TokenLockSplit(tokenAddress, amount, newLock);
	}
}
// We import Chai to use its asserting functions here.
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TokenLock", function () {

  let tokenLock;
  let token;
  let owner;
  let addr1;
  let addr2;
  let addrs;
  let block;
  let DEFAULT_ADMIN_ROLE;
  let UNLOCK_ROLE;
  let EXTEND_ROLE;


  async function deploy() {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("TestERC20");
    token = await Token.deploy("Test", "TEST", 100000, owner.address);

    const TokenLockFactory = await ethers.getContractFactory("TokenLockFactory");
    const factory = await TokenLockFactory.deploy();

    const TokenLock = await ethers.getContractFactory("TokenLock");
    tokenLock = await TokenLock.deploy(factory.address, token.address);
    DEFAULT_ADMIN_ROLE = await tokenLock.DEFAULT_ADMIN_ROLE();
    UNLOCK_ROLE = await tokenLock.UNLOCK_ROLE();
    EXTEND_ROLE = await tokenLock.EXTEND_ROLE();

    block = await ethers.provider.getBlock();
  }

  beforeEach(deploy);

  describe("extendUnlockDate", () => {
    it("Should revert if not in any roles", async () => {
      await expect(tokenLock.connect(addr1).extendUnlockDate(block.timestamp + 100))
        .to.be.revertedWith("TokenLock: caller does not have extend role");
      
    });

    it("Should revert if owner with no roles", async () => {
      await tokenLock.revokeRole(EXTEND_ROLE, owner.address);
      await tokenLock.revokeRole(UNLOCK_ROLE, owner.address);
      await tokenLock.revokeRole(DEFAULT_ADMIN_ROLE, owner.address);
      await expect(tokenLock.extendUnlockDate(block.timestamp + 100))
        .to.be.revertedWith("TokenLock: caller does not have extend role");
    });

    it("Should revert with UNLOCK_ROLE", async () => {
      await tokenLock.grantRole(UNLOCK_ROLE, addr1.address);
      await expect(tokenLock.connect(addr1).extendUnlockDate(block.timestamp + 100))
        .to.be.revertedWith("TokenLock: caller does not have extend role");
    });

    it("Should revert if in the past", async () => {
      await expect(tokenLock.extendUnlockDate(block.timestamp - 100))
        .to.be.revertedWith("TokenLock: new date must be in the future");
    });

    it("Should update if in DEFAULT_ADMIN_ROLE and emit an event", async () => {
      await tokenLock.grantRole(DEFAULT_ADMIN_ROLE, addr1.address)
      await expect(tokenLock.connect(addr1).extendUnlockDate(block.timestamp + 100))
        .to.emit(tokenLock, "UnlockDateExtended")
        .withArgs(block.timestamp + 100);
      expect(await tokenLock.unlockDate()).to.equal(block.timestamp + 100);
    });

    it("Should update if in EXTEND_ROLE and emit an event", async () => {
      await tokenLock.grantRole(EXTEND_ROLE, addr1.address);
      await expect(tokenLock.connect(addr1).extendUnlockDate(block.timestamp + 100))
        .to.emit(tokenLock, "UnlockDateExtended")
        .withArgs(block.timestamp + 100);
      expect(await tokenLock.unlockDate()).to.equal(block.timestamp + 100);
    });
  });

  describe("unlock", () => {
    it("Should revert if not in any roles", async () => {
      await expect(tokenLock.connect(addr1).unlock(100, addr2.address))
        .to.be.revertedWith("TokenLock: caller does not have unlock role");
    });

    it("Should revert if owner with no roles", async () => {
      await tokenLock.revokeRole(EXTEND_ROLE, owner.address);
      await tokenLock.revokeRole(UNLOCK_ROLE, owner.address);
      await tokenLock.revokeRole(DEFAULT_ADMIN_ROLE, owner.address);
      await expect(tokenLock.unlock(100, addr2.address))
        .to.be.revertedWith("TokenLock: caller does not have unlock role");
    });

    it("Should revert with EXTEND_ROLE", async () => {
      await tokenLock.grantRole(EXTEND_ROLE, addr1.address);
      await expect(tokenLock.connect(addr1).unlock(100, addr2.address))
        .to.be.revertedWith("TokenLock: caller does not have unlock role");
    });

    it("Should revert if before the unlock date", async () => {
      await tokenLock.extendUnlockDate(block.timestamp + 1000);
      await owner.sendTransaction({ to: tokenLock.address, value: ethers.utils.parseEther("1.0") });
      
      await expect(tokenLock.unlock(ethers.utils.parseEther("1.0"), addr2.address))
        .to.be.revertedWith("TokenLock: recipient is not allowed to unlock at this time");
    });

    it("Should revert if not enough funds", async () => {
      await expect(tokenLock.unlock(100, addr2.address))
        .to.be.revertedWith("TokenLock: not enough held in lock");
    });    

    it("Should transfer funds if unlocked and DEFAULT_ADMIN_ROLE and emit an event", async () => {
      await tokenLock.grantRole(DEFAULT_ADMIN_ROLE, addr1.address);
      await owner.sendTransaction({ to: tokenLock.address, value: ethers.utils.parseEther("1.0") });
      
      await expect(tokenLock.connect(addr1).unlock(ethers.utils.parseEther("1.0"), addr2.address))
        .to.emit(tokenLock, "Unlocked")
        .withArgs(ethers.utils.parseEther("1.0"), addr2.address);
    });

    it("Should transfer funds if unlocked and EXTEND_ROLE and emit an event", async () => {
      await tokenLock.grantRole(UNLOCK_ROLE, addr1.address);
      await owner.sendTransaction({ to: tokenLock.address, value: ethers.utils.parseEther("1.0") });
      
      const preBalance = await addr2.getBalance();
      await expect(tokenLock.connect(addr1).unlock(ethers.utils.parseEther("1.0"), addr2.address))
        .to.emit(tokenLock, "Unlocked")
        .withArgs(ethers.utils.parseEther("1.0"), addr2.address);
      await expect(await addr2.getBalance()).to.equal(preBalance.add(ethers.utils.parseEther("1.0")));
    });
  });

  describe("unlockToken", () => {
    it("Should revert if not in any roles", async () => {
      await token.transfer(tokenLock.address, 500);
      await expect(tokenLock.connect(addr1).unlockToken(token.address, 100, addr2.address))
        .to.be.revertedWith("TokenLock: caller does not have unlock role");
    });

    it("Should revert if owner with no roles", async () => {
      await tokenLock.revokeRole(EXTEND_ROLE, owner.address);
      await tokenLock.revokeRole(UNLOCK_ROLE, owner.address);
      await tokenLock.revokeRole(DEFAULT_ADMIN_ROLE, owner.address);
      await expect(tokenLock.unlockToken(token.address, 100, addr2.address))
        .to.be.revertedWith("TokenLock: caller does not have unlock role");
    });

    it("Should revert with EXTEND_ROLE", async () => {
      await token.transfer(tokenLock.address, 500);
      await tokenLock.grantRole(EXTEND_ROLE, addr1.address);
      await expect(tokenLock.connect(addr1).unlockToken(token.address, 100, addr2.address))
        .to.be.revertedWith("TokenLock: caller does not have unlock role");
    });

    it("Should revert if before the unlock date", async () => {
      await token.transfer(tokenLock.address, 500);
      await tokenLock.extendUnlockDate(block.timestamp + 1000);
      await owner.sendTransaction({ to: tokenLock.address, value: ethers.utils.parseEther("1.0") });
      
      await expect(tokenLock.unlockToken(token.address, ethers.utils.parseEther("1.0"), addr2.address))
        .to.be.revertedWith("TokenLock: recipient is not allowed to unlock at this time");
    });

    it("Should revert if not enough tokens", async () => {
      await expect(tokenLock.unlockToken(token.address, 100, addr2.address))
        .to.be.revertedWith("TokenLock: not enough tokens held in lock");
    });    

    it("Should transfer tokens if unlocked and DEFAULT_ADMIN_ROLE and emit an event", async () => {
      await token.transfer(tokenLock.address, 500);
      await tokenLock.grantRole(DEFAULT_ADMIN_ROLE, addr1.address);
      
      await expect(tokenLock.connect(addr1).unlockToken(token.address, 500, addr2.address))
        .to.emit(tokenLock, "TokensUnlocked")
        .withArgs(token.address, 500, addr2.address);
      expect(await token.balanceOf(addr2.address)).to.equal(500);
    });

    it("Should transfer tokens if unlocked and EXTEND_ROLE and emit an event", async () => {
      await token.transfer(tokenLock.address, 500);
      await tokenLock.grantRole(UNLOCK_ROLE, addr1.address);
      
      await expect(tokenLock.connect(addr1).unlockToken(token.address, 500, addr2.address))
        .to.emit(tokenLock, "TokensUnlocked")
        .withArgs(token.address, 500, addr2.address);
      await expect(await token.balanceOf(addr2.address)).to.equal(500);
    });
  });

  describe("splitTokenLock", () => {
    it("Should revert if not in any roles", async () => {
      await token.transfer(tokenLock.address, 500);
      await expect(tokenLock.connect(addr1).splitTokenLock(token.address, 100, block.timestamp + 1000))
        .to.be.revertedWith("TokenLock: caller does not have admin role");
    });

    it("Should revert with EXTEND_ROLE", async () => {
      await token.transfer(tokenLock.address, 500);
      await tokenLock.grantRole(EXTEND_ROLE, addr1.address);
      await expect(tokenLock.connect(addr1).splitTokenLock(token.address, 100, block.timestamp + 1000))
        .to.be.revertedWith("TokenLock: caller does not have admin role");
    });

    it("Should revert with UNLOCK_ROLE", async () => {
      await token.transfer(tokenLock.address, 500);
      await tokenLock.grantRole(UNLOCK_ROLE, addr1.address);
      await expect(tokenLock.connect(addr1).splitTokenLock(token.address, 100, block.timestamp + 1000))
        .to.be.revertedWith("TokenLock: caller does not have admin role");
    });

    it("Should revert if before current lock unlock date", async () => {
      await token.transfer(tokenLock.address, 500);
      await tokenLock.extendUnlockDate(block.timestamp + 10000);
      await expect(tokenLock.splitTokenLock(token.address, 100, block.timestamp + 9999))
        .to.be.revertedWith("TokenLock: new lock unlock date cannot be before current lock unlock date");
    });

    it("Should revert if after the unlock date", async () => {
      await token.transfer(tokenLock.address, 500);
      await expect(tokenLock.splitTokenLock(token.address, 100, block.timestamp))
        .to.be.revertedWith("TokenLock: new lock unlock date must be in the future");
    });

    it("Should revert if not enough funds", async () => {
      await expect(tokenLock.splitTokenLock(token.address, 100, block.timestamp + 1000))
        .to.be.revertedWith("TokenLock: not enough tokens held in lock");
    });

    it("Should split lock if valid and DEFAULT_ADMIN_ROLE and emit an event", async () => {
      await tokenLock.extendUnlockDate(block.timestamp + 100);
      await token.transfer(tokenLock.address, 500);
      let newLock = await expect(tokenLock.splitTokenLock(token.address, 250, block.timestamp + 1000))
        .to.emit(tokenLock, "LockSplit");

      expect(await token.balanceOf(newLock)).to.equal(250);
      expect(await token.balanceOf(tokenLock.address)).to.equal(250);
    });
  });
});
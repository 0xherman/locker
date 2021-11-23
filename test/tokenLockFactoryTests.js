// We import Chai to use its asserting functions here.
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TokenLockFactory", function () {

  let Token;
  let TokenLock;
  let tokenLock;
  let lockFactory;
  let token;
  let owner;
  let addr1;
  let addr2;
  let addrs;
  let block;
  let DEFAULT_ADMIN_ROLE;
  let UNLOCK_ROLE;
  let EXTEND_ROLE;

  beforeEach(async () => {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    block = await ethers.provider.getBlock();

    Token = await ethers.getContractFactory("TestERC20");
    token = await Token.deploy("Test", "TEST", 100000, owner.address);

    const TokenLockFactory = await ethers.getContractFactory("TokenLockFactory");
    lockFactory = await TokenLockFactory.deploy();

    TokenLock = await ethers.getContractFactory("TokenLock");
    tokenLock = await TokenLock.deploy(lockFactory.address, block.timestamp + 100, owner.address);
    DEFAULT_ADMIN_ROLE = await tokenLock.DEFAULT_ADMIN_ROLE();
    UNLOCK_ROLE = await tokenLock.UNLOCK_ROLE();
    EXTEND_ROLE = await tokenLock.EXTEND_ROLE();

    block = await ethers.provider.getBlock();
  });

  describe("getLocksByToken", () => {
    it("Should return locks linked to a token", async () => {
      const tx1 = await lockFactory.createLock(block.timestamp + 100);
      const tx2 = await lockFactory.createLock(block.timestamp + 200);
      const tx3 = await lockFactory.createLock(block.timestamp + 300);
      // Have to get the receipts to get data
      const lock1 = (await tx1.wait()).events.filter((x) => x.event == "LockCreated")[0].args[0];
      const lock2 = (await tx2.wait()).events.filter((x) => x.event == "LockCreated")[0].args[0];
      const lock3 = (await tx3.wait()).events.filter((x) => x.event == "LockCreated")[0].args[0];

      await TokenLock.attach(lock1).trackToken(token.address);
      await TokenLock.attach(lock2).trackToken(token.address);
      await TokenLock.attach(lock3).trackToken(token.address);

      const locks = await lockFactory.getLocksByToken(token.address);
      expect(locks.length).to.equal(3);
      expect(locks[0]).to.equal(lock1);
      expect(locks[1]).to.equal(lock2);
      expect(locks[2]).to.equal(lock3);
    });
  });

  describe("getLocksByAccount", () => {
    it("Should return locks linked to an account", async () => {
      const tx1 = await lockFactory.createLock(block.timestamp + 100);
      const tx2 = await lockFactory.createLock(block.timestamp + 200);
      const tx3 = await lockFactory.createLock(block.timestamp + 300);
      // Have to get the receipts to get data
      const lock1 = (await tx1.wait()).events.filter((x) => x.event == "LockCreated")[0].args[0];
      const lock2 = (await tx2.wait()).events.filter((x) => x.event == "LockCreated")[0].args[0];
      const lock3 = (await tx3.wait()).events.filter((x) => x.event == "LockCreated")[0].args[0];
      
      const locks = await lockFactory.getLocksByAccount(owner.address);
      expect(locks.length).to.equal(3);
      expect(locks[0]).to.equal(lock1);
      expect(locks[1]).to.equal(lock2);
      expect(locks[2]).to.equal(lock3);
    });
  });

  describe("createLock", () => {
    it("Should revert if value is less than fee", async () => {
      await lockFactory.setFee(1000);

      await expect(lockFactory.createLock(block.timestamp + 100, { value: 999 }))
        .to.be.revertedWith("TokenLockFactory: value is less than required fee");
    });

    it("Should revert if unlock date is not in the future", async () => {
      await expect(lockFactory.createLock(block.timestamp - 1))
        .to.be.revertedWith("TokenLockFactory: new lock unlock date must be in the future");
    });

    it("Should create new lock with unlock date and emit event", async () => {
      await lockFactory.createLock(block.timestamp + 12345);
      const lockAddr = (await lockFactory.getLocksByAccount(owner.address))[0];
      const lock = await TokenLock.attach(lockAddr);
      expect(await lock.unlockDate()).to.equal(block.timestamp + 12345);
    });

    it("Should add new lock to account locks", async () => {
      const tx = await lockFactory.createLock(block.timestamp + 100);
      const lock = (await tx.wait()).events.filter((x) => x.event == "LockCreated")[0].args[0];
      expect(await lockFactory.getLocksByAccount(owner.address)).to.include(lock);
    });
  });

  describe("transferLock", () => {
    it("Should execute on lock ownership transfer and add and remove ownerships", async () => {
      const tx = await lockFactory.createLock(block.timestamp + 100);
      const lockAddr = (await tx.wait()).events.filter((x) => x.event == "LockCreated")[0].args[0];
      const lock = await TokenLock.attach(lockAddr);

      expect(await lock.owner()).to.equal(owner.address);
      expect(await lockFactory.getLocksByAccount(owner.address)).to.include(lockAddr);
      expect(await lockFactory.getLocksByAccount(addr1.address)).to.not.include(lockAddr);
      await lock.transferOwnership(addr1.address);
      expect(await lock.owner()).to.equal(addr1.address);
      expect(await lockFactory.getLocksByAccount(owner.address)).to.not.include(lockAddr);
      expect(await lockFactory.getLocksByAccount(addr1.address)).to.include(lockAddr);
    });
  });

  describe("setFee", () => {
    it("Should revert if not owner", async () => {
      await expect(lockFactory.connect(addr1).setFee(1000))
        .to.revertedWith("Ownable: caller is not the owner");
    });

    it("Should change fee if owner", async () => {
      await lockFactory.setFee(500);
      expect(await lockFactory.fee()).to.equal(500);
      await lockFactory.setFee(1000);
      expect(await lockFactory.fee()).to.equal(1000);
    })
  });
});
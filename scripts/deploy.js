// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers } = require("hardhat");
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  const name = hre.network.name;
  console.log(name);
  if (name == "localhost" || name == "hardhat") {
    await localDeploy();
  }
  else if (name == "testnet" || name == "ropsten") {
    await testDeploy();
  }
}

async function testDeploy() {
  const owner = (await ethers.getSigner()).address;

  // Deploy TestERC20 token
  const TestToken = await ethers.getContractFactory("TestERC20");
  const token = await TestToken.deploy("Test", "TEST", ethers.utils.parseEther("1000000000"), owner);
  await token.deployed();
  console.log("TestERC20 contract deployed to:", token.address);

  // Deploy TokenLockFactory
  const TokenLockFactory = await ethers.getContractFactory("TokenLockFactory");
  const factory = await TokenLockFactory.deploy();
  await factory.deployed();
  console.log("TokenLockFactory contract deployed to:", factory.address);

  // Verify contracts on bscscan
  await hre.run("verify:verify", {
    address: token.address,
    constructorArguments: [
      "Test",
      "TEST",
      ethers.utils.parseEther("1000000000"),
      owner
    ],
  });
  await hre.run("verify:verify", {
    address: factory.address
  });
}

async function localDeploy() {
  const owner = await ethers.getSigner();
  const block = await ethers.provider.getBlock();

  // Deploy TestERC20 token
  const TestToken = await ethers.getContractFactory("TestERC20");
  const token = await TestToken.deploy("Test", "TEST", ethers.utils.parseEther("1000000000"), owner.address);
  await token.deployed();
  console.log("TestERC20 contract deployed to:", token.address);

  // Deploy TokenLockFactory
  const TokenLockFactory = await ethers.getContractFactory("TokenLockFactory");
  const factory = await TokenLockFactory.deploy();
  await factory.deployed();
  console.log("TokenLockFactory contract deployed to:", factory.address);

  const tx = await factory.createLock(block.timestamp + 1000);
  const lock = (await tx.wait()).events.filter((x) => x.event == "LockCreated")[0].args[0];
  console.log("TokenLock contract deployed to:", lock);
  await factory.setCustomName(lock, "retromoon");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

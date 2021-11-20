require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
let secrets = require("./secrets.test.json");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
    },
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: { mnemonic: secrets.key }
    },
    ropsten: {
      url: secrets.ropstenUrl,
      accounts: [ secrets.key ]
    }
  },
  etherscan: {
    apiKey: secrets.scanKey
  },
  solidity: {
    compilers: [
      {
        version: "0.8.4"
      },
      {
        version: "0.6.6",
      },
      {
        version: "0.5.16"
      }
    ],
  },
};

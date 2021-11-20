# Locker Contracts

Basic hardhat contract project to lock tokens.

## Installation Guide

First, clone project and then run `npm install`.

### Run local server
Once installed, you will most likely want to test on a local server. To do so, open a terminal and run:
```
npx hardhat node
```

This will run a local server to deploy contracts on and should also give you a list of test accounts to play with. It should deploy at `http://127.0.0.1:8545/` (it will tell you where it runs). Now you can leave this terminal window running and switch to a new terminal for further commands.

### Deploy contract

To deploy some test contracts to local server, run `npm run deploy` or the following in a new terminal:
```
npx hardhat run scripts/deploy.js --network localhost
```
This should compile, deploy, and output the created contract IDs. The transactions should also show up in the terminal window running the local server.

If you want to deploy to a live chain, it is a little more involved, requiring api keys and supplied private key. Some setup is done for testnet and ropsten. Here are a few links to help:

https://hardhat.org/tutorial/deploying-to-a-live-network.html

https://docs.binance.org/smart-chain/developer/deploy/hardhat.html#config-hardhat-for-bsc


### Calling contract methods

To call the contract methods, you can find the contract ID from deploying the contract (or in local server), and can find the ABI under `/artifacts/contracts/ContractName.json`. Then you can do your web3 setup with the contractId and the ABI and call the methods you want.

### Test in the browser

If testing in the browser, you will have to setup Metamask to use this local server. Setup a new network in Metamask with RPC URL pointing to the URL above and set Chain ID to `1337`. You can then easily import one of the accounts with a private key string.

### Running local tests

To run existing written test cases, perform the following:
```
npx hardhat test
```
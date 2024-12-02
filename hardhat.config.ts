import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from "dotenv";

dotenv.config({ path: ".env" });

if (!process.env.WALLET_KEY) {
  throw new Error("[PNUT_CONTRACTS]: Provide WALLET_KEY!");
}

if (!process.env.INFURA_KEY) {
  throw new Error("[PNUT_CONTRACTS]: Provide INFURA_KEY!");
}

if (!process.env.PORT) {
  throw new Error("[PNUT_CONTRACTS]: Provide PORT!");
}

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.27",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000,
          },
        },
      },
    ],
  },
  networks: {
    // for mainnet
    "linea-mainnet": {
      url: `https://linea-mainnet.infura.io/v3/${process.env.INFURA_KEY}`,
      accounts: [process.env.WALLET_KEY as string],
      gasPrice: 1000000000,
    },
    // for testnet
    "linea-sepolia": {
      url: `https://linea-sepolia.infura.io/v3/${process.env.INFURA_KEY}`,
      accounts: [process.env.WALLET_KEY as string],
      gasPrice: 1000000000,
    },
    // for local dev environment
    "linea-local": {
      url: `http://localhost:${process.env.PORT}`,
      accounts: [process.env.WALLET_KEY as string],
      gasPrice: 1000000000,
    },
    hardhat: {
      forking: {
        url: `https://linea-mainnet.infura.io/v3/${process.env.INFURA_KEY}`,
        blockNumber: 12808514,
      },
    },
  },
};

export default config;

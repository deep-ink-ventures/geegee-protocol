// hardhat.config.js

import { HardhatUserConfig } from "hardhat/types";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-chai-matchers";
import "@typechain/hardhat";

type Config = HardhatUserConfig & {
    etherscan: any
};

const config: Config = {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ]
  },
  networks: {
    ethereumSepolia: {
      url: "https://rpc.sepolia.org",
      accounts: [process.env.PRIVATE_KEY!],
    },
    moonbaseAlpha: {
      url: "https://rpc.api.moonbase.moonbeam.network",
      accounts: [process.env.PRIVATE_KEY!],
      chainId: 1287,
    },
    localhost: {
      url: "http://127.0.0.1:8545/",
      accounts: [process.env.DEV_PRIVATE_KEY!],
      chainId: 31337,
    },
  },
  etherscan: {
    apiKey: {
      ethereumSepolia: process.env.ETHERSCAN_API_KEY!,
      moonbaseAlpha: process.env.MOONSCAN_API_KEY!,
    },
    customChains: [
      {
        network: "moonbaseAlpha",
        chainId: 1287,
        urls: {
          apiURL: "https://api-moonbase.moonscan.io/api",
          browserURL: "https://moonbase.moonscan.io",
        },
      },
    ],
  },
  paths: {
    sources: "./contracts",
    tests: "./tests",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  typechain: {
    outDir: "typechain",
    target: "ethers-v6",
  }
};

export default config;

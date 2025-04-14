import { HardhatUserConfig } from "hardhat/config";
require("hardhat-tracer");

// foundry support
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-toolbox";

import { config as dotEnvConfig } from "dotenv";
dotEnvConfig();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 20000
      }
    }
  },
  networks: {
    baseSepolia: {
      url: `https://base-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
      chainId: 84532
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
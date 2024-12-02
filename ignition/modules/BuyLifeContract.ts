// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "hardhat";

const lifePrice = ethers.parseEther("0.00004");

const LockModule = buildModule("BuyLifeContractModule", (m) => {
  const lock = m.contract("BuyLifeContract", [lifePrice, ""]);
  return { lock };
});

export default LockModule;

import { ethers } from "hardhat";
import { expect } from "chai";
import { BuyLifeContract, BuyLifeContract__factory } from "../typechain-types";

describe("BuyLifeContract", function () {
  async function deployBuyLifeFixture() {
    const [owner, delegate, buyer, otherAccount] = await ethers.getSigners();
    const lifePrice = ethers.parseEther("0.01"); // Set life price to 0.01 ETH

    const BuyLifeContractFactory = (await ethers.getContractFactory(
      "BuyLifeContract"
    )) as BuyLifeContract__factory;
    const buyLifeContract = await BuyLifeContractFactory.deploy(
      lifePrice,
      delegate.address
    );

    return { buyLifeContract, owner, delegate, buyer, otherAccount, lifePrice };
  }

  describe("Deployment", function () {
    it("Should set the correct life price", async function () {
      const { buyLifeContract, lifePrice } = await deployBuyLifeFixture();
      expect(await buyLifeContract.lifePrice()).to.equal(lifePrice);
    });

    it("Should set the correct owner", async function () {
      const { buyLifeContract, delegate } = await deployBuyLifeFixture();
      expect(await buyLifeContract.owner()).to.equal(delegate.address);
    });

    it("Should revert if life price is set to zero", async function () {
      const BuyLifeContractFactory = (await ethers.getContractFactory(
        "BuyLifeContract"
      )) as BuyLifeContract__factory;
      await expect(BuyLifeContractFactory.deploy(0, ethers.ZeroAddress)).to.be
        .reverted;
    });
  });

  describe("Life Purchases", function () {
    it("Should allow a user to buy a life and emit an event", async function () {
      const { buyLifeContract, buyer, lifePrice } =
        await deployBuyLifeFixture();
      const amount = 3;
      const totalCost = lifePrice * ethers.toBigInt(amount);

      await expect(
        buyLifeContract.connect(buyer).buyLife(amount, { value: totalCost })
      )
        .to.emit(buyLifeContract, "LifePurchased")
        .withArgs(buyer.address, totalCost);
    });

    it("Should revert if insufficient ETH is sent", async function () {
      const { buyLifeContract, buyer, lifePrice } =
        await deployBuyLifeFixture();
      const amount = 2;
      const insufficientValue =
        lifePrice * ethers.toBigInt(amount) - ethers.toBigInt(1);

      await expect(
        buyLifeContract
          .connect(buyer)
          .buyLife(amount, { value: insufficientValue })
      ).to.be.revertedWith("Insufficient ETH to buy a life");
    });
  });

  describe("Owner Functions", function () {
    it("Should revert withdrawal if no funds are available", async function () {
      const { buyLifeContract, owner } = await deployBuyLifeFixture();
      await expect(buyLifeContract.connect(owner).withdraw()).to.be.reverted;
    });

    it("Should revert if a non-owner tries to withdraw funds", async function () {
      const { buyLifeContract, buyer } = await deployBuyLifeFixture();
      await expect(buyLifeContract.connect(buyer).withdraw()).to.be.reverted;
    });
  });

  describe("Fallback Functions", function () {
    it("Should revert on direct ETH transfers", async function () {
      const { buyLifeContract, buyer } = await deployBuyLifeFixture();
      await expect(
        buyer.sendTransaction({
          to: buyLifeContract.getAddress(),
          value: ethers.parseEther("1"),
        })
      ).to.be.revertedWith("Direct deposits are not allowed");
    });

    it("Should revert on fallback function calls", async function () {
      const { buyLifeContract, otherAccount } = await deployBuyLifeFixture();
      const fallbackData = "0x1234"; // Random data
      await expect(
        otherAccount.sendTransaction({
          to: buyLifeContract.getAddress(),
          data: fallbackData,
        })
      ).to.be.revertedWith("Fallback function called");
    });
  });
});

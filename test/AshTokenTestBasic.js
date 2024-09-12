// import { expect } from "chai";
// import { ethers } from "hardhat";

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AshToken Contract", function () {
  let AshToken;
  let ashToken;
  let owner;
  let addr1;
  let addr2;

  beforeEach(async function () {
    try {
      const AshToken = await ethers.getContractFactory("AshToken");
      [owner, addr1, addr2] = await ethers.getSigners();
      // console.log("OWNer", owner.address);
      ashToken = await AshToken.deploy();
      // await ashToken.deployed();
      console.log("Before each Deployed at ", await ashToken.getAddress());
      return;
    } catch (error) {
      console.error("Deployment error:", error);
      throw error; // Re-throw to make the test fail as expected
    }
  });
  it("Should set initial parameters correctly", async function () {
    console.log("Contract Address:", await ashToken.getAddress());
    console.log("Owner Address:", owner.address);
    console.log("Addr1 Address:", addr1.address);

    // Check initial state
    const initialSupply = await ashToken.totalSupply();
    console.log("Initial Supply:", ethers.formatEther(initialSupply));

    expect(await ashToken.name()).to.equal("Ash Token");
    expect(await ashToken.symbol()).to.equal("ASH");
  });

  describe("Mint Function", function () {
    it("Should successfully mint tokens within the cap", async function () {
      const mintAmount = ethers.parseUnits("10", 18);

      // Record initial balance of addr1
      const initialBalance = await ashToken.balanceOf(addr1.address);

      // Mint tokens
      await ashToken.mint(addr1.address, mintAmount);

      // Check the balance after minting
      const finalBalance = await ashToken.balanceOf(addr1.address);

      // Assert that the balance has increased by the minted amount
      expect(finalBalance).to.equal(initialBalance + mintAmount);
    });
    it("Should successfully mint tokens within the cap for owner", async function () {
      const mintAmount = ethers.parseUnits("1000", 18);

      // Record initial balance of addr1
      const initialBalance = await ashToken.balanceOf(owner.address);

      // Mint tokens
      await ashToken.mint(owner.address, mintAmount);

      // Check the balance after minting
      const finalBalance = await ashToken.balanceOf(owner.address);

      // Assert that the balance has increased by the minted amount
      expect(finalBalance).to.equal(initialBalance + mintAmount);
    });

    it("Should fail to mint more than the cap", async function () {
      const largeAmount = ethers.parseUnits("100000000000000", 18);
      await expect(
        ashToken.mint(addr1.address, largeAmount)
      ).to.be.revertedWith("Minting exceeds 1% cap for the period");
    });

    it("Should fail to mint to the zero address", async function () {
      const mintAmount = ethers.parseUnits("100", 18);
      await expect(
        ashToken.mint(ethers.ZeroAddress, mintAmount)
      ).to.be.revertedWith("ERC20: mint to the zero address");
    });

    it("Should fail to mint with zero amount", async function () {
      await expect(ashToken.mint(addr1.address, 0)).to.be.revertedWith(
        "Amount must be greater than zero"
      );
    });
  });

  describe("Set Time Lock", function () {
    it("Should set time lock correctly", async function () {
      const futureDate = Math.floor(Date.now() / 1000) + 10000; // 10,000 seconds in the future
      const timeFrame = 100000;
      const snapshotDate = futureDate - 5000;
      const releasePercentage = 50;

      await ashToken.setTimeLock(
        futureDate,
        timeFrame,
        snapshotDate,
        releasePercentage
      );

      expect(await ashToken.futureDate()).to.equal(futureDate);
      expect(await ashToken.DCATimeFrame()).to.equal(timeFrame);
      expect(await ashToken.snapshotDate()).to.equal(snapshotDate);
      expect(await ashToken.timeLockReleasePercentage()).to.equal(
        releasePercentage
      );
    });

    it("Should fail to set future date in the past", async function () {
      const futureDate = Math.floor(Date.now() / 1000) - 10000; // 10,000 seconds in the past
      const timeFrame = 100000;
      const snapshotDate = futureDate - 5000;
      const releasePercentage = 50;

      await expect(
        ashToken.setTimeLock(
          futureDate,
          timeFrame,
          snapshotDate,
          releasePercentage
        )
      ).to.be.revertedWith("Future date must be in the future");
    });

    it("Should fail to set invalid time frame", async function () {
      const futureDate = Math.floor(Date.now() / 1000) + 10000;
      const timeFrame = 0;
      const snapshotDate = futureDate - 5000;
      const releasePercentage = 50;

      await expect(
        ashToken.setTimeLock(
          futureDate,
          timeFrame,
          snapshotDate,
          releasePercentage
        )
      ).to.be.revertedWith("Time frame must be greater than zero");
    });

    it("Should fail to set invalid release percentage", async function () {
      const futureDate = Math.floor(Date.now() / 1000) + 10000;
      const timeFrame = 100000;
      const snapshotDate = futureDate - 5000;
      const releasePercentage = 101; // More than 100%

      await expect(
        ashToken.setTimeLock(
          futureDate,
          timeFrame,
          snapshotDate,
          releasePercentage
        )
      ).to.be.revertedWith("Release percentage must be between 0 and 100");
    });
  });

  describe("Lock Tokens", function () {
    it("Should lock tokens successfully", async function () {
      // const lockAmount = ethers.parseUnits("1000", 18);
      // await ashToken.transfer(addr1.address, lockAmount);
      // // await ashToken.lockTokens(addr1.address, lockAmount);
      // expect(await ashToken.lockedTokens(addr1.address)).to.equal(lockAmount);
      const lockAmount = ethers.parseUnits("1000", 18);

      // Check initial balance of the owner
      const ownerBalance = await ashToken.balanceOf(owner.address);

      console.log(
        "Owner balance before transfer:",
        ethers.formatEther(ownerBalance)
      );

      // Mint additional tokens if necessary
      if (ownerBalance < lockAmount) {
        const mintAmount = lockAmount - ownerBalance;
        await ashToken.mint(owner.address, mintAmount);
      }

      // Check balance after minting
      const newOwnerBalance = await ashToken.balanceOf(owner.address);
      console.log(
        "Owner balance after minting:",
        ethers.formatEther(newOwnerBalance)
      );

      // Lock tokens
      await ashToken.lockTokens(owner.address, lockAmount);

      // Check if tokens were locked correctly
      expect(await ashToken.lockedTokens(owner.address)).to.equal(lockAmount);
    });

    it("Should fail to lock zero tokens", async function () {
      await expect(ashToken.lockTokens(addr1.address, 0)).to.be.revertedWith(
        "Amount must be greater than zero"
      );
    });

    it("Should fail to lock more tokens than balance", async function () {
      const lockAmount = ethers.parseUnits("1000000", 18); // More than balance
      await expect(
        ashToken.lockTokens(addr1.address, lockAmount)
      ).to.be.revertedWith("Insufficient balance to lock tokens");
    });
  });

  describe("Release Locked Tokens", function () {
    beforeEach(async function () {
      const futureDate = Math.floor(Date.now() / 1000) + 10000; // 10,000 seconds in the future
      const timeFrame = 100000;
      const snapshotDate = futureDate - 5000;
      const releasePercentage = 50;

      await ashToken.setTimeLock(
        futureDate,
        timeFrame,
        snapshotDate,
        releasePercentage
      );

      const lockAmount = ethers.parseUnits("10000", 18);

      // Ensure owner has enough tokens to lock
      const ownerBalance = await ashToken.balanceOf(owner.address);
      if (ownerBalance < lockAmount) {
        await ashToken.mint(owner.address, lockAmount- ownerBalance);
      }

      // Lock tokens
      await ashToken.lockTokens(owner.address, lockAmount);
    });

    it("Should successfully release locked tokens after the release date", async function () {
      // Fast forward to a time after the release date
      await ethers.provider.send('evm_increaseTime', [10000]); // 10,000 seconds
      await ethers.provider.send('evm_mine');

      const initialBalance = await ashToken.balanceOf(owner.address);
      console.log("init ",initialBalance)
      await ashToken.releaseLockedTokens(owner.address);

      // Check the balance after releasing locked tokens
      const finalBalance = await ashToken.balanceOf(owner.address);
      console.log("final ",finalBalance)

      expect(finalBalance).to.be.gt(initialBalance); // Balance should increase
    });

    it("Should fail to release tokens before the release date", async function () {
      await ethers.provider.send('evm_increaseTime', [100]); // 10,000 seconds

      await expect(ashToken.releaseLockedTokens(owner.address)).to.be.revertedWith("Tokens are not yet unlocked");
    });

    it("Should fail to release if no tokens are locked", async function () {
      // Fast forward to a time after the release date
      await ethers.provider.send('evm_increaseTime', [10000]); // 10,000 seconds
      await ethers.provider.send('evm_mine');

      // Unlock tokens for the first test
      await ashToken.releaseLockedTokens(owner.address);

      await expect(ashToken.releaseLockedTokens(owner.address)).to.be.revertedWith("No locked tokens to release");
    });
  });
});
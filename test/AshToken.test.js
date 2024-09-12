
// //   const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
// const { expect } = require("chai");

// describe("AshToken Contract", function () {
//     let AshToken, ashToken, owner, addr1, addr2;

//     beforeEach(async function () {
//         AshToken = await ethers.getContractFactory("AshToken");
//         [owner, addr1, addr2] = await ethers.getSigners();
//         ashToken = await AshToken.deploy();
//         console.log(ashToken)
//         await ashToken.deployed();
//         console.log("...",ashToken)

//     });

//     it("Should deploy the contract", async function () {
//         expect(await ashToken.name()).to.equal("Ash Token");
//         expect(await ashToken.symbol()).to.equal("ASH");
//     });
//     it("should initialize with the correct total supply", async function () {
//         const totalSupply = await ashToken.totalSupply();
//         expect(await ashToken.balanceOf(owner.address)).to.equal(totalSupply);
//     });

//     it("should mint tokens correctly", async function () {
//         await ashToken.mint(addr1.address, ethers.utils.parseUnits("1000", 18));
//         expect(await ashToken.balanceOf(addr1.address)).to.equal(ethers.utils.parseUnits("1000", 18));
//     });

//     it("should not mint more than the allowed cap", async function () {
//         await ashToken.mint(addr1.address, ethers.utils.parseUnits("10000000000", 18));
//         await expect(
//             ashToken.mint(addr1.address, ethers.utils.parseUnits("100", 18))
//         ).to.be.revertedWith("Minting exceeds 1% cap for the period");
//     });

//     it("should set and get tax rates correctly", async function () {
//         await ashToken.setBuySellTax(50, 50);
//         expect(await ashToken.buyTax()).to.equal(50);
//         expect(await ashToken.sellTax()).to.equal(50);
//     });

//     it("should set time lock parameters correctly", async function () {
//         await ashToken.setTimeLock(
//             Math.floor(Date.now() / 1000) + 3600, // futureDate: 1 hour from now
//             3600, // DCATimeFrame: 1 hour
//             Math.floor(Date.now() / 1000), // snapshotDate: now
//             10 // releasePercentage: 10%
//         );
//         expect(await ashToken.futureDate()).to.be.gt(Math.floor(Date.now() / 1000));
//     });

//     it("should lock and release tokens correctly", async function () {
//         await ashToken.mint(owner.address, ethers.utils.parseUnits("10000", 18));
//         await ashToken.lockTokens(owner.address, ethers.utils.parseUnits("5000", 18));

//         const lockedAmount = await ashToken.lockedTokens(owner.address);
//         expect(lockedAmount).to.equal(ethers.utils.parseUnits("5000", 18));

//         await ethers.provider.send("evm_increaseTime", [3600]); // advance time by 1 hour
//         await ethers.provider.send("evm_mine");

//         await ashToken.releaseLockedTokens();
//         expect(await ashToken.balanceOf(owner.address)).to.be.gt(ethers.utils.parseUnits("10000", 18));
//     });

//     it("should prevent unauthorized token locking and releasing", async function () {
//         await expect(
//             ashToken.connect(addr1).lockTokens(addr2.address, ethers.utils.parseUnits("1000", 18))
//         ).to.be.revertedWith("Ownable: caller is not the owner");

//         await expect(
//             ashToken.connect(addr1).releaseLockedTokens()
//         ).to.be.revertedWith("Tokens cannot be released before the future date");
//     });
// });

const { parseEther } = require("@ethersproject/units");
const { expect, use } = require("chai");
const { solidity } = require("ethereum-waffle");
use(solidity);

const contractName = "TheRealDream";
const baseURI1 = "therealdream.com/api/";
const baseURI2 = "therealdream.com/api/v2/";
const contractParams = ["The Real Dream", "TRD", 4, baseURI1];
const maxRoyaltyFee = 10000;
const oneEth = parseEther("1");

const setupContract = async (signer) => {
  const factory = await ethers.getContractFactory(contractName, signer);
  const instance = await factory.deploy(...contractParams);
  return instance;
};

describe("Contract: The Real Dream", () => {
  let instance;
  let owner, holder1, holder2, nonHolder1, nonHolder2;
  beforeEach("!! deploy instance", async () => {
    [owner, holder1, holder2, nonHolder1, nonHolder2] =
      await ethers.getSigners();
    instance = await setupContract(owner);
  });
  context("Contract can pause access", () => {
    it("owner can pause contract", async () => {
      expect(await instance.paused()).to.be.false;
      await instance.connect(owner).pause();
      expect(await instance.paused()).to.be.true;
    });
    it("owner can unpause contract when it is paused", async () => {
      await instance.connect(owner).pause();
      expect(await instance.paused()).to.be.true;
      await instance.connect(owner).unpause();
      expect(await instance.paused()).to.be.false;
    });
  });
  context("Owner can airdrop tokens", () => {
    it("cannot airdrop if no address supplied", async () => {
      await expect(instance.connect(owner).airdrop([])).to.be.revertedWith(
        "ZERO_RECEIVERS_COUNT"
      );
    });
    it("can airdrop to multiple address", async () => {
      const receiverList = [holder1.address, holder2.address];
      expect(await instance.balanceOf(holder1.address)).to.equal(0);
      expect(await instance.balanceOf(holder2.address)).to.equal(0);
      await instance.connect(owner).airdrop(receiverList);
      expect(await instance.balanceOf(holder1.address)).to.not.equal(0);
      expect(await instance.balanceOf(holder2.address)).to.not.equal(0);
    });
    it("cannot airdrop more than maximum", async () => {
      const receiverList = [holder1.address, holder2.address];
      // 1st airdrop
      await instance.connect(owner).airdrop(receiverList);
      // 2nd airdrop tried but should fail
      await expect(
        instance.connect(owner).airdrop([...receiverList, ...receiverList])
      ).to.be.revertedWith("MAX_TOKENS_REACHED");
    });
  });
  context("Owner can update royalties", () => {
    beforeEach("!! Airdrop token", async () => {
      const receiverList = [holder1.address, holder2.address];
      await instance.connect(owner).airdrop(receiverList);
    });
    it("can update royalties", async () => {
      let royaltyFee = maxRoyaltyFee / 10;
      await instance.setRoyalty(owner.address, royaltyFee);
      let tokenId = 1;
      let royaltyInfo = await instance.royaltyInfo(tokenId, oneEth);
      expect(royaltyInfo[0]).to.equal(owner.address);
      expect(royaltyInfo[1]).to.equal(
        oneEth.mul(royaltyFee).div(maxRoyaltyFee)
      );
      royaltyFee = maxRoyaltyFee / 20;
      await instance.setRoyalty(owner.address, royaltyFee);
      tokenId = 2;
      royaltyInfo = await instance.royaltyInfo(tokenId, oneEth);
      expect(royaltyInfo[0]).to.equal(owner.address);
      expect(royaltyInfo[1]).to.equal(
        oneEth.mul(royaltyFee).div(maxRoyaltyFee)
      );
      royaltyFee = maxRoyaltyFee;
      await instance.setRoyalty(owner.address, royaltyFee);
      royaltyInfo = await instance.royaltyInfo(tokenId, oneEth);
      expect(royaltyInfo[0]).to.equal(owner.address);
      expect(royaltyInfo[1]).to.equal(
        oneEth.mul(royaltyFee).div(maxRoyaltyFee)
      );
    });
    it("can delete royalties info", async () => {
      const royaltyFee = maxRoyaltyFee / 10;
      await instance.setRoyalty(owner.address, royaltyFee);
      const tokenId = 1;
      let royaltyInfo = await instance.royaltyInfo(tokenId, oneEth);
      expect(royaltyInfo[0]).to.equal(owner.address);
      expect(royaltyInfo[1]).to.equal(
        oneEth.mul(royaltyFee).div(maxRoyaltyFee)
      );
      await instance.removeRoyalty();
      royaltyInfo = await instance.royaltyInfo(tokenId, oneEth);
      expect(royaltyInfo[0]).to.equal(ethers.constants.AddressZero);
      expect(royaltyInfo[1]).to.equal(0);
    });
  });
  context("returns correct token URI", () => {
    beforeEach("!! Airdrop token", async () => {
      const receiverList = [holder1.address, holder2.address];
      await instance.connect(owner).airdrop(receiverList);
    });
    it("returns correct token URI", async () => {
      const tokenID = 1;
      const expectedTokenURI = `${baseURI1}${tokenID}.json`;
      expect(await instance.tokenURI(tokenID)).to.equal(expectedTokenURI);
      await instance.setBaseURI(baseURI2);
      const expectTokenURI2 = `${baseURI2}${tokenID}.json`;
      expect(await instance.tokenURI(tokenID)).to.equal(expectTokenURI2);
    });
    it("fails when token doesn't exist", async () => {
      const tokenID = 0;
      await expect(instance.tokenURI(tokenID)).to.be.revertedWith(
        "nonexistent token"
      );
    });
    it("support interface", async () => {
      console.log(await instance.supportsInterface("0x12345678"));
    });
  });
});

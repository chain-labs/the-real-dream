const { parseEther } = require("@ethersproject/units");
const { expect, use } = require("chai");
const { solidity } = require("ethereum-waffle");
const { time } = require("@openzeppelin/test-helpers");
use(solidity);

const contractName = "TheRealDream";
const baseURI1 = "therealdream.com/api/";
const baseURI2 = "therealdream.com/api/v2/";
const maximumTokens = 4;
const cooldownPeriod = 120; // 2 minutes
const minimumDistributionPeriod = 240; // 4 mintues
const buffer = 10;
const contractParams = [
  maximumTokens,
  cooldownPeriod,
  minimumDistributionPeriod,
  "The Real Dream",
  "TRD",
  baseURI1,
];
const multiplier = 3;
const maxRoyaltyFee = 10000;
const oneEth = parseEther("1");

const increaseTimeTo = async () => {
  await network.provider.send("evm_setNextBlockTimestamp", [1625097600]);
  await network.provider.send("evm_mine");
};

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
      await instance.supportsInterface("0x12345678");
    });
  });
  context("owner can deposit funds", () => {
    it("cannot deposit if tokens are not distributed", async () => {
      const currentTime = parseInt((await time.latest()).toString());
      const startTime = currentTime + cooldownPeriod;
      const endTime = currentTime + cooldownPeriod * multiplier;
      await expect(
        instance.prepareForRewards(startTime, endTime, { value: oneEth })
      ).to.be.revertedWith("TOKENS_NOT_DISTRIBUTED");
    });
    context("preapre for rewards when tokens are distributed", () => {
      beforeEach("!! distribute tokens", async () => {
        const receiverList = [holder1.address, holder2.address];
        await instance.airdrop([...receiverList, ...receiverList]);
        const data = await instance.data();
        expect(data.totalSupply).to.equal(maximumTokens);
      });
      it("can deposit if tokens are distributed", async () => {
        const currentTime = parseInt((await time.latest()).toString());
        const startTime = currentTime + cooldownPeriod + buffer;
        const endTime = currentTime + cooldownPeriod * multiplier + buffer;
        await instance.prepareForRewards(startTime, endTime, { value: oneEth });
      });
      it("cannot distribute with short notice", async () => {
        const currentTime = parseInt((await time.latest()).toString());
        const startTime = currentTime + cooldownPeriod - buffer;
        const endTime = currentTime + cooldownPeriod * multiplier;
        await expect(
          instance.prepareForRewards(startTime, endTime, { value: oneEth })
        ).to.be.revertedWith("SHORT_NOTICE");
      });
      it("cannot have distribution period too short", async () => {
        const currentTime = parseInt((await time.latest()).toString());
        const startTime = currentTime + cooldownPeriod + buffer;
        const endTime = currentTime + cooldownPeriod + buffer;
        await expect(instance.prepareForRewards(startTime, endTime, { value: oneEth })).to.be.revertedWith("SHORT_DISTRIBUTION_PERIOD");
      })
    });
  });
  context("can split payments", () => {
    beforeEach("!! deposit some funds and airdrop tokens", async () => {
      const receiverList = [holder1.address, holder2.address];
      await instance.connect(owner).airdrop([...receiverList, ...receiverList]);
      const currentTime = parseInt((await time.latest()).toString());
      const startTime = currentTime + cooldownPeriod + buffer;
      const endTime = currentTime + cooldownPeriod * multiplier + buffer;
      await instance.prepareForRewards(startTime, endTime, {
        value: oneEth.mul(maximumTokens),
      });
    });
    context("before distribution period starts", async () => {
      it("cannot release before distribution period starts", async () => {
        const tokenId = 1;
        await expect(
          instance.connect(holder1).releaseReward(tokenId)
        ).to.be.revertedWith("INVALID_DISTRIBUTION_PERIOD");
      });
      it("can transfer token before distribution period", async () => {
        await instance
          .connect(holder1)
          .transferFrom(holder1.address, holder2.address, 3);
      });
    });
    context("during distribution period", async () => {
      beforeEach("!! jump to distribution period", async () => {
        const data = await instance.data();
        await time.increaseTo(
          (data.distributionStartTime).toString()
        );
      });
      it("cannot release if token doesn't exists", async () => {
        const tokenId = 0;
        await expect(
          instance.connect(holder1).releaseReward(tokenId)
        ).to.be.revertedWith("nonexistent token");
      });
      it("releases payment for valid token to owner of token", async () => {
        const tokenId = 1;
        await expect(
          await instance.connect(holder1).releaseReward(tokenId)
        ).to.changeEtherBalance(
          holder1,
          oneEth.mul(maximumTokens).div(maximumTokens)
        );
      });
      it("cannot release payment when nothing is due", async () => {
        const tokenId = 1;
        await instance.connect(holder1).releaseReward(tokenId);
        await expect(
          instance.connect(holder1).releaseReward(tokenId)
        ).to.be.revertedWith("no due payment");
      });
      it("cannot transfer token during distribution period", async () => {
        await expect(
          instance
            .connect(holder1)
            .transferFrom(holder1.address, holder2.address, 3)
        ).to.be.revertedWith("TRANSFER_PAUSED");
      });
    });
    context("after distribution period", async () => {
      beforeEach("!! jump to distribution end time", async () => {
        const data = await instance.data();
        await time.increaseTo(
          data.distributionEndTime.toString()
        );
      });
      it("cannot release", async () => {
        const tokenId = 1;
        await expect(
          instance.connect(holder1).releaseReward(tokenId)
        ).to.be.revertedWith("INVALID_DISTRIBUTION_PERIOD");
      });
      it("can transfer token after distribution period", async () => {
        await instance
          .connect(holder1)
          .transferFrom(holder1.address, holder2.address, 3);
      });
    });
  });
});

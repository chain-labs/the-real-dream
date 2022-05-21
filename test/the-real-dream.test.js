const { expect, use } = require("chai");
const { solidity } = require('ethereum-waffle');
use(solidity);

const contractName = "TheRealDream";
const contractParams = ["The Real Dream", "TRD"];

const setupContract = async (signer) => {
    const factory = await ethers.getContractFactory(contractName, signer);
    const instance = await factory.deploy(...contractParams);
    return instance;
}

describe("Contract: The Real Dream", () => {
    let instance;
    let owner, holder1, holder2, nonHolder1, nonHolder2;
    beforeEach("!! deploy instance", async () => {
        [owner, holder1, holder2, nonHolder1, nonHolder2] = await ethers.getSigners();
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
    })
})
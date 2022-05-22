const contractName = "TheRealDream";
const tokenName = "The Real Dream";
const symbol = "TRD";
const baseURI = "therealdream.com/api/";
const assetURI = "youtube.com/video/xyz";
const firstReward = 1;
const maximumTokens = 4;
const cooldownPeriod = 120; // 2 minutes
const minimumDistributionPeriod = 24 * 60 * 60; // 4 mintues
const param = [
  maximumTokens,
  cooldownPeriod,
  minimumDistributionPeriod,
  tokenName,
  symbol,
  baseURI,
  assetURI,
];

module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  await deploy(contractName, {
    from: deployer,
    args: param,
    log: true
  });
};
module.exports.tags = [contractName];

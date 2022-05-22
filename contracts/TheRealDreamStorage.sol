pragma solidity 0.8.13;

contract TheRealDreamStorage {
    struct RewardData {
        uint256 maximumTokens; // maximum amount of tokens that can be minted
        string baseURI; // base URI
        uint256 totalReleased;
        uint256 cooldownPeriod;
        uint256 distributionStartTime;
        uint256 distributionEndTime;
        uint256 totalSupply;
        uint256 minimumDistributionPeriod;
        mapping(uint256 => uint256) released;
    }

    RewardData public data;
}

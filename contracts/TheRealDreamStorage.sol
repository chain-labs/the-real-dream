pragma solidity 0.8.13;

contract TheRealDreamStorage {
    struct RewardData {
        uint256 maximumTokens; // maximum amount of tokens that can be minted //set by owner
        uint256 cooldownPeriod; //set by owner
        uint256 minimumDistributionPeriod;   //set by owner
        uint256 distributionStartTime;   //set by owner
        uint256 distributionEndTime;     //set by owner
        uint256 totalBalance;
        uint256 totalReleased;
        uint256 totalSupply;
        string baseURI; // base URI //  //set by owner
        string assetURI; // set by owner
        mapping(uint256 => uint256) released;
    }
    mapping(uint256 => RewardData) public rewards;
    uint256 public rewardsIndex;
    uint256 public totalSupply;
}

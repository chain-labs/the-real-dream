pragma solidity 0.8.13;

/// @title The Real Dream Storage
/// @author Mihirsinh Parmar
/// @notice Storage contract of The Real Dream
/// @dev A separate storage contract to prevent storage collision in proxy
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

    /// @notice mapping of reward index with reward data
    /// @return rewards returns the reward data struct
    mapping(uint256 => RewardData) public rewards;

    /// @notice next reward index
    /// @return rewardsIndex next reward index
    uint256 public rewardsIndex;

    /// @notice total supply
    /// @dev total supply
    /// @return totalSupply total supply
    uint256 public totalSupply;
}

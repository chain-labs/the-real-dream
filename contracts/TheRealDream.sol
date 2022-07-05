// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2022 The Real Dream Project
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./TheRealDreamStorage.sol";

/// @title The Real Dream
/// @author Mihirsinh Parmar
/// @notice The real dream is a project to help youtube creators split rewards with NFT holders
/// @dev It is going to be deployed using proxy
contract TheRealDream is
    Ownable,
    Pausable,
    ReentrancyGuard,
    ERC721,
    ERC2981,
    TheRealDreamStorage
{
    using Strings for uint256;
    
    /// @notice It is prefix multiplier for reward ID
    /// @dev each reward as a unique ID, and the token ID for each reward starts with prefix
    /// @return PREFIX_MULTIPLIER the prefix multipler
    uint256 public constant PREFIX_MULTIPLIER = 100_000_000;

    /// @notice create log when new payment is released
    /// @dev emits whenever a user releases a payment
    /// @param tokenId token ID for which payment was released
    /// @param payment amount of reward released
    /// @param receiver receiver address
    event PaymentReleased(
        uint256 indexed tokenId,
        uint256 payment,
        address indexed receiver
    );

    /// @notice create log when creator prepares rewards
    /// @dev emits whenever owner prepares rewards
    /// @param depositAmount amount deposited to smart contract for reward
    /// @param startTime start time when the reward distribution starts
    /// @param endTime end time when the reward distribution ends
    event PrepareRewards(
        uint256 depositAmount,
        uint256 startTime,
        uint256 endTime
    );

    /// @notice create logs when a new reward asset is added
    /// @dev emitted when creator adds new reward asset
    /// @param index index of new reward asset
    /// @param maximumTokens maximum number of NFTs for this reward
    /// @param assetURI URI of the reward asset
    event RewardAssetAdded(
        uint256 indexed index,
        uint256 maximumTokens,
        string assetURI
    );

    /// @notice Constructor
    /// @dev Constructor
    /// @param _maximumTokens maximum number of NFTs for the initial reward asset
    /// @param _cooldownPeriod cool down period before new reward distribution can start
    /// @param _minimumDistributionPeriod minimum time period for which reward distribution can be active
    /// @param _name name of token
    /// @param _symbol symbol of token
    /// @param _baseURI base URI of the NFT metadata
    /// @param _assetURI asset URI of the new reward asset
    constructor(
        uint256 _maximumTokens,
        uint256 _cooldownPeriod,
        uint256 _minimumDistributionPeriod,
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        string memory _assetURI
    ) ERC721(_name, _symbol) {
        uint256 firstIndex = 1;
        unchecked {
            rewardsIndex = firstIndex;
        }
        _addNewReward(
            firstIndex,
            _maximumTokens,
            _cooldownPeriod,
            _minimumDistributionPeriod,
            _baseURI,
            _assetURI
        );
    }

    /// @notice creator can add new reward asset
    /// @dev add new reward asset and set reward settings
    /// @param _maximumTokens maximum number of NFTs for the reward asset
    /// @param _cooldownPeriod cooldown period before reward distribution starts
    /// @param _minimumDistributionPeriod minimum time period of reward distribution
    /// @param _baseURI the base URI of the new asset reward
    /// @param _assetURI the asset URI of the new reward asset
    function addNewReward(
        uint256 _maximumTokens,
        uint256 _cooldownPeriod,
        uint256 _minimumDistributionPeriod,
        string memory _baseURI,
        string memory _assetURI
    ) external onlyOwner {
        uint256 currentIndex = rewardsIndex;
        unchecked {
            rewardsIndex = currentIndex + 1;
        }
        currentIndex++;
        _addNewReward(
            currentIndex,
            _maximumTokens,
            _cooldownPeriod,
            _minimumDistributionPeriod,
            _baseURI,
            _assetURI
        );
    }

    /// @notice creator can add new reward asset
    /// @dev add new reward asset and set reward settings
    /// @param _index new index of the reward asset
    /// @param _maximumTokens maximum number of NFTs for the reward asset
    /// @param _cooldownPeriod cooldown period before reward distribution starts
    /// @param _minimumDistributionPeriod minimum time period of reward distribution
    /// @param _baseURI the base URI of the new asset reward
    /// @param _assetURI the asset URI of the new reward asset
    function _addNewReward(
        uint256 _index,
        uint256 _maximumTokens,
        uint256 _cooldownPeriod,
        uint256 _minimumDistributionPeriod,
        string memory _baseURI,
        string memory _assetURI
    ) internal {
        rewards[_index].maximumTokens = _maximumTokens;
        rewards[_index].baseURI = _baseURI;
        rewards[_index].cooldownPeriod = _cooldownPeriod;
        rewards[_index].minimumDistributionPeriod = _minimumDistributionPeriod;
        rewards[_index].assetURI = _assetURI;
        emit RewardAssetAdded(_index, _maximumTokens, _assetURI);
    }

    /// @notice pause smart contract
    /// @dev pauses the functionality to release reward
    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    /// @notice unpause smart contract
    /// @dev unpauses the functionality to release reward
    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    /// @notice airdrop NFTs for a reward index
    /// @dev airdrop tokens for a reward index to list of addresses
    /// @param _receivers list of addresses to sirdrop token
    /// @return _rewardIndex reward index whose tokens will be airdropped
    function airdrop(address[] calldata _receivers, uint256 _rewardIndex)
        external
        onlyOwner
    {
        require(_receivers.length > 0, "ZERO_RECEIVERS_COUNT");
        require(
            rewards[_rewardIndex].totalSupply + _receivers.length <=
                rewards[_rewardIndex].maximumTokens,
            "MAX_TOKENS_REACHED"
        );
        uint256 prefix = _rewardIndex * PREFIX_MULTIPLIER;
        unchecked {
            totalSupply = totalSupply + _receivers.length;
        }
        for (uint256 i; i < _receivers.length; i++) {
            unchecked {
                rewards[_rewardIndex].totalSupply =
                    rewards[_rewardIndex].totalSupply +
                    1;
            }
            _safeMint(
                _receivers[i],
                rewards[_rewardIndex].totalSupply + prefix
            );
        }
    }

    /// @notice set royalty details
    /// @dev set default royalties
    /// @param _account address of royalty receiver
    /// @param _fee royalty percentage
    function setRoyalty(address _account, uint96 _fee) external onlyOwner {
        _setDefaultRoyalty(_account, _fee);
    }

    /// @notice remove royalty
    /// @dev remove royalty
    function removeRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

    /// @notice creator can deposit and set new distribution reward
    /// @dev creator deposits and set new distribution reward
    /// @param _distributionStartTime distribution of reward start time
    /// @param _distributionEndTime distribution of reward end time
    /// @param _rewardIndex reward asset index whose distribution period needs to start
    function prepareForRewards(
        uint256 _distributionStartTime,
        uint256 _distributionEndTime,
        uint256 _rewardIndex
    ) external payable onlyOwner {
        require(
            rewards[_rewardIndex].totalSupply ==
                rewards[_rewardIndex].maximumTokens,
            "TOKENS_NOT_DISTRIBUTED"
        );
        require(
            _distributionEndTime - _distributionStartTime >=
                rewards[_rewardIndex].minimumDistributionPeriod,
            "SHORT_DISTRIBUTION_PERIOD"
        );
        require(
            _distributionStartTime >=
                block.timestamp + rewards[_rewardIndex].cooldownPeriod,
            "SHORT_NOTICE"
        );
        rewards[_rewardIndex].distributionStartTime = _distributionStartTime;
        rewards[_rewardIndex].distributionEndTime = _distributionEndTime;
        _increaseBalance(msg.value, _rewardIndex);
        emit PrepareRewards(
            msg.value,
            _distributionStartTime,
            _distributionEndTime
        );
    }

    /// @inheritdoc	ERC721
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @notice set new base URI for reward asset
    /// @dev sets new base URI for a reward asset
    /// @param _baseURI new base URI
    /// @param _rewardIndex reward asset index
    function setBaseURI(string calldata _baseURI, uint256 _rewardIndex)
        external
        onlyOwner
    {
        rewards[_rewardIndex].baseURI = _baseURI;
    }

    /// @notice release reward
    /// @dev release reward
    /// @param tokenId token ID for what rewards are released
    function releaseReward(uint256 tokenId) external whenNotPaused {
        uint256 _rewardIndex = getRewardIndex(tokenId);
        require(
            (rewards[_rewardIndex].distributionStartTime <= block.timestamp &&
                rewards[_rewardIndex].distributionEndTime > block.timestamp),
            "INVALID_DISTRIBUTION_PERIOD"
        );
        require(_exists(tokenId), "nonexistent token");

        uint256 totalReceived = rewards[_rewardIndex].totalBalance +
            rewards[_rewardIndex].totalReleased;
        uint256 payment = (totalReceived /
            rewards[_rewardIndex].maximumTokens) -
            rewards[_rewardIndex].released[tokenId];

        require(payment != 0, "no due payment");

        rewards[_rewardIndex].released[tokenId] += payment;
        rewards[_rewardIndex].totalReleased += payment;
        _decreaseBalance(payment, _rewardIndex);
        Address.sendValue(payable(ownerOf(tokenId)), payment);
        emit PaymentReleased(tokenId, payment, ownerOf(tokenId));
    }

    /// @notice calculate pending reward for a token ID
    /// @dev calculate pending reward for a token ID
    /// @param tokenId token ID for which pending reward was calculated
    /// @return pendingAmount amount fo pending rewards
    function pendingReward(uint256 tokenId) external view returns (uint256) {
        uint256 _rewardIndex = getRewardIndex(tokenId);
        uint256 totalReceived = rewards[_rewardIndex].totalBalance +
            rewards[_rewardIndex].totalReleased;
        return
            (totalReceived / rewards[_rewardIndex].maximumTokens) -
            rewards[_rewardIndex].released[tokenId];
    }

    /// @inheritdoc	ERC721
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "nonexistent token");
        uint256 _rewardIndex = getRewardIndex(tokenId);
        uint256 id = tokenId % PREFIX_MULTIPLIER;

        string memory baseURI = rewards[_rewardIndex].baseURI;
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, id.toString(), ".json"))
                : "";
    }

    /// @notice increases balance stored in state
    /// @dev increases balance stored in state
    /// @param _value amount by which balance should be increased
    /// @param _rewardIndex reward asset index
    function _increaseBalance(uint256 _value, uint256 _rewardIndex) internal {
        rewards[_rewardIndex].totalBalance += _value;
    }

    /// @notice decreseas balance stored in state
    /// @dev decreseas balance stored in state
    /// @param _value amount by which balance should be decreased
    /// @return _rewardIndex reward asset index
    function _decreaseBalance(uint256 _value, uint256 _rewardIndex) internal {
        rewards[_rewardIndex].totalBalance -= _value;
    }

    /// @inheritdoc	ERC721
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        // if (distributionEndTime != 0 && distributionStartTime != 0) {
        uint256 _rewardIndex = getRewardIndex(tokenId);
        require(
            !(rewards[_rewardIndex].distributionStartTime <= block.timestamp &&
                rewards[_rewardIndex].distributionEndTime > block.timestamp),
            "TRANSFER_PAUSED"
        );
    }

    /// @notice get reward index for a token ID
    /// @dev for a specified token ID, it calculates the token ID
    /// @param _tokenId token ID for which reward index should be calculated
    /// @return rewardIndex index of reward asset
    function getRewardIndex(uint256 _tokenId) public pure returns (uint256) {
        return _tokenId / PREFIX_MULTIPLIER;
    }

    /// @notice fallback method to revert when any ETH is transferred
    /// @dev fallback method to revert when any ETH is transferred
    receive() external payable {
        revert("NOT_ALLOWED");
    }
}

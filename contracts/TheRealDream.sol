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

contract TheRealDream is
    Ownable,
    Pausable,
    ReentrancyGuard,
    ERC721,
    ERC2981,
    TheRealDreamStorage
{
    uint256 public constant PREFIX_MULTIPLIER = 100_000_000;
    using Strings for uint256;

    event PaymentReleased(
        uint256 indexed tokenId,
        uint256 payment,
        address indexed receiver
    );
    event PrepareRewards(
        uint256 depositAmount,
        uint256 startTime,
        uint256 endTime
    );
    event RewardAssetAdded(
        uint256 indexed index,
        uint256 maximumTokens,
        string assetURI
    );

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

    //
    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    // Owner Functions
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

    function setRoyalty(address _account, uint96 _fee) external onlyOwner {
        _setDefaultRoyalty(_account, _fee);
    }

    function removeRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function setBaseURI(string calldata _baseURI, uint256 _rewardIndex)
        external
        onlyOwner
    {
        rewards[_rewardIndex].baseURI = _baseURI;
    }

    function releaseReward(uint256 tokenId) external {
        uint256 _rewardIndex = getRewardIndex(tokenId);
        require(
            (rewards[_rewardIndex].distributionStartTime <= block.timestamp &&
                rewards[_rewardIndex].distributionEndTime > block.timestamp),
            "INVALID_DISTRIBUTION_PERIOD"
        );
        require(_exists(tokenId), "nonexistent token");

        uint256 totalReceived = rewards[_rewardIndex].totalBalance +
            rewards[_rewardIndex].totalReleased;
        uint256 payment = totalReceived /
            rewards[_rewardIndex].maximumTokens -
            rewards[_rewardIndex].released[tokenId];

        require(payment != 0, "no due payment");

        rewards[_rewardIndex].released[tokenId] += payment;
        rewards[_rewardIndex].totalReleased += payment;
        _decreaseBalance(payment, _rewardIndex);
        Address.sendValue(payable(ownerOf(tokenId)), payment);
        emit PaymentReleased(tokenId, payment, ownerOf(tokenId));
    }

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

    function _increaseBalance(uint256 _value, uint256 _rewardIndex) internal {
        rewards[_rewardIndex].totalBalance += _value;
    }

    function _decreaseBalance(uint256 _value, uint256 _rewardIndex) internal {
        rewards[_rewardIndex].totalBalance -= _value;
    }

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
        // }
    }

    function getRewardIndex(uint256 _tokenId) public view returns (uint256) {
        return _tokenId / PREFIX_MULTIPLIER;
    }

    receive() external payable {
        revert("NOT_ALLOWED");
    }
}

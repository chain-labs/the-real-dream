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

    constructor(
        uint256 _maximumTokens,
        uint256 _cooldownPeriod,
        uint256 _minimumDistributionPeriod,
        string memory _name,
        string memory _symbol,
        string memory _baseURI
    ) ERC721(_name, _symbol) {
        data.maximumTokens = _maximumTokens;
        data.baseURI = _baseURI;
        data.cooldownPeriod = _cooldownPeriod;
        data.minimumDistributionPeriod = _minimumDistributionPeriod;
    }

    //
    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    // Owner Functions
    function airdrop(address[] calldata _receivers) external onlyOwner {
        require(_receivers.length > 0, "ZERO_RECEIVERS_COUNT");
        require(
            data.totalSupply + _receivers.length <= data.maximumTokens,
            "MAX_TOKENS_REACHED"
        );
        for (uint256 i; i < _receivers.length; i++) {
            unchecked {
                data.totalSupply = data.totalSupply + 1;
            }
            _safeMint(_receivers[i], data.totalSupply);
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
        uint256 _distributionEndTime
    ) external payable onlyOwner {
        require(data.totalSupply == data.maximumTokens, "TOKENS_NOT_DISTRIBUTED");
        require(_distributionEndTime - _distributionStartTime >= data.minimumDistributionPeriod, "SHORT_DISTRIBUTION_PERIOD");
        require(
            _distributionStartTime >= block.timestamp + data.cooldownPeriod,
            "SHORT_NOTICE"
        );
        data.distributionStartTime = _distributionStartTime;
        data.distributionEndTime = _distributionEndTime;
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

    function setBaseURI(string calldata _baseURI) external onlyOwner {
        data.baseURI = _baseURI;
    }

    function releaseReward(uint256 tokenId) external {
        require(
            (data.distributionStartTime <= block.timestamp &&
                data.distributionEndTime > block.timestamp),
            "INVALID_DISTRIBUTION_PERIOD"
        );
        require(_exists(tokenId), "nonexistent token");

        uint256 totalReceived = address(this).balance + data.totalReleased;
        uint256 payment = totalReceived / data.maximumTokens - data.released[tokenId];

        require(payment != 0, "no due payment");

        data.released[tokenId] += payment;
        data.totalReleased += payment;

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

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json"))
                : "";
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return data.baseURI;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        // if (distributionEndTime != 0 && distributionStartTime != 0) {
        require(
            !(data.distributionStartTime <= block.timestamp &&
                data.distributionEndTime > block.timestamp),
            "TRANSFER_PAUSED"
        );
        // }
    }
}

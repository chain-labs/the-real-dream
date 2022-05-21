pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
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
    ERC721Enumerable,
    ERC2981,
    TheRealDreamStorage
{
    using Strings for uint256;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maximumTokens,
        string memory _baseURI
    ) ERC721(_name, _symbol) {
        maximumTokens = _maximumTokens;
        baseURI = _baseURI;
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
            totalSupply() + _receivers.length <= maximumTokens,
            "MAX_TOKENS_REACHED"
        );
        for (uint256 i; i < _receivers.length; i++) {
            _safeMint(_receivers[i], totalSupply() + 1);
        }
    }

    function setRoyalty(address _account, uint96 _fee) external onlyOwner {
        _setDefaultRoyalty(_account, _fee);
    }

    function removeRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function setBaseURI(string calldata _baseURI) external onlyOwner {
        baseURI = _baseURI;
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
        return baseURI;
    }
}

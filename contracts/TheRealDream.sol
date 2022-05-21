pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import ".//TheRealDreamStorage.sol";

contract TheRealDream is Ownable, Pausable, ReentrancyGuard, ERC721, TheRealDreamStorage {

    constructor (string memory _name, string memory _symbol) ERC721(_name, _symbol) {} 

    // 
    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

 contract solidityPart2Task2 is ERC721, Ownable, ERC721URIStorage {

    // 构造函数设置NFT的名称和符号
    constructor(address initailOwner) ERC721("solidityPart2Task2", "MCL") Ownable(initailOwner) {
        
    }
     // mintNFT函数：允许用户铸造NFT，并关联元数据连接
    function mintNFT(address to, uint256 tokenId,string memory uri) public onlyOwner {
        _mint(to, tokenId);
        _setTokenURI(tokenId, uri);
        
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override (ERC721, ERC721URIStorage) returns(bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }


 }
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
<<<<<<< HEAD
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AstroFeed is ERC721, ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenID;
    uint256 MAX_SUPPLY = 500;
    // uint256 _Price = 85000000000000000; // 0.085 ETH
    mapping(uint256 => address) public minter;

    constructor() ERC721("ATC", "ATC") {}

    function _tokenMint() private {
        _tokenID.increment();
        uint256 tokenId = _tokenID.current();
        minter[tokenId] = msg.sender;
        _safeMint(msg.sender, tokenId);
    }

    function mint(uint256 mintCount) public nonReentrant {
        uint256 count = _tokenID.current() + mintCount;
        require(count <= MAX_SUPPLY, "Maximum supply reached.");

        for (uint256 i = 0; i < mintCount; i++) {
            _tokenMint();
        }
    }

    function getTokenId() public view returns (uint256) {
        return _tokenID.current();
    }

    function uint2str(
        uint _i
    ) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
=======
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AstroFeed is ERC1155, ReentrancyGuard, Ownable {

    uint256 private constant tokenID = 1;
    mapping(uint256 => string) private tokenURI;

    constructor() ERC1155("https://game.example/api/item/{id}.json")
    {
    }

    function mintToken() external nonReentrant onlyOwner{
        _mint(msg.sender, tokenID, 1, "0x00");
    }

}
>>>>>>> 3cb8abbbf5862d64149e1ad8cefbccf20942533c

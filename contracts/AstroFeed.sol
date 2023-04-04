// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AstroFeed is ERC1155, ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;

    struct MintToken {
        address minter_address;
        uint256 royalty;
    }

    Counters.Counter private _tokenID;
    uint256 MAX_SUPPLY = 500;

    mapping(uint256 => MintToken) public minter;

    constructor() ERC1155("https://infura.io/{id}.json") {}

    function mint(uint256 mintCount, uint256 royalty) public nonReentrant {
        uint256 count = _tokenID.current() + mintCount;
        require(count <= MAX_SUPPLY, "Maximum supply reached.");

        _tokenID.increment();
        uint256 tokenId = _tokenID.current();
        minter[tokenId] = MintToken(msg.sender, royalty);
        _mint(msg.sender, tokenId, mintCount, "");
    }

    function distribute() public payable {
        uint256 count = _tokenID.current();
        for (uint256 i = 0; i < count; i++) {
            payable(minter[i].minter_address).transfer(
                msg.value * (minter[i].royalty / 100)
            );
        }
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
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

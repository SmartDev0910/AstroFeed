// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AstroFeed is ERC1155, ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenID;
    Counters.Counter private _nftsSold;
    Counters.Counter private _nftCount;

    uint256 MAX_SUPPLY = 500;
    uint256 public LISTING_FEE = 0.0001 ether;

    mapping(uint256 => NFT) private _idToNFT;
    struct NFT {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool listed;
    }
    event NFTListed(
        uint256 tokenId,
        address seller,
        address owner,
        uint256 price
    );
    event NFTSold(
        uint256 tokenId,
        address seller,
        address owner,
        uint256 price
    );

    struct MintToken {
        address minter_address;
        uint256 royalty;
    }

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
                (msg.value * (minter[i].royalty / 100)) / count
            );
        }
    }

    // List the NFT on the marketplace
    function listNft(
        uint256 _tokenId,
        uint256 _price
    ) public payable nonReentrant {
        require(_price > 0, "Price must be at least 1 wei");

        IERC1155(address(this)).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
            1,
            ""
        );

        distribute();
        _nftCount.increment();

        _idToNFT[_tokenId] = NFT(
            _tokenId,
            payable(msg.sender),
            payable(address(this)),
            _price,
            true
        );

        emit NFTListed(_tokenId, msg.sender, address(this), _price);
    }

    // Buy an NFT
    function buyNft(uint256 _tokenId) public payable nonReentrant {
        NFT storage nft = _idToNFT[_tokenId];
        require(
            msg.value >= nft.price,
            "Not enough ether to cover asking price"
        );

        address payable buyer = payable(msg.sender);
        payable(nft.seller).transfer(msg.value);
        IERC1155(address(this)).safeTransferFrom(
            address(this),
            buyer,
            nft.tokenId,
            1,
            ""
        );
        nft.owner = buyer;
        nft.listed = false;

        _nftsSold.increment();
        emit NFTSold(nft.tokenId, nft.seller, buyer, msg.value);
    }

    // Resell an NFT purchased from the marketplace
    function resellNft(
        uint256 _tokenId,
        uint256 _price
    ) public payable nonReentrant {
        require(_price > 0, "Price must be at least 1 wei");
        require(msg.value == LISTING_FEE, "Not enough ether for listing fee");
        IERC1155(address(this)).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
            1,
            ""
        );

        NFT storage nft = _idToNFT[_tokenId];
        nft.seller = payable(msg.sender);
        nft.owner = payable(address(this));
        nft.listed = true;
        nft.price = _price;

        _nftsSold.decrement();
        emit NFTListed(_tokenId, msg.sender, address(this), _price);
    }

    function getListedNfts() public view returns (NFT[] memory) {
        uint256 nftCount = _nftCount.current();
        uint256 unsoldNftsCount = nftCount - _nftsSold.current();

        NFT[] memory nfts = new NFT[](unsoldNftsCount);
        uint nftsIndex = 0;
        for (uint i = 0; i < nftCount; i++) {
            if (_idToNFT[i + 1].listed) {
                nfts[nftsIndex] = _idToNFT[i + 1];
                nftsIndex++;
            }
        }
        return nfts;
    }

    function getMyNfts() public view returns (NFT[] memory) {
        uint nftCount = _nftCount.current();
        uint myNftCount = 0;
        for (uint i = 0; i < nftCount; i++) {
            if (_idToNFT[i + 1].owner == msg.sender) {
                myNftCount++;
            }
        }

        NFT[] memory nfts = new NFT[](myNftCount);
        uint nftsIndex = 0;
        for (uint i = 0; i < nftCount; i++) {
            if (_idToNFT[i + 1].owner == msg.sender) {
                nfts[nftsIndex] = _idToNFT[i + 1];
                nftsIndex++;
            }
        }
        return nfts;
    }

    function getMyListedNfts() public view returns (NFT[] memory) {
        uint nftCount = _nftCount.current();
        uint myListedNftCount = 0;
        for (uint i = 0; i < nftCount; i++) {
            if (
                _idToNFT[i + 1].seller == msg.sender && _idToNFT[i + 1].listed
            ) {
                myListedNftCount++;
            }
        }

        NFT[] memory nfts = new NFT[](myListedNftCount);
        uint nftsIndex = 0;
        for (uint i = 0; i < nftCount; i++) {
            if (
                _idToNFT[i + 1].seller == msg.sender && _idToNFT[i + 1].listed
            ) {
                nfts[nftsIndex] = _idToNFT[i + 1];
                nftsIndex++;
            }
        }
        return nfts;
    }

    function setMaxSupply(uint256 maxSupply) public onlyOwner {
        MAX_SUPPLY = maxSupply;
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

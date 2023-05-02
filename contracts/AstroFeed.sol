// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@thirdweb-dev/contracts/base/ERC1155SignatureMint.sol";
import {ITokenERC1155} from "@thirdweb-dev/contracts/interfaces/token/ITokenERC1155.sol";

contract AstroFeed is ERC1155SignatureMint, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenID;
    Counters.Counter private _nftsSold;
    Counters.Counter private _nftCount;

    uint256 MAX_SUPPLY = 500;
    uint256 MAX_ROYALTY = 4000;
    uint256 public royaltyCost = 0;
    address private immutable _primarySaleRecipient;

    struct NFT {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        uint256 fee;
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
        address holder_address;
        uint256 royaltyBps;
    }

    mapping(uint256 => NFT) private _idToNFT;
    mapping(uint256 => MintToken) public minter;
    mapping(uint256 => bool) public isApproved;

    constructor(
        string memory name,
        string memory symbol,
        address royaltyRecipient,
        uint128 royaltyBps,
        address primarySaleRecipient
    )
        ERC1155SignatureMint(
            name,
            symbol,
            royaltyRecipient,
            royaltyBps,
            primarySaleRecipient
        )
    {
        _primarySaleRecipient = primarySaleRecipient;
    }

    function mint(
        MintRequest calldata _req,
        bytes calldata _signature
    ) public nonReentrant {
        uint256 count = _tokenID.current() + 1;
        require(count <= MAX_SUPPLY, "Maximum supply reached.");
        require(_req.royaltyBps <= MAX_ROYALTY, "Maximum royaltyBps reached.");

        _tokenID.increment();
        uint256 tokenId = _tokenID.current();
        minter[tokenId] = MintToken(msg.sender, _req.royaltyBps);

        // Mint tokens.
        _mint(msg.sender, tokenId, _req.quantity, "");

        emit TokensMintedWithSignature(
            _processRequest(_req, _signature),
            msg.sender,
            tokenId,
            _req
        );
    }

    function distribute() public payable onlyOwner {
        uint256 count = _tokenID.current();
        for (uint256 i = 0; i < count; i++) {
            payable(minter[i].holder_address).transfer(royaltyCost / count);
        }
    }

    function uri(uint256 tokenId) public pure override returns (string memory) {
        string memory hexstringtokenID;
        hexstringtokenID = uint2hexstr(tokenId);

        return string(abi.encodePacked("ipfs://f0", hexstringtokenID));
    }

    // Approve the NFT before list it.
    function approveNft(uint256 _tokenId) public {
        require(
            minter[_tokenId].holder_address == msg.sender,
            "You are not the minter of this NFT."
        );
        isApproved[_tokenId] = true;
    }

    // List the NFT on the marketplace
    function listNft(
        uint256 _tokenId,
        uint256 _price,
        uint256 _fee
    ) public payable nonReentrant {
        require(_price > 0, "Price must be at least 1 wei");
        require(isApproved[_tokenId] == true, "This NFT is not approved.");

        _nftCount.increment();

        _idToNFT[_tokenId] = NFT(
            _tokenId,
            payable(msg.sender),
            payable(msg.sender),
            _price,
            _fee,
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

        require(
            minter[_tokenId].royaltyBps + nft.fee <= MAX_ROYALTY,
            "Maximum royaltyBps reached."
        );

        address payable buyer = payable(msg.sender);

        minter[_tokenId].holder_address = buyer;

        payable(nft.seller).transfer(
            msg.value * ((1000 - (minter[_tokenId].royaltyBps + nft.fee)) / 100)
        );

        royaltyCost += msg.value * (minter[_tokenId].royaltyBps / 100);

        ITokenERC1155(msg.sender).safeTransferFrom(
            nft.seller,
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

    function uint2hexstr(uint256 i) public pure returns (string memory) {
        if (i == 0) return "0";
        uint j = i;
        uint length;
        while (j != 0) {
            length++;
            j = j >> 4;
        }
        uint mask = 15;
        bytes memory bstr = new bytes(length);
        uint k = length;
        while (i != 0) {
            uint curr = (i & mask);
            bstr[--k] = curr > 9
                ? bytes1(uint8(55 + curr))
                : bytes1(uint8(48 + curr)); // 55 = 65 - 10
            i = i >> 4;
        }
        return string(bstr);
    }
}

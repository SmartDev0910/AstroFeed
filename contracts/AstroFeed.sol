// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AstroFeed is ERC1155, ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _items;
    Counters.Counter private _soldItems;
    Counters.Counter private _tokenID;
    uint256 MAX_SUPPLY = 500;

    address payable owner;

    // interface to marketplace item
    struct MarketplaceItem {
        uint256 itemId;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }

    mapping(uint256 => MarketplaceItem) private idToMarketplaceItem;

    // declare a event for when a item is created on marketplace
    event MarketplaceItemCreated(
        uint256 indexed itemId,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    struct MintToken {
        address minter_address;
        uint256 royalty;
    }

    mapping(uint256 => MintToken) public minter;

    constructor() ERC1155("https://infura.io/{id}.json") {
        owner = payable(msg.sender);
    }

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

    function setMaxSupply(uint256 maxSupply) public onlyOwner {
        MAX_SUPPLY = maxSupply;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getTokenId() public view returns (uint256) {
        return _tokenID.current();
    }

    // places an item for sale on the marketplace
    function createMarketplaceItem(
        uint256 tokenId,
        uint256 price
    ) public payable nonReentrant {
        require(price > 0, "Price must be at least 1 wei");

        _items.increment();
        uint256 itemId = _items.current();

        idToMarketplaceItem[itemId] = MarketplaceItem(
            itemId,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            price,
            false
        );

        IERC1155(address(this)).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            1,
            ""
        );

        emit MarketplaceItemCreated(
            itemId,
            tokenId,
            msg.sender,
            address(0),
            price,
            false
        );
    }

    // creates the sale of a marketplace item
    // transfers ownership of the item, as well as funds between parties
    function createMarketplaceSale(uint256 itemId) public payable nonReentrant {
        uint256 price = idToMarketplaceItem[itemId].price;
        uint256 tokenId = idToMarketplaceItem[itemId].tokenId;

        require(
            msg.value == price,
            "Please submit the asking price in order to complete the purchase"
        );

        idToMarketplaceItem[itemId].seller.transfer(msg.value);
        IERC1155(address(this)).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId,
            1,
            ""
        );

        idToMarketplaceItem[itemId].owner = payable(msg.sender);
        idToMarketplaceItem[itemId].sold = true;

        _soldItems.increment();

        distribute();
        // payable(owner).transfer(listingPrice);
    }

    // returns all unsold marketplace items
    function fetchMarketplaceItems()
        public
        view
        returns (MarketplaceItem[] memory)
    {
        uint256 itemCount = _items.current();
        uint256 unsoldItemCount = _items.current() - _soldItems.current();
        uint256 currentIndex = 0;

        MarketplaceItem[] memory items = new MarketplaceItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketplaceItem[i + 1].owner == address(0)) {
                uint256 currentId = i + 1;
                MarketplaceItem storage currentItem = idToMarketplaceItem[
                    currentId
                ];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    // returns only items that a user has purchased
    function fetchMyNFTs() public view returns (MarketplaceItem[] memory) {
        uint256 totalItemCount = _items.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketplaceItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketplaceItem[] memory items = new MarketplaceItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketplaceItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketplaceItem storage currentItem = idToMarketplaceItem[
                    currentId
                ];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    // returns only items a user has created
    function fetchItemsCreated()
        public
        view
        returns (MarketplaceItem[] memory)
    {
        uint256 totalItemCount = _items.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketplaceItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        MarketplaceItem[] memory items = new MarketplaceItem[](itemCount);

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketplaceItem[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                MarketplaceItem storage currentItem = idToMarketplaceItem[
                    currentId
                ];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
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

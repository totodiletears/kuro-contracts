// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC721Enumerable, Ownable {
    using Strings for uint256;

    string baseURI;
    string public baseExtension = ".json";
    uint256 public max = 50000;
    uint256 public greyTotal = 0;
    uint256 public greenTotal = 0;
    uint256 public purpleTotal = 0;
    uint256 public cost = 10 ether;
    uint256 public maxAmountPerMint = 50;
    bool public paused = false;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI
    ) ERC721(_name, _symbol) {
        setBaseURI(_initBaseURI);
    }

    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    mapping(uint => uint) nftColor;

    // grey is color ID 0
    function mintGrey(uint256 _amount) public payable {
        require(!paused);
        require(_amount > 0, "cant mint zero");
        require(greyTotal + _amount <= max, "more than exists");
        require(_amount <= maxAmountPerMint, "max per mint exceeded");
        uint256 supply = totalSupply();

        if (msg.sender != owner()) {
            require(msg.value >= cost * _amount);
        }

        for (uint i = 1; i <= _amount; i++) {
            setColor(supply + i, 0);
            greyTotal++;
            _safeMint(msg.sender, supply + i);
        }
    }

    // green is color ID 1
    function mintGreen(uint256 _amount) public payable {
        require(!paused);
        require(_amount > 0, "cant mint zero");
        require(greenTotal + _amount <= max, "more than exists");
        require(_amount <= maxAmountPerMint, "max per mint exceeded");
        uint256 supply = totalSupply();

        if (msg.sender != owner()) {
            require(msg.value >= cost * _amount);
        }

        for (uint i = 1; i <= _amount; i++) {
            setColor(supply + i, 1);
            greenTotal++;
            _safeMint(msg.sender, supply + i);
        }
    }

    // purple is color ID 2
    function mintPurple(uint256 _amount) public payable {
        require(!paused);
        require(_amount > 0, "cant mint zero");
        require(purpleTotal + _amount <= max, "more than exists");
        require(_amount <= maxAmountPerMint, "max per mint exceeded");
        uint256 supply = totalSupply();

        if (msg.sender != owner()) {
            require(msg.value >= cost * _amount);
        }

        for (uint i = 1; i <= _amount; i++) {
            setColor(supply + i, 2);
            purpleTotal++;
            _safeMint(msg.sender, supply + i);
        }
    }

    function withdraw() public payable onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }

    function setColor(uint256 _id, uint256 _color) internal {
        nftColor[_id] = _color;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
        baseExtension = _newBaseExtension;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
        _exists(tokenId),
        "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, nftColor[tokenId].toString(), baseExtension))
            : "";
    } 
}
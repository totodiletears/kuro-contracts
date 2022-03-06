// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Mint is ERC1155Holder, Ownable {
    IERC1155 public nftToken;
    IERC20 public erc20Token;

    address[] public airdropList;

    address collector;
    address nftContract;
    uint256 remaining;
    uint256 minted;
    uint256 supply;
    uint256 cost;
    bool paused;

    constructor(
        IERC1155 _nftToken,
        address _nftContract,
        IERC20 _erc20Token,
        address _collector,
        uint256 _supply,
        uint256 _cost
    ) {
        nftToken = _nftToken;
        nftContract = _nftContract;
        erc20Token = _erc20Token;
        collector = _collector;
        supply = _supply;
        cost = _cost; // kuro
        paused = true;
        minted = 0;
    }

    // buy

    function mint(address _nftContract) public payable {
        require(_nftContract == nftContract, "Wrong Contract Address");
        require(!paused, "Contract: Paused");
        require(minted + 1 <= supply, "Contract: Sold out");
        require(
            erc20Token.balanceOf(msg.sender) >= cost,
            "Contract: You don't have enough KURO"
        );
        erc20Token.transferFrom(msg.sender, collector, cost);
        nftToken.safeTransferFrom(address(this), msg.sender, minted + 1, 1, "");
        airdropList.push(msg.sender);
        minted++;
    }

    // misc

    function nftsRemaining() public view returns (uint256) {
        return supply - minted;
    }

    function setCost(uint256 _cost) public onlyOwner {
        cost = _cost;
    }

    function getCost() public view returns (uint256) {
        return cost;
    }

    function setCollector(address _collector) public onlyOwner {
        collector = _collector;
    }

    function getCollector() public view returns (address) {
        return collector;
    }

    function setSupply(uint256 _supply) public onlyOwner {
        supply = _supply;
    }

    function getSupply() public view returns (uint256) {
        return supply;
    }

    function setPause(bool _pause) public onlyOwner {
        paused = _pause;
    }

    function isPaused() public view returns (bool) {
        return paused;
    }

    function totalMinted() public view returns (uint256) {
        return minted;
    }

    function getBalance() public view returns (uint256) {
        return erc20Token.balanceOf(msg.sender);
    }

    function getMinterAddress() public view returns (address) {
        return address(this);
    }
}

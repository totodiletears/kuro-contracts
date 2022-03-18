// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IStaking {
    function stakeNFT(address from, uint256 id) external;

    function stakeMultipleNFTs(address from, uint256[] calldata tokenIds)
        external;
}

interface IMarketplace {
    function sellNFT(
        address _seller,
        uint256 _id,
        uint256 _price
    ) external;

    function sellMultipleNFTs(
        address _seller,
        uint256[] calldata _ids,
        uint256[] calldata _prices
    ) external;
}

contract NFTs is ERC1155Supply, Ownable {
    // Here you would define your game items, like the  accessories, treats, etc.

    IStaking public stakingContract;
    IMarketplace public marketplaceContract;

    uint256 public supply;

    constructor(uint256 _supply) ERC1155("https://ipfs.io/") {
        supply = _supply;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    // @note Staking contract must be set after deployment since staking
    // contract needs the address of this contract on its deployement.
    function setStakingContract(address _contract) public onlyOwner {
        stakingContract = IStaking(_contract);
    }

    function setMarketplaceContract(address _contract) public onlyOwner {
        marketplaceContract = IMarketplace(_contract);
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyOwner {
        _mint(account, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }

    function isNFT(uint256 id) public view returns (bool) {
        return totalSupply(id) == 1;
    }

    // Transfers NFT from caller to the staking contract.
    function stakeNFT(uint256 id) external {
        // Check to make sure it's actually an NFT
        require(isNFT(id), "Token ID is not an NFT");
        safeTransferFrom(msg.sender, address(stakingContract), id, 1, "");
        stakingContract.stakeNFT(msg.sender, id);
    }

    // NOTE: Due to the unavoidable gas limit of the Ethereum network,
    // a large amount of NFTs transfered could result to a failed transaction.
    // *An alt scenerio would be to approve all NFTs to the staking contract,
    // then call a function in the stake contract to batch transfer them all to itself.
    function stakeMultipleNFTs(uint256[] calldata ids) external {
        // Array needed to pay out the NFTs
        uint256[] memory amounts = new uint256[](ids.length);
        for (uint256 i; i < ids.length; i++) {
            require(isNFT(ids[i]), "Token ID is not an NFT");
            amounts[i] = 1;
        }

        safeBatchTransferFrom(
            msg.sender,
            address(stakingContract),
            ids,
            amounts,
            ""
        );
        stakingContract.stakeMultipleNFTs(msg.sender, ids);
    }

    function sellNFT(uint256 id, uint256 price) external {
        require(price >= 1e9, "Minimum amount must be greater than 1");
        require(isNFT(id), "Token ID is not an NFT");
        safeTransferFrom(msg.sender, address(marketplaceContract), id, 1, "");
        marketplaceContract.sellNFT(msg.sender, id, price);
    }

    function sellMultipleNFTs(uint256[] calldata ids, uint256[] calldata prices)
        external
    {
        uint256[] memory amounts = new uint256[](ids.length);
        for (uint256 i; i < ids.length; i++) {
            require(prices[i] >= 1e9, "Minimum amount must be greater than 1");
            require(isNFT(ids[i]), "Token ID is not an NFT");
            amounts[i] = 1;
        }

        safeBatchTransferFrom(
            msg.sender,
            address(marketplaceContract),
            ids,
            amounts,
            ""
        );
        marketplaceContract.sellMultipleNFTs(msg.sender, ids, prices);
    }

    function setSupply(uint256 _supply) public onlyOwner {
        supply = _supply;
    }

    function getTokensAvailableForTransfer(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory helper = new uint256[](supply);
        uint256 lengthOfHelper = 0;
        uint256 j = 0;
        for (uint256 i; i < supply; i++) {
            if (balanceOf(_owner, i + 1) == 1) {
                helper[j] = i + 1;
                j++;
            }
        }

        for (uint256 k; k < supply; k++) {
            if (helper[k] > 0) {
                lengthOfHelper++;
            } else if (helper[k] == 0) {
                break;
            }
        }

        uint256[] memory result = new uint256[](lengthOfHelper);

        for (uint256 l; l < lengthOfHelper; l++) {
            result[l] = helper[l];
        }

        return result;
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.11;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract NFTSwap is ERC1155Holder {
    IERC1155 public oldNFT;

    uint256 public supply;

    mapping(uint256 => address) public list;
    mapping(address => bool) public turnedIn;

    constructor(address _oldNFTContract, uint256 _supply) {
        oldNFT = IERC1155(_oldNFTContract);
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
            if (oldNFT.balanceOf(_owner, i + 1) == 1) {
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

    function _saveList(address owner, uint256[] memory ids) internal {
        for (uint256 i; i < ids.length; i++) {
            list[ids[i]] = owner;
        }
    }

    function updateList(address owner) public {
        require(turnedIn[owner] == false);
        uint256[] memory ids = getTokensAvailableForTransfer(owner);
        uint256[] memory amounts = new uint256[](ids.length);

        for (uint256 i; i < ids.length; i++) {
            amounts[i] = 1;
        }

        oldNFT.safeBatchTransferFrom(owner, address(this), ids, amounts, "");

        for (uint256 i; i < ids.length; i++) {
            require(oldNFT.balanceOf(address(this), ids[i]) == 1);
        }

        _saveList(owner, ids);
        turnedIn[owner] = true;
    }

    function getList() public view returns (address[] memory) {
        address[] memory fullList = new address[](supply);

        for (uint256 i; i < supply; i++) {
            fullList[i] = list[i + 1];
        }

        return fullList;
    }
}

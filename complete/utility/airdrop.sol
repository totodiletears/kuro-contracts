// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @notice Airdrop contract for Masterbrews Test
 */
contract ERC1155Airdrop is Context, ReentrancyGuard {
    /// @notice ERC1155 NFT
    IERC1155 public token;

    event AirdropContractDeployed();
    event AirdropFinished(uint256 tokenId, address[] recipients);

    address[] public recipientArray;
    uint[] public recipientId;
    /**
     * @dev Constructor Function
     */
    constructor(IERC1155 _token) {
        require(address(_token) != address(0), "Invalid NFT");

        token = _token;

        emit AirdropContractDeployed();
    }

    /**
     * @dev Owner of token can airdrop tokens to recipients
     * @param _tokenId id of the token
     * @param _recipients addresses of recipients
     */
    function airdrop(uint256 _tokenId, address[] memory _recipients)
        external
        nonReentrant
    {

        require(
            token.isApprovedForAll(_msgSender(), address(this)),
            "Owner has not approved"
        );
        require(
            _recipients.length > 0,
            "Recipients should be greater than 0"
        );
        require(
            _recipients.length <= 1000,
            "Recipients should be smaller than 1000"
        );

        for (uint256 i = 0; i < _recipients.length; i++) {
            token.safeTransferFrom(
                _msgSender(),
                _recipients[i],
                _tokenId + i,
                1,
                ""
            );
            recipientArray.push(_recipients[i]);
            recipientId.push(_tokenId + i);
        }

        emit AirdropFinished(_tokenId, _recipients);
    }

    function getAddresses()public view returns(address[] memory){
        return recipientArray;
    }

}
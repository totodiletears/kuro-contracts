	function stakeMultipleNFTs(uint[] calldata ids) external {
		// Array needed to pay out the NFTs
		uint[] memory amounts = new uint[](ids.length);
		for (uint i; i < ids.length; i++) {
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

	function stakeMultipleNFTs(address from, uint[] calldata tokenIds)
		external
		onlyNFT
	{
		for (uint i; i < tokenIds.length; i++) {
			uint tokenId = tokenIds[i]; // gas saver
			// Checks to make sure this contract received the NFT.
			require(
				nftToken.balanceOf(address(this), tokenId) == 1,
				"Stake: Token Transfer Failed"
			);

			receipt[tokenId].owner = from;
			receipt[tokenId].stakedFromBlock = block.number;
			stakedNFTs[from].push(tokenId);

			emit NFTStaked(from, tokenId, block.number);
		}
		totalNFTsStaked += tokenIds.length;
	}






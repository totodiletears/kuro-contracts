	function unstakeMultipleNFTs(uint[] calldata tokenIds) external nonReentrant {
		// Array needed to pay out the NFTs
		uint[] memory amounts = new uint[](tokenIds.length);
		uint[] storage _stakedNFTs = stakedNFTs[msg.sender]; // gas saver

		for (uint i; i < tokenIds.length; i++) {
			uint id = tokenIds[i]; // gas saver

			_onlyStaker(id);
			_requireTimeElapsed(id);
			_payoutStake(id);
			amounts[i] = 1;

			// Finds the ID in the array and removes it.
			for (uint x; x < _stakedNFTs.length; x++) {
				if (id == _stakedNFTs[x]) {
					_stakedNFTs[x] = _stakedNFTs[_stakedNFTs.length - 1];
					_stakedNFTs.pop();
					break;
				}
			}

			emit NFTUnStaked(msg.sender, id, receipt[id].stakedFromBlock);
		}

		nftToken.safeBatchTransferFrom(
			address(this),
			msg.sender,
			tokenIds,
			amounts,
			""
		);
		totalNFTsStaked -= tokenIds.length;
	}
	function unstakeNFT(uint tokenId) external nonReentrant {
		_onlyStaker(tokenId);
		_requireTimeElapsed(tokenId);
		_payoutStake(tokenId);

		uint[] memory _stakedNFTs = stakedNFTs[msg.sender]; // gas saver
		for (uint i; i < _stakedNFTs.length; i++) {
			if (_stakedNFTs[i] == tokenId) {
				stakedNFTs[msg.sender][i] = _stakedNFTs[_stakedNFTs.length - 1];
				stakedNFTs[msg.sender].pop();
			}
		}
		nftToken.safeTransferFrom(address(this), msg.sender, tokenId, 1, "");
		totalNFTsStaked--;
	}

	// This function is called when a user wants to withdraw their funds without
	// unstaking their NFT
	function withdrawRewards(uint[] calldata tokenIds) external nonReentrant {
		for (uint i; i < tokenIds.length; i++) {
			uint tokenId = tokenIds[i]; // gas saver
			_onlyStaker(tokenId);
			_requireTimeElapsed(tokenId);
			_payoutStake(tokenId);

			// update receipt with a new block number
			receipt[tokenId].stakedFromBlock = block.number;
		}
	}

	// Withdraws rewards from all NFTs staked without passing in an array of specific
	// token IDs from which you want to withdraw from
	// NOTE: Cheaper on gas to pass in the array of tokenIDs rather than not
	// but by not passing the array in it can withdraw everything while the other can
	// specify only the NFT rewards you'd like to withdraw from.
	function withdrawRewardsNoArray() external nonReentrant {
		uint[] memory _stakedNFTs = stakedNFTs[msg.sender]; // gas saver
		for (uint i; i < _stakedNFTs.length; i++) {
			uint tokenId = _stakedNFTs[i];
			_onlyStaker(tokenId);
			_requireTimeElapsed(tokenId);
			_payoutStake(tokenId);

			// update receipt with a new block number
			receipt[tokenId].stakedFromBlock = block.number;
		}
	}

	// NOTE: To only be called by a nonReentrant function.
	// This function is meant to be called by other functions within the smart contract.
	// Never called externally by the client.
	function _payoutStake(uint tokenId) private {
		Stake memory _tokenId = receipt[tokenId]; // gas saver

		// earned amount is difference between the stake start block, current block multiplied by stake amount
		uint timeStaked = (block.number - _tokenId.stakedFromBlock) - 1; // don't pay for the tx block of withdrawl
		uint payout = timeStaked * tokensPerBlock;

		// If contract does not have enough tokens to pay out, return the NFT without payment
		// This prevent a NFT being locked in the contract when empty
		if (erc20Token.balanceOf(address(this)) < payout) {
			emit StakePayout(
				msg.sender,
				tokenId,
				0,
				_tokenId.stakedFromBlock,
				block.number
			);
		} else {
			// payout stake
			erc20Token.transfer(_tokenId.owner, payout);
            pastClaims[_tokenId.owner] += payout;
			emit StakePayout(
				msg.sender,
				tokenId,
				payout,
				_tokenId.stakedFromBlock,
				block.number
			);
		}
	}
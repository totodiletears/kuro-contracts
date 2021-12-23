// SPDX-License-Identifier: MIT
pragma solidity = 0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GuestStake is IERC721Receiver, ReentrancyGuard, Ownable {
    IERC721 public nftToken;
    IERC20 public erc20Token;
    IERC20 public feeToken;

    address private collector;
    uint public fee;

    uint public tokensPerBlock;
    uint public totalNFTsStaked;
    uint public totalFeesPaid;

    struct Stake {
        address owner;
        uint stakedFromBlock;
    }

    mapping(uint => Stake) public receipt;
    mapping(address => uint[]) public stakedNFTs;
    mapping(address => uint) public pastClaims;
    mapping(address => bool) public paidFee;

    event NFTStaked(address indexed staker, uint tokenId, uint blockNumber);
    event NFTUnStaked(address indexed staker, uint tokenId, uint blockNumber);
    event StakePayout(
        address indexed staker,
        uint tokenId,
        uint stakeAmount,
        uint fromBlock,
        uint toBlock
    );
    event StakeRewardUpdated(uint rewardPerBlock);

    constructor(
        address _nftToken,
        address _erc20Token,
        address _feeToken,
        address _collector,
        uint _fee,
        uint _tokensPerBlock
    ) {
        nftToken = IERC721(_nftToken);
        erc20Token = IERC20(_erc20Token);
        feeToken = IERC20(_feeToken);
        collector = _collector;
        tokensPerBlock = _tokensPerBlock;
        fee = _fee;

        emit StakeRewardUpdated(tokensPerBlock);
    }

    // set approval for all
    // important functions
    // stake
    function stakeNFT(address from, uint tokenId) internal {
        require(paidFee[from] == true);
        nftToken.safeTransferFrom(msg.sender, address(this), tokenId);
        require(
            nftToken.ownerOf(tokenId) == address(this),
            "Staking Failed"
        );

        receipt[tokenId].owner = from;
		receipt[tokenId].stakedFromBlock = block.number;
		stakedNFTs[from].push(tokenId);
		totalNFTsStaked++;

		emit NFTStaked(from, tokenId, block.number);
    }

    // stake multiple
    function stakeMultipleNFTs(address from, uint[] calldata ids) external nonReentrant {
        for (uint i; i < ids.length; i++) {
            stakeNFT(from, ids[i]);
		}
    }

    // unstake
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
		nftToken.safeTransferFrom(address(this), msg.sender, tokenId);
		totalNFTsStaked--;
	}

    // unstake multiple
	// function unstakeMultipleNFTs(uint[] calldata tokenIds) external nonReentrant {
	// 	// Array needed to pay out the NFTs
	// 	uint[] storage _stakedNFTs = stakedNFTs[msg.sender]; // gas saver

	// 	for (uint i; i < tokenIds.length; i++) {
	// 		uint id = tokenIds[i]; // gas saver

	// 		_onlyStaker(id);
	// 		_requireTimeElapsed(id);
	// 		_payoutStake(id);

	// 		// Finds the ID in the array and removes it.
	// 		for (uint x; x < _stakedNFTs.length; x++) {
	// 			if (id == _stakedNFTs[x]) {
	// 				_stakedNFTs[x] = _stakedNFTs[_stakedNFTs.length - 1];
	// 				_stakedNFTs.pop();
	// 				break;
	// 			}
	// 		}

	// 		emit NFTUnStaked(msg.sender, id, receipt[id].stakedFromBlock);
	// 	}

	// 	nftToken.safeTransferFrom(address(this), msg.sender, );
	// 	totalNFTsStaked -= tokenIds.length;
	// }


    // payout
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

    // withdraw
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

    // other functions
	function _requireTimeElapsed(uint tokenId) private view {
		require(
			receipt[tokenId].stakedFromBlock < block.number,
			"requireTimeElapsed: Can not stake/unStake/harvest in same block"
		);
	}

    // Returns an array of all the NFTs a user has staked
    function getAllNFTsUserStaked(address account)
        public
        view
        returns (uint[] memory)
    {
        return stakedNFTs[account];
    }

	function _getTimeStaked(uint256 tokenId) internal view returns (uint256) {
        if (receipt[tokenId].stakedFromBlock == 0) {
            return 0;
        }
        return receipt[tokenId].stakedFromBlock;
    }

	function _getCurrentStakeEarned(uint256 tokenId) public view returns (uint256) {
		if (receipt[tokenId].stakedFromBlock == 0) {
			return 0;
		}
		return (block.number - _getTimeStaked(tokenId)) * tokensPerBlock;
    }

	function getPendingRewards() public view returns (uint) {
		uint temp = 0;
        uint total = 0;
		uint[] memory _stakedNFTs = stakedNFTs[msg.sender];
		for (uint i; i < _stakedNFTs.length; i++) {
			uint tokenId = _stakedNFTs[i];
			temp += _getCurrentStakeEarned(tokenId);
		}
        // removes one block from pending
        total = temp - (tokensPerBlock * _stakedNFTs.length);
        if (total < 0) {
            return 0;
        }
		return total;
	}

    function getPastClaims() public view returns (uint) {
        return pastClaims[msg.sender];
    }

	// Returns the total amount of ERC20 tokens that this contract owns
	function getStakeContractBalance() public view returns (uint) {
		return erc20Token.balanceOf(address(this));
	}

	// Allows you to set a new ERC20 contract address
	function setERC20Contract(address _tokenAddress) public onlyOwner {
		erc20Token = IERC20(_tokenAddress);
	}

	// Allows you to set a new NFT contract address
	function setNFTContract(address _nftAddress) public onlyOwner {
		nftToken = IERC721(_nftAddress);
	}

	// Allows you to update the rewards per block amount
	function updateStakingReward(uint _tokensPerBlock) external onlyOwner {
		tokensPerBlock = _tokensPerBlock;
		emit StakeRewardUpdated(tokensPerBlock);
	}

	// Returns the length of the total amount an account has staked to this smart contract
	function totalNFTsUserStaked(address account) public view returns (uint) {
		return stakedNFTs[account].length;
	}

    // modifier
    function _onlyStaker(uint tokenId) private view {
        require(
            nftToken.ownerOf(tokenId) == address(this),
            "onlyStaker: Contract is not owner of this NFT"
        );
        require(
            receipt[tokenId].stakedFromBlock != 0,
            "onlyStaker: Token is not staked"
        );
        require(
            receipt[tokenId].owner == msg.sender,
            "onlyStaker: Caller is not NFT stake owner"
        );
    }

    // required by solidity
    /**
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function setCollector(address _collector) public onlyOwner {
        collector = _collector;
    }

    function setFee(uint _fee) public onlyOwner {
        fee = _fee;
    }

    // requires erc20 approval
    function payFee() external {
        require(paidFee[msg.sender] == false, "You already paid the fee");
        feeToken.transferFrom(msg.sender, collector, fee);
        paidFee[msg.sender] = true;
        totalFeesPaid += fee;
    } 

}
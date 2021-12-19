// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SingleStake is Ownable {
    IERC20 public kuro; // 9 dec
    IERC20 public wone; // 18 dec

    uint public tokensPerBlock;
    uint public totalKuroStaked;

    mapping(address => uint) stakedAmount;
    mapping(address => uint) stakedFromBlock;

    constructor(
		address _kuro,
		address _wone,
		uint _tokensPerBlock
	) {
		kuro = IERC20(_kuro);
		wone = IERC20(_wone);
		tokensPerBlock = _tokensPerBlock * 10 ** 18; // wone

		// emit StakeRewardUpdated(tokensPerBlock);
	}

    // need approval
    // stakes kuro
    function stake(uint amount) public payable {
        if (stakedAmount[msg.sender] != 0) {
            _claim();
        }
        kuro.transferFrom(msg.sender, address(this), amount);
        totalKuroStaked += amount;
        stakedAmount[msg.sender] += amount;
        stakedFromBlock[msg.sender] = block.number;
    }

    // unstakes kuro and claims rewards
    function unstake(uint amount) public {
        require(amount > 0, "cannot unstake 0");
        require(amount <= stakedAmount[msg.sender], "cannot unstake more than staked");

        // transfers amount to unstake
        kuro.transfer(msg.sender, amount);
        // claims rewards on all staked tokens
        _claim();
        // sets new amount staked for user
        stakedAmount[msg.sender] -= amount;
        // sets new amount staked for contract
        totalKuroStaked -= amount;
    }

    // claims rewards without unstaking
    function _claim() public {
        require(stakedAmount[msg.sender] > 0, "nothing staked");
        require(_getBlocksStaked() > 0, "KURO: No claiming in same block");
        
        // calculate rewards
        uint blocksStaked = block.number - stakedFromBlock[msg.sender];
        uint rewardOwed = getRewardRate() * stakedAmount[msg.sender] * blocksStaked;
        // transfer rewards
        wone.transfer(msg.sender, rewardOwed);
        // if still staked, reset staked from block
        if (stakedAmount[msg.sender] > 0) {
            stakedFromBlock[msg.sender] = block.number;
        // if unstaked, set staked from block to zero
        } else if (stakedAmount[msg.sender] == 0) {
            stakedFromBlock[msg.sender] = 0;
        }
    }

    // returns amount of kuro user staked
    function getUserKuroStaked() public view returns (uint) {
        return stakedAmount[msg.sender];
    }

    // sets token per block in wei 18 dec
    function setTokensPerBlock(uint _tokensPerBlock) public onlyOwner {
        tokensPerBlock = _tokensPerBlock;
    }

    // returns current block number
    function getBlockNumber() public view returns (uint) {
        return block.number;
    }

    // returns blocks user has been staking
    function _getBlocksStaked() public view returns (uint) {
        if (stakedFromBlock[msg.sender] == 0) {
            return 0;
        }
        return block.number - stakedFromBlock[msg.sender];
    }

    // ---------- magic

    // returns pending rewards for sender
    function getPendingRewards() public view returns (uint) {
        return getRewardRate() * stakedAmount[msg.sender] * _getBlocksStaked();
    }

    // gets reward per block per 0.000000001 kuro staked
    // maybe refactor this
    function getRewardRate() public view returns (uint) {
        if (totalKuroStaked == 0) {
            return 0;
        }
        return tokensPerBlock / totalKuroStaked;
    }

    // ---------- please fix

    // add start and end blocks
    // non nonReentrant / security
    // pending rewards go down when new people enter, bad

}

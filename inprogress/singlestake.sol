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
		tokensPerBlock = _tokensPerBlock;

		// emit StakeRewardUpdated(tokensPerBlock);
	}

    // need approval
    function stake(uint amount) public payable {
        if (stakedAmount[msg.sender] != 0) {
            claim();
        }
        kuro.transferFrom(msg.sender, address(this), amount);
        totalKuroStaked += amount;
        stakedAmount[msg.sender] += amount;
        stakedFromBlock[msg.sender] = block.number;
    }

    // unstakes kuro
    function unstake(uint amount) public {
        require(amount >= stakedAmount[msg.sender]);
        kuro.transfer(msg.sender, amount);
        stakedAmount[msg.sender] -= amount;
        totalKuroStaked -= amount;
        claim();
    }

    // claims rewards without unstaking
    function claim() public {
        require(stakedFromBlock[msg.sender] != block.number, "KURO: No claiming in same block");
        uint blocksStaked = block.number - stakedFromBlock[msg.sender];
        wone.transfer(msg.sender, 100);
    }

    // returns amount of kuro user staked
    function getUserKuroStaked() public view returns (uint) {
        return stakedAmount[msg.sender];
    }

    function getRewardRate() public view returns (uint) {
        if (totalKuroStaked == 0) {
            return 0;
        }
        return tokensPerBlock / totalKuroStaked;
    }

    function setTokensPerBlock(uint _tokensPerBlock) public onlyOwner {
        tokensPerBlock = _tokensPerBlock;
    }
}

// keep track of blocks
// security

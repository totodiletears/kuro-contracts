// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract KuroBond {
    IERC20 public erc20Token;

    uint totalBondsActive;

    // make variable in constructor
    uint bondCost = 10000;
    uint bondPayoutAmount = 12500;
    uint totalBondsAvailable = 400;
    uint bondingTime = 60 days;

    mapping(address => bool) gotPaid;
    mapping(address => bool) isBonding;
    mapping(address => uint) totalBondsForUser;
    mapping(address => uint) bondEndTime;

    constructor(
        address _erc20Token
    ) {
        erc20Token = IERC20(_erc20Token);
    }

    function buyBond(uint _amount) public {
        require(!gotPaid[msg.sender], "you already exhausted your reward");
        require(!isBonding[msg.sender], "one purchase per reward offering");
        require(totalBondsActive + _amount < totalBondsAvailable, "not enough available");
        require(erc20Token.balanceOf(msg.sender) >= _amount * bondCost, "need more kuro");

        // approve first
        erc20Token.transferFrom(msg.sender, address(this), _amount * bondCost);

        isBonding[msg.sender] = true;
        totalBondsForUser[msg.sender] += _amount;
        bondEndTime[msg.sender] = block.timestamp + bondingTime;

        totalBondsActive += _amount;
    }

    // regular payout after time elapsed
    function bondPayout() public {
        require(isBonding[msg.sender], "not active");
        require(block.timestamp > bondEndTime[msg.sender], "not fully matured");
        erc20Token.transfer(msg.sender, totalBondsForUser[msg.sender] * bondPayoutAmount);
        gotPaid[msg.sender] = true;
    }

    // add emg withdraw no rewards
    function emgWithdraw() public {
        require(isBonding[msg.sender]);
        require(!gotPaid[msg.sender]);
        erc20Token.transfer(msg.sender, totalBondsForUser[msg.sender] * bondCost);
        totalBondsActive -= totalBondsForUser[msg.sender];
        totalBondsForUser[msg.sender] = 0; 
        isBonding[msg.sender] = false;
    }

    // view
    function getCost() public view returns (uint) {
        return bondCost;
    }

    function getReturn() public view returns (uint) {
        return bondPayoutAmount;
    }

    function getTotalBondsForUser(address _user) public view returns (uint) {
        return totalBondsForUser[_user];
    }

    function getCurrentBondsAvailable() public view returns (uint) {
        return totalBondsAvailable - totalBondsActive;
    }

    function getIsBonding() public view returns (bool) {
        return isBonding[msg.sender];
    }

    function getDuration() public view returns (uint) {
        return bondingTime / 86400;
    }

    function getTimeRemainingOnBond() public view returns (uint) {
        if (isBonding[msg.sender]) {
            return getEndTime() - getCurrentTime();
        }
        return 0;
    }

    function getEndTime() public view returns (uint) {
        return bondEndTime[msg.sender];
    }

    function getCurrentTime() public view returns (uint) {
        return block.timestamp;
    }

}

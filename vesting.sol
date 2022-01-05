// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Vesting is Ownable {
    IERC20 public erc20Token;

    mapping(uint => address) payees; //

    mapping(address => uint) lastPayed;
    mapping(address => uint) payment;

    uint public cooldown = 7 days;

    constructor(
        address _erc20Token,
        uint cooldown
    ) {
        erc20Token = IERC20(_erc20Token);
        cooldown = 7 days;
    }

    function _payoutVest(address payee, uint amount) internal onlyOwner {
        require(_checkCookdown(payee) == true, "already paid");
        require(erc20Token.balanceOf(address(this)) >= amount, "contract out of money");
        erc20Token.transfer(payee, amount); //
        lastPayed[payee] = now;
    }

    function _checkCooldown(address payee) public view returns (bool) {
        return (lastPayed[payee] + cooldown) > now;
    }

    function setPayment(address payee, uint amount) public onlyOwner {
        payment[payee] = amount;
    }

    function setPayees(address[] calldata payees) public onlyOwner {
        //
    }

    function withdrawAll(address owner) public onlyOwner {
        erc20Token.transfer(owner, erc20Token.balanceOf(address(this)); //
    }

    function pay() public onlyOwner {
        for (uint i = 0; i < payees.length; i++) {
            _payoutVest(payee[i], payment[i]);
        }
    }

}
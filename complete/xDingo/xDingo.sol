// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract xDingo is ERC20, ERC20Snapshot, Ownable {
    address public admin;
    address public stakingAddress;

    constructor(
        address _admin,
        address _stakingAddress
        ) 
        ERC20("xDingo", "xDG") 
        {
        admin = _admin;
        stakingAddress = _stakingAddress;
        _mint(msg.sender, 166650000 * 10 ** decimals());
    }

    function snapshot() public onlyOwner {
        _snapshot();
    }

    function transfer(address _to, uint256 _value) public virtual override returns (bool) {
        require(verifyTransfer(msg.sender), "Transfer is not valid");    

        super.transfer(_to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public virtual override returns (bool) {
        require(verifyTransfer(_from), "Transfer is not valid");

        super.transferFrom(_from, _to, _value);
        return true;
    }

    function verifyTransfer(address _from) public view returns (bool) {
        if(_from == admin || _from == stakingAddress)
            return true;
        else
            return false;
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Snapshot)
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function setAdmin(address _admin) public onlyOwner {
        admin = _admin;
    }

    function setStaking(address _staking) public onlyOwner {
        stakingAddress = _staking;
    }
}
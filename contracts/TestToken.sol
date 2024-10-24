// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    address public immutable i_owner;

    modifier _onlyOwner {
        require(msg.sender == i_owner, "Only owner can call this function");
        _;
    }

    constructor(uint256 _totalSupply) ERC20("TestToken", "TTKn") {
        i_owner = msg.sender;
        _mint(msg.sender, _totalSupply);
    }

    function mint(address to, uint256 amount) external _onlyOwner{
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external _onlyOwner {
        _burn(from, amount);
    }
}

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FakeToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Chain", "CHN") {
        _mint(msg.sender, initialSupply);
    }

    function mintForUser(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}
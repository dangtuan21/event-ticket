// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
// pragma solidity ^0.4.18;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EVENTToken is ERC20, Ownable 
{
    constructor (address deployedAddress) ERC20("Event Token", "EVENT") {
    }

    function burn(uint256 amount, address account) external {
        _burn(account, amount);
    }    
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }    
}


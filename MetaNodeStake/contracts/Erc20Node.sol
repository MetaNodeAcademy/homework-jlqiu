pragma solidity ^0.8;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Erc20Node is ERC20 {
    constructor(uint256 initialSupply) ERC20("Erc20Node", "MTK") {
        _mint(msg.sender, initialSupply);
    }

}

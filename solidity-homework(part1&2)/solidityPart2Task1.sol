// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 作业1：ERC20代币  1.合约包含以下标准ERC20  ok
contract Task2 is ERC20 {

    // // 账户余额信息
    // mapping(address => uint256) private _balances;

    // // 账户授权信息
    // mapping(address => uint256) private _approves;

    constructor() ERC20("Task2", "MTK") {
        
    }
    // 2.获取账户余额  ok
    function getBalance(address account) public view returns (uint) {
        return balanceOf(account);
    } 

    // 3、转账，从当前账户转账给A账户  ok 
  // to  0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
  // from 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
    function transferTo(address from) public returns(bool) {
        return transfer(from, 1);
    }

    // 4、approve和transferFrom：授权和代扣转账  ok
    // 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4   2
    function approveTest(address spender, uint amount) public returns(bool) {
         return approve(spender, amount);
    }

    // 4、approve和transferFrom：授权和代扣转账  ok
    //recipient :0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
    // addr:0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
    function transferTest(address addr, address recipient, uint amount) public returns(bool) {
        return transferFrom(addr, recipient, amount);
    }

    // 5、使用event 记录转账和授权操作   ok
    event Log(uint amount, address indexed sender, address indexed receiver);
    
    
    // 回退函数
    receive() external payable { }
    // 6、提供mint函数，允许合约所有者增发代币   ok
    function mint(address account, uint value) public {
        _mint(account, value);
    }



}
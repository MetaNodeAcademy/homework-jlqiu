// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "@openzeppelin/contracts/access/Ownable.sol";

// 创建一个名为BeggingContract的合约
contract BeggingContract is Ownable{
    address public owners;

    constructor() Ownable(address(this)) { 
        owners = msg.sender;
    }

// 一个mapping来记录每个捐赠者的捐赠金额
    mapping ( address => uint256 ) public balances;

    
    // 合约能够接收ETH 直接转账
    receive() external payable { 
        balances[msg.sender] = balances[msg.sender] + msg.value;
    }

    // 一个donate函数，允许用户向合约发送以太币，并记录捐赠信息 ok
    function donat() public payable  returns(bool) {
        require(msg.value > 0,"amount must > 0");
        balances[msg.sender] = balances[msg.sender] + msg.value;
        return true;
    }


    // 一个withdraw函数，允许合约所有者提取所有资金  ok
    function withdraw() public {
        require(owners == msg.sender, "caller is not the owner");
        (bool success, ) = owners.call{value: address(this).balance}("");
       require(success, "widthdraw failed");
        
    }

     // 一个getDonation函数，用于查询某个地址的捐赠金额  ok
    function getDonation(address addr) public view returns(uint) {
        return  balances[addr];
    }

   // 查看合约当前余额  ok
    function getBalances() public view returns(uint) {
          return address(this).balance;
    }
    
    // 使用payable修饰符和address.transfer 实现支付和提款  ok
    function transferTest(uint amount,address payable addr) public payable  returns(bool) {
        addr.transfer(amount);
        return true;
    }
    
}
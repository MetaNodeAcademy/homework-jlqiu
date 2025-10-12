// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 主要功能实现黑名单控制和持币量的限制
contract PepeToken is Ownable, ERC20 {
    bool public limited;
    uint256 public maxHoldingAmount;
    uint256 public minHoldingAmount;
    address public uniswapV2Pair;
    mapping(address => bool) public blacklists;

    constructor(uint256 _totalSupply) ERC20("Pepe", "PEPE") Ownable(msg.sender) {
        // 初始化mint _totalSupply数量的代币
        _mint(msg.sender, _totalSupply); 
    }
    // 添加黑名单，仅合约拥有者可以调用
    function blacklist(address _address, bool _isBlacklisting) external onlyOwner {
        blacklists[_address] = _isBlacklisting;
    }

   // 设置合约的相关规则，如：_limited是否限制，_uniswapV2Pair交易所地址， _maxHoldingAmount最大持有代币量，_minHoldingAmount最小持有代币量，仅合约拥有者可以调用
    function setRule(bool _limited, address _uniswapV2Pair, uint256 _maxHoldingAmount, uint256 _minHoldingAmount) external onlyOwner {
        limited = _limited;
        uniswapV2Pair = _uniswapV2Pair;
        maxHoldingAmount = _maxHoldingAmount;
        minHoldingAmount = _minHoldingAmount;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    )  internal virtual {
        // 判断转出和转入账户是否在黑名单
        require(!blacklists[to] && !blacklists[from], "Blacklisted");
        // 判断交易所地址为零地址，交易未开始，只有拥有者可参与交易
        if (uniswapV2Pair == address(0)) {
            // 要么发送方是拥有者，要么接收方是拥有者,仅拥有者参与转账
            require(from == owner() || to == owner(), "trading is not started");
            return;
        }
         //  limited用于判断是否开启下面的逻辑，判断转出账户是否为交易所地址，用户从交易所购买代币
        if (limited && from == uniswapV2Pair) {
            // 判断转入账户代币的持有量是否在最小持有量和最大持有量之间
            require(super.balanceOf(to) + amount <= maxHoldingAmount && super.balanceOf(to) + amount >= minHoldingAmount, "Forbid");
        }
    }
     
     // 销毁代币
    function burn(uint256 value) external {
        _burn(msg.sender, value);
    }

}
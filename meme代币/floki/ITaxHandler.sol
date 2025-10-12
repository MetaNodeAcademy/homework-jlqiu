// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;
// 税收接口
/**
 * @title Tax handler interface
 * @dev Any class that implements this interface can be used for protocol-specific tax calculations.
 */
interface ITaxHandler {
    // 获取需要作为税费支付的代币数量
    // benefactor 捐赠人地址
    // beneficiary 受益人地址
    // 转账数量
    // 返回作为税费的代币数量
    /**
     * @notice Get number of tokens to pay as tax.
     * @param benefactor Address of the benefactor.
     * @param beneficiary Address of the beneficiary.
     * @param amount Number of tokens in the transfer.
     * @return Number of tokens to pay as tax.
     */
    function getTax(
        address benefactor,
        address beneficiary,
        uint256 amount
    ) external view returns (uint256);
}
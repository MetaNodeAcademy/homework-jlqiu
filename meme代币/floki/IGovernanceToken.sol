// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;
// 代币治理
/**
 * @title Governance token interface.
 */
interface IGovernanceToken {
    // 特定区块票数检查点
    /// @notice A checkpoint for marking number of votes as of a given block.
    struct Checkpoint {
        // The 32-bit unsigned integer is valid until these estimated dates for these given chains:
        //  - BSC: Sat Dec 23 2428 18:23:11 UTC
        //  - ETH: Tue Apr 18 3826 09:27:12 UTC
        // This assumes that block mining rates don't speed up.
        // 区块号
        uint32 blockNumber;
        // This type is set to `uint224` for optimizations purposes (i.e., specifically to fit in a 32-byte block). It
        // assumes that the number of votes for the implementing governance token never exceeds the maximum value for a
        // 224-bit number.
        // 票数
        uint224 votes;
    }

    /**
     * @notice Determine the number of votes for an account as of a block number.
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check.
     * @param blockNumber The block number to get the vote balance at.
     * @return The number of votes the account had as of the given block.
     */
     // 获取在某个特定区块账户的得票数 account 需要检查的账户地址，blockNumber区块编号，返回票数
    function getVotesAtBlock(address account, uint32 blockNumber) external view returns (uint224);

    /// @notice Emitted whenever a new delegate is set for an account.
    // 在治理代币系统中，代币持有者可以将自己的投票权委托给其他地址（代理）
    // 代理关系变更事件 delegator委托用户 ，原被委托人currentDelegate，新的被委托人：newDelegate
    event DelegateChanged(address delegator, address currentDelegate, address newDelegate);

    /// @notice Emitted when a delegate's vote count changes.
    // delegatee被委托的地址（即实际持有投票权的代理地址） oldVotes变更前票数  newVotes变更后票数
    // 代理地址的投票权数量变更事件
    event DelegateVotesChanged(address delegatee, uint224 oldVotes, uint224 newVotes);
}
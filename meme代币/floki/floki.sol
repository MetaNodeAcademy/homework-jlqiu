// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/access/Ownable.sol";

import "./IGovernanceToken.sol";
import "./ITaxHandler.sol";
import "./ITreasuryHandler.sol";
// 代币具有治理功能，具有投票委托以及历史投票权快照
// 模块化的税收系统，外部合约实现
// 模块化的金库系统，外部合约实现

/**
 * @title Floki token contract
 * @dev The Floki token has modular systems for tax and treasury handler as well as governance capabilities.
 */
contract FLOKI is IERC20, IGovernanceToken, Ownable {
    /// @dev Registry of user token balances.
    // 用户代币余额记录
    mapping(address => uint256) private _balances;

    /// @dev Registry of addresses users have given allowances to.
    // 记录授权地址授权被委托地址能够使用的代币数量
    mapping(address => mapping(address => uint256)) private _allowances;

    /// @notice Registry of user delegates for governance.
    // 代币持有者通常可将自己的投票权委托给其他地址，记录委托关系
    mapping(address => address) public delegates;

    /// @notice Registry of nonces for vote delegation.
    // 用于记录地址的随机数，防止重放；nonces映射通过为每个地址维护一个递增的计数器，确保每笔签名交易只能被使用一次
    mapping(address => uint256) public nonces;

    /// @notice Registry of the number of balance checkpoints an account has.
    // 记录账户检查点？
    mapping(address => uint32) public numCheckpoints;

    /// @notice Registry of balance checkpoints per account.
    // 检查点历史快照，记录某个块投票数量
    mapping(address => mapping(uint32 => Checkpoint)) public checkpoints;

    /// @notice The EIP-712 typehash for the contract's domain.
    // 域名类型哈希
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract.
    // 委托结构体类型哈希
    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @notice The contract implementing tax calculations.
    // 税收接口 模块化的税收系统，外部合约实现
    ITaxHandler public taxHandler;

    /// @notice The contract that performs treasury-related operations.
    // 财务接口 模块化的金库系统，外部合约实现
    ITreasuryHandler public treasuryHandler;

    /// @notice Emitted when the tax handler contract is changed.
    // 事件，用于记录税费处理合约地址的变更信息 oldAddress变更前，newAddress变更后
    event TaxHandlerChanged(address oldAddress, address newAddress);

    /// @notice Emitted when the treasury handler contract is changed.
    // 事件，用于记录财务处理合约地址的变更信息 oldAddress变更前，newAddress变更后
    event TreasuryHandlerChanged(address oldAddress, address newAddress);

    /// @dev Name of the token.
    string private _name;

    /// @dev Symbol of the token.
    string private _symbol;

    /**
     * @param name_ Name of the token.
     * @param symbol_ Symbol of the token.
     * @param taxHandlerAddress Initial tax handler contract.
     * @param treasuryHandlerAddress Initial treasury handler contract.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address taxHandlerAddress,
        address treasuryHandlerAddress
    ) {
        _name = name_;
        _symbol = symbol_;

        // 初始化税收合约，并设置税收合约地址
        taxHandler = ITaxHandler(taxHandlerAddress);
        // 初始化财务系统，并设置财务系统合约地址
        treasuryHandler = ITreasuryHandler(treasuryHandlerAddress);
        // 将代币的全部初始供应量（totalSupply()设置给当前调用者
        _balances[_msgSender()] = totalSupply();
       // 发布给当前调用者初始分配代币的事件
        emit Transfer(address(0), _msgSender(), totalSupply());
    }

    /**
     * @notice Get token name.
     * @return Name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @notice Get token symbol.
     * @return Symbol of the token.
     */
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Get number of decimals used by the token.
     * @return Number of decimals used by the token.
     */
    function decimals() external pure returns (uint8) {
        return 9;
    }

    /**
     * @notice Get the maximum number of tokens.
     * @return The maximum number of tokens that will ever be in existence.
     */
    function totalSupply() public pure override returns (uint256) {
        // Ten trillion, i.e., 10,000,000,000,000 tokens.
        return 1e13 * 1e9;
    }

    /**
     * @notice Get token balance of given given account.
     * @param account Address to retrieve balance for.
     * @return The number of tokens owned by `account`.
     */
    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @notice Transfer tokens from caller's address to another.
     * @param recipient Address to send the caller's tokens to.
     * @param amount The number of tokens to transfer to recipient.
     * @return True if transfer succeeds, else an error is raised.
     */
     // 转账地址，从当前调用者转给接受者recipient，amount数量的代币
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @notice Get the allowance `owner` has given `spender`.
     * @param owner The address on behalf of whom tokens can be spent by `spender`.
     * @param spender The address authorized to spend tokens on behalf of `owner`.
     * @return The allowance `owner` has given `spender`.
     */
     // 获取授权额度，owner授权人，spender被授权人
    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @notice Approve address to spend caller's tokens.
     * @dev This method can be exploited by malicious spenders if their allowance is already non-zero. See the following
     * document for details: https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit.
     * Ensure the spender can be trusted before calling this method if they've already been approved before. Otherwise
     * use either the `increaseAllowance`/`decreaseAllowance` functions, or first set their allowance to zero, before
     * setting a new allowance.
     * @param spender Address to authorize for token expenditure.
     * @param amount The number of tokens `spender` is allowed to spend.
     * @return True if the approval succeeds, else an error is raised.
     */
     // 授权操作，授权某个地址可以使用的代币数量，授权人：当前调用者，被授权人：spender，授权金额：amount
    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @notice Transfer tokens from one address to another.
     * @param sender Address to move tokens from.
     * @param recipient Address to send the caller's tokens to.
     * @param amount The number of tokens to transfer to recipient.
     * @return True if the transfer succeeds, else an error is raised.
     */
     // 转账 转出地址：sender，转入地址：recipient，转出数量：amount，（调用者作为接受者？）
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];// 获取被授权额度
        // 检查授权额度是否当前转出金额，否则返回
        require(
            currentAllowance >= amount,
            "FLOKI:transferFrom:ALLOWANCE_EXCEEDED: Transfer amount exceeds allowance."
        );
        unchecked {
            // 更改授权额度
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * @notice Increase spender's allowance.
     * @param spender Address of user authorized to spend caller's tokens.
     * @param addedValue The number of tokens to add to `spender`'s allowance.
     * @return True if the allowance is successfully increased, else an error is raised.
     */
     // 追加授权额度，当前调用者给被授权人增加授权额度
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);

        return true;
    }

    /**
     * @notice Decrease spender's allowance.
     * @param spender Address of user authorized to spend caller's tokens.
     * @param subtractedValue The number of tokens to remove from `spender`'s allowance.
     * @return True if the allowance is successfully decreased, else an error is raised.
     */
     //  减少授权额度，当前调用者给被授权人减少授权额度 
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        // 获取当前授权额度
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        // 检查当前授权额度是否大于等于减少的额度，否则返回
        require(
            currentAllowance >= subtractedValue,
            "FLOKI:decreaseAllowance:ALLOWANCE_UNDERFLOW: Subtraction results in sub-zero allowance."
        );
        // 针对授权额度进行减少处理
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @notice Delegate votes to given address.
     * @dev It should be noted that users that want to vote themselves, also need to call this method, albeit with their
     * own address.
     * @param delegatee Address to delegate votes to.
     */
     // 当前调用者将投票权委托给某个地址
    function delegate(address delegatee) external {
        return _delegate(msg.sender, delegatee);
    }

    /**
     * @notice Delegate votes from signatory to `delegatee`.
     * @param delegatee The address to delegate votes to.
     * @param nonce The contract state required to match the signature.
     * @param expiry The time at which to expire the signature.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     */
     // 当前调用者将投票权委托给某个地址delegatee，签名者的随机数nonce，委托的有效期expiry， vrs ECC 椭圆曲线签名的三个组成部分
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // 域名哈希
        bytes32 domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name())), block.chainid, address(this))
        );
        // 委托结构体的哈希
        bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
        // 域名和结构体拼接进行签名
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);// 通过签名参数恢复签名者地址
        // 签名地址无效则返回
        require(signatory != address(0), "FLOKI:delegateBySig:INVALID_SIGNATURE: Received signature was invalid.");
        // 判断有效期，是否在有效期内，否则返回
        require(block.timestamp <= expiry, "FLOKI:delegateBySig:EXPIRED_SIGNATURE: Received signature has expired.");
        // 签名随机数验证
        require(nonce == nonces[signatory]++, "FLOKI:delegateBySig:INVALID_NONCE: Received nonce was invalid.");

        return _delegate(signatory, delegatee);
    }

    /**
     * @notice Determine the number of votes for an account as of a block number.
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check.
     * @param blockNumber The block number to get the vote balance at.
     * @return The number of votes the account had as of the given block.
     */
     // 获取某个地址在某个块的投票数量
    function getVotesAtBlock(address account, uint32 blockNumber) public view returns (uint224) {
        // 判断块是否小于当前块，否则返回
        require(
            blockNumber < block.number,
            "FLOKI:getVotesAtBlock:FUTURE_BLOCK: Cannot get votes at a block in the future."
        );
        
        // 检查点为0则返回
        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance.边界判断
        // 判断当前地址的最大检查点的投票快照的块小于请求的块，则返回最大的块对应的投票数量
        if (checkpoints[account][nCheckpoints - 1].blockNumber <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance. 边界判断
        // 0号检查点的投票快照的块大于当前请求的块，返回0数量的投票
        if (checkpoints[account][0].blockNumber > blockNumber) {
            return 0;
        }

        // Perform binary search.
        // 用二叉方式循环检查快照信息，获取与当前块匹配的快照
        uint32 lowerBound = 0;
        uint32 upperBound = nCheckpoints - 1;
        while (upperBound > lowerBound) {
            uint32 center = upperBound - (upperBound - lowerBound) / 2;
            Checkpoint memory checkpoint = checkpoints[account][center];

            if (checkpoint.blockNumber == blockNumber) {
                return checkpoint.votes;
            } else if (checkpoint.blockNumber < blockNumber) {
                lowerBound = center;
            } else {
                upperBound = center - 1;
            }
        }

        // No exact block found. Use last known balance before that block number.
        return checkpoints[account][lowerBound].votes;
    }

    /**
     * @notice Set new tax handler contract.
     * @param taxHandlerAddress Address of new tax handler contract.
     */
     // 设置税收合约地址
    function setTaxHandler(address taxHandlerAddress) external onlyOwner {
        // 获取旧的合约地址
        address oldTaxHandlerAddress = address(taxHandler);
        // 初始化新的地址
        taxHandler = ITaxHandler(taxHandlerAddress);
        // 发布税收合约地址变更事件
        emit TaxHandlerChanged(oldTaxHandlerAddress, taxHandlerAddress);
    }

    /**
     * @notice Set new treasury handler contract.
     * @param treasuryHandlerAddress Address of new treasury handler contract.
     */
     // 设置财务合约地址
    function setTreasuryHandler(address treasuryHandlerAddress) external onlyOwner {
        // 获取旧的财务合约地址
        address oldTreasuryHandlerAddress = address(treasuryHandler);
        // 初始化设置新的财务合约地址
        treasuryHandler = ITreasuryHandler(treasuryHandlerAddress);
        // 发布财务合约地址变更事件
        emit TreasuryHandlerChanged(oldTreasuryHandlerAddress, treasuryHandlerAddress);
    }

    /**
     * @notice Delegate votes from one address to another.
     * @param delegator Address from which to delegate votes for.
     * @param delegatee Address to delegate votes to.
     */
     // 委托投票权，委托地址delegator，被委托地址delegatee
    function _delegate(address delegator, address delegatee) private {
        // 获取当前被委托地址
        address currentDelegate = delegates[delegator];
        // 获取当前委托数量
        uint256 delegatorBalance = _balances[delegator];
        // 设置新的被委托人
        delegates[delegator] = delegatee;
       // 发布委托变更事件 delegator委托人，变更前委托人currentDelegate，变更后委托人delegatee
        emit DelegateChanged(delegator, currentDelegate, delegatee);
       // 从旧的被委托人转代币给新的被委托人
        _moveDelegates(currentDelegate, delegatee, uint224(delegatorBalance));
    }

    /**
     * @notice Move delegates from one address to another.
     * @param from Representative to move delegates from.
     * @param to Representative to move delegates to.
     * @param amount Number of delegates to move.
     */
    function _moveDelegates(
        address from,
        address to,
        uint224 amount
    ) private {
        // No need to update checkpoints if the votes don't actually move between different delegates. This can be the
        // case where tokens are transferred between two parties that have delegated their votes to the same address.
        // 旧的被委托地址和新的被委托地址是同一个则不需要转
        if (from == to) {
            return;
        }

        // Some users preemptively delegate their votes (i.e. before they have any tokens). No need to perform an update
        // to the checkpoints in that case.
        // 数量为零则不需要转
        if (amount == 0) {
            return;
        }

        // 判断旧被委托地址有效
        if (from != address(0)) {
            // 获取旧地址的投票快照
            uint32 fromRepNum = numCheckpoints[from];
            // 获取投票数
            uint224 fromRepOld = fromRepNum > 0 ? checkpoints[from][fromRepNum - 1].votes : 0;
            // 投票数减去要转的数
            uint224 fromRepNew = fromRepOld - amount;
           // 写入旧地址的检查点的投票数量
            _writeCheckpoint(from, fromRepNum, fromRepOld, fromRepNew);
        }

        // 判断新被委托地址是否有效
        if (to != address(0)) {
            // 获取新地址的投票历史快照
            uint32 toRepNum = numCheckpoints[to];
            uint224 toRepOld = toRepNum > 0 ? checkpoints[to][toRepNum - 1].votes : 0;
            // 计算总的投票数
            uint224 toRepNew = toRepOld + amount;
             // 更新新地址的投票快照
            _writeCheckpoint(to, toRepNum, toRepOld, toRepNew);
        }
    }

    /**
     * @notice Write balance checkpoint to chain.
     * @param delegatee The address to write the checkpoint for.
     * @param nCheckpoints The number of checkpoints `delegatee` already has.
     * @param oldVotes Number of votes prior to this checkpoint.
     * @param newVotes Number of votes `delegatee` now has.
     */
     // 更新被委托地址delegatee的nCheckpoints检查点的投票数，oldVotes更新前投票数，newVotes更新后投票数
    function _writeCheckpoint(
        address delegatee,
        uint32 nCheckpoints,
        uint224 oldVotes,
        uint224 newVotes
    ) private {
        // 当前区块
        uint32 blockNumber = uint32(block.number);
        
        // 判断检查点以及快照区块是否等于当前区块
        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].blockNumber == blockNumber) {
            // 设置当前检查点新的投票数据
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            // 检查点小于0，设置新的投票数
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            // 检查点+1
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    /**
     * @notice Approve spender on behalf of owner.
     * @param owner Address on behalf of whom tokens can be spent by `spender`.
     * @param spender Address to authorize for token expenditure.
     * @param amount The number of tokens `spender` is allowed to spend.
     */
     // 代币所有者授权给spender，一定数量的代币amount操作权限
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        // 所有者地址有效性判断，无效则返回
        require(owner != address(0), "FLOKI:_approve:OWNER_ZERO: Cannot approve for the zero address.");
        // 被授权地址有效性判断，无效则返回
        require(spender != address(0), "FLOKI:_approve:SPENDER_ZERO: Cannot approve to the zero address.");
       // 授权记录
        _allowances[owner][spender] = amount;
      // 授权
        emit Approval(owner, spender, amount);
    }

    /**
     * @notice Transfer `amount` tokens from account `from` to account `to`.
     * @param from Address the tokens are moved out of.
     * @param to Address the tokens are moved to.
     * @param amount The number of tokens to transfer.
     */
     // 转账
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        //判断转出转入地址的有效性
        require(from != address(0), "FLOKI:_transfer:FROM_ZERO: Cannot transfer from the zero address.");
        require(to != address(0), "FLOKI:_transfer:TO_ZERO: Cannot transfer to the zero address.");
        // 判断转账数量是否大于零，否则返回
        require(amount > 0, "FLOKI:_transfer:ZERO_AMOUNT: Transfer amount must be greater than zero.");
        // 判断转出账户余额是否大于当前转账金额，否则返回
        require(amount <= _balances[from], "FLOKI:_transfer:INSUFFICIENT_BALANCE: Transfer amount exceeds balance.");
        // 转账前处理
        treasuryHandler.beforeTransferHandler(from, to, amount);
        // 获取税金
        uint256 tax = taxHandler.getTax(from, to, amount);
        // 计算转账金额减去税金，扣除税金后的金额
        uint256 taxedAmount = amount - tax;
        // 转出转入账户余额处理
        _balances[from] -= amount;
        _balances[to] += taxedAmount;
        // 处理授权
        _moveDelegates(delegates[from], delegates[to], uint224(taxedAmount));
    // 税金大于0 的处理
        if (tax > 0) {
            // 财务系统的合约地址金额增加
            _balances[address(treasuryHandler)] += tax;
            
            // 授权财务系统可以从from账户操作tax的代币
            _moveDelegates(delegates[from], delegates[address(treasuryHandler)], uint224(tax));
            // 发布转账事件
            emit Transfer(from, address(treasuryHandler), tax);
        }
        // 转账后处理
        treasuryHandler.afterTransferHandler(from, to, amount);
        // 发布转账事件
        emit Transfer(from, to, taxedAmount);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// 1. 动态铸造权限管理
// 多权限控制：通过_minters映射表管理授权地址
// Merkle Tree白名单：使用 Merkle Proof 验证白名单地址
// 灵活调整：所有者可以随时更新铸造权限和白名单
// 2. 防女巫攻击机制
// 地址级限制：每个地址有最大铸造量限制(maxMintPerAddress)
// 铸造计数：通过_mintedCount记录每个地址已铸造数量
// 可配置参数：最大铸造量可通过setMaxMintPerAddress调整
// 3. 元数据动态生成
// 基础URI设置：支持动态更新基础元数据URI
// 代币属性存储：每个代币可存储自定义属性数据
// 动态URI生成：tokenURI方法根据属性动态生成最终元数据URL
contract AdvancedMintingSystem is ERC721, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256;
    
    // 代币计数器
    Counters.Counter private _tokenIdCounter;
    
    // 动态铸造权限相关
    mapping(address => bool) private _minters;
    // 根节点
    bytes32 public merkleRoot; // 用于白名单验证
    
    // 防女巫攻击
    mapping(address => uint256) private _mintedCount;
    // 每个地址的最大铸造次数
    uint256 public maxMintPerAddress = 1;
    
    // 元数据动态生成
    string private _baseTokenURI;
    mapping(uint256 => string) private _tokenAttributes;
    
    // 铸造价格
    uint256 public mintPrice = 0.05 ether;
    
    // 事件
    // 某个地址允许铸造权限更新事件
    event MintPermissionUpdated(address indexed minter, bool allowed);
    // 默克根节点更新事件
    event MerkleRootUpdated(bytes32 newRoot);

    event MetadataUpdated(uint256 tokenId, string attributes);
    
    // 构造函数，初始化指定合约拥有者
    constructor(string memory name, string memory symbol, address initialOwner) ERC721(name, symbol) Ownable(initialOwner) {}
    
    // ========== 动态铸造权限管理 ==========
    
    // 设置Merkle Root用于白名单验证
    function setMerkleRoot(bytes32 root) external onlyOwner {
        merkleRoot = root;
        emit MerkleRootUpdated(root);
    }
    
    // 添加/移除铸造权限
    function setMinter(address minter, bool allowed) external onlyOwner {
        _minters[minter] = allowed;
        emit MintPermissionUpdated(minter, allowed);
    }
    
    // 验证铸造权限
    modifier onlyMinter(bytes32[] calldata proof) {
        // 调用者是否在铸造授权列表中
        require(
            _minters[msg.sender] || 
            MerkleProof.verify(proof, merkleRoot, keccak256(abi.encodePacked(msg.sender))),
            "Caller is not allowed to mint"
        );
        _;// 执行此修饰符修饰的函数
    }
    
    // ========== 防女巫攻击 ==========
    
    // 设置每个地址最大铸造量
    function setMaxMintPerAddress(uint256 max) external onlyOwner {
        maxMintPerAddress = max;
    }
    
    // 检查是否超过最大铸造次数
    modifier checkMintLimit() {
        require(
            _mintedCount[msg.sender] < maxMintPerAddress,
            "Exceeds maximum mint limit per address"
        );
        _; // 执行修饰符修饰的函数
        _mintedCount[msg.sender]++; // 函数执行完后返回此方法 铸造次数+1
    }
    
    // ========== 元数据动态生成 ==========
    
    // 设置基础URI
    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }
    
    // 设置代币属性(可扩展为链上或链下生成)
    function setTokenAttributes(uint256 tokenId, string calldata attributes) external {
        // 满足一个条件即可，否则返回错误
        // 条件1 调用者为当前token的拥有者
        // 条件2：当前调用者被授权可以操作该token
        // 条件3：检查调用者是否是所有者授权
       require(
    ownerOf(tokenId) == msg.sender ||
    getApproved(tokenId) == msg.sender ||
    isApprovedForAll(ownerOf(tokenId), msg.sender),
    "Not owner nor approved"
);
// 更新token的元数据
        _tokenAttributes[tokenId] = attributes;
// 发布更新事件
        emit MetadataUpdated(tokenId, attributes);
    }
    
    // 重写tokenURI方法实现动态元数据
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
       require(_ownerOf(tokenId) != address(0), "Token does not exist");
        // 基础URI获取
        string memory baseURI = _baseURI();
        // 属性数据获取
        string memory attributes = _tokenAttributes[tokenId];
        // 属性不为空，则使用基本URI和tokenId,属性，使用encodePacked拼接完整的URI
        if(bytes(attributes).length > 0) {
            return string(abi.encodePacked(baseURI, Strings.toString(tokenId), "?attributes=", attributes));
        }
        // 如果属性为空，则使用基本URI和tokenId拼接
        return string(abi.encodePacked(baseURI, Strings.toString(tokenId)));
    }
    
    // ========== 铸造功能 ==========
    
    // 公开铸造函数 onlyMinter修饰符函数，优先调用。修饰符函数，优先调用。
    function mint(bytes32[] calldata proof, string calldata initialAttributes) 
        external 
        payable 
        onlyMinter(proof)
        checkMintLimit
    {
        // 判断调用者发送的代币>=铸造手续费,否则返回“支付不足”
        require(msg.value >= mintPrice, "Insufficient payment");
        
        // 计数器当前值作为token标识ID
        uint256 tokenId = _tokenIdCounter.current();
        // 计数器+1
        _tokenIdCounter.increment();
        // 调用ERC721合约的安全铸造方法，铸造NFT
        _safeMint(msg.sender, tokenId);
        
        if(bytes(initialAttributes).length > 0) {
            _tokenAttributes[tokenId] = initialAttributes;
        }
    }
    
    // 提取资金，只有合约拥有者可以操作，从当前合约地址转账给拥有者账户，仅支持提取以太币
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
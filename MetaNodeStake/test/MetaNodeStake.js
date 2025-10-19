const hre = require("hardhat");
const { expect } = require("chai");

describe("MetaNodeStake Test", function () {
    let metaNodeStake;
    let erc20Node;
    let ownerAddress;
        beforeEach(async function () {
            // 部署 ERC20合约
            const Erc20Node = await hre.ethers.getContractFactory("Erc20Node");
            erc20Node = await Erc20Node.deploy();
            await erc20Node.waitForDeployment();
            
            // 部署MetaNodeStake
            const MetaNodeStake = await hre.ethers.getContractFactory("MetaNodeStake");
            metaNodeStake = await MetaNodeStake.deploy();
            await metaNodeStake.waitForDeployment();

            // 初始化参数
            const blockNumber = await hre.ethers.provider.getBlockNumber();
            const startBlock = blockNumber + 100;
            const endBlock = blockNumber + 200;
            const MetaNodePerBlock = hre.ethers.utils.parseEther("0.1");
            ownerAddress = await hre.ethers.provider.getSigner();

            // 调用MetaNodeStake的init函数
            await metaNodeStake.initialize(
                metaNodeStake.address,
                startBlock,
                endBlock,
                MetaNodePerBlock
            );

            // 给质押合约初始化代币
            await metaNodeStake.mint(metaNodeStake.address, hre.ethers.utils.parseEther("1000"));

            // 创建池子
            await metaNodeStake.addPool(
                hre.ethers.ZeroAddress,
                100,
                hre.ethers.utils.parseEther("1"),
                100,
                false
            );
        });
        describe("管理员功能测试", function () {
            it("测试管理员权限", async function () {
                const admin = await metaNodeStake.admin();
                expect(admin).to.equal(hre.ethers.constants.AddressZero);
            });

            it("测试设置管理员权限", async function () {
                const newAdmin = "0x12345678901234567890";
                await metaNodeStake.setAdmin(newAdmin);
                const admin = await metaNodeStake.admin();
                expect(admin).to.equal(newAdmin);
            });
            it("测试设置管理员权限失败", async function () {
                const newAdmin = "0x1234567890";
                await metaNodeStake.setAdmin(newAdmin, {from: "0x1234567890"});
                const admin = await metaNodeStake.admin();
                expect(admin).to.equal(hre.ethers.constants.AddressZero);
            });
            it("测试管理员添加流动池", async function () {
                const newPool = "0x1234567890";
                await metaNodeStake.addPool(newPool, 100, hre.ethers.utils.parseEther("1"), 100, false);
                const poolCount = await metaNodeStake.poolCount();
                expect(poolCount).to.equal(1);
            });

            it("管理员设置初始块和结束块", async function () {
                const blockNumber = await hre.ethers.provider.getBlockNumber();
                const startBlock = blockNumber + 100;
                const endBlock = blockNumber + 200;
                await metaNodeStake.setStartBlock(startBlock);
                await metaNodeStake.setEndBlock(endBlock);
                const startBlockStored = await metaNodeStake.startBlock();
                const endBlockStored = await metaNodeStake.endBlock();
                expect(startBlockStored).to.equal(startBlock);
                expect(endBlockStored).to.equal(endBlock);
            });

            it("管理员更新每个块的奖励金额", async function () {
                const MetaNodePerBlock = hre.ethers.utils.parseEther("0.1");
                await metaNodeStake.setMetaNodePerBlock(MetaNodePerBlock);
                const MetaNodePerBlockStored = await metaNodeStake.metaNodePerBlock();
                expect(MetaNodePerBlockStored).to.equal(MetaNodePerBlock);
            });

            it("测试管理员设置质押合约地址", async function () {
                const metaNode = "0x1234567890";
                await metaNodeStake.setMetaNode(metaNode);
                const metaNodeStored = await metaNodeStake.metaNode();
                expect(metaNodeStored).to.equal(metaNode);
            });
            it("测试管理员指定特定池子的权重", async function () {
                await metaNodeStake.setPoolWeight(0, 100);
                expect(await metaNodeStake.poolWeight(0)).to.equal(100);
             });

        });


        describe("用户功能测试", function () {
            it("测试质押功能eth", async function () {
                const amount = hre.ethers.utils.parseEther("1");
                // 质押ETH
               await metaNodeStake.depositETH({value: amount});
               // 获取质押ETH数量
                const balance = await metaNodeStake.stakingBalance(0, ownerAddress.getAddress());
                expect(balance).to.equal(amount);
            });

            it("测试质押功能erc20", async function () {
                const amount = hre.ethers.utils.parseEther("1");
                // 质押代币
                await metaNodeStake.deposit(1, amount);
                // 获取质押金额
                const balance = await metaNodeStake.stakingBalance(1, erc20Node.address);
                expect(balance).to.equal(amount);
            });

            it("测试提取已解锁的质押金额", async function () {
                const amount = hre.ethers.utils.parseEther("1");
                // 质押Eth
                await metaNodeStake.depositETH({value: amount});
                // 获取锁定的和未锁定的未质押金额
                const {reqeustAmount, pendingAmount} = await metaNodeStake.withdrawAmount(0, erc20Node.address);
                // 仅仅提取解锁的未质押金额
                await metaNodeStake.withdraw(0, erc20Node.address, pendingAmount);
                const {reqeustAmountAfter, pendingAmountAfter} = await metaNodeStake.withdrawAmount(0, erc20Node.address);
                expect(pendingAmountAfter).to.equal(0);
            });
            it("测试解除质押", async function () {
                const amount = hre.ethers.utils.parseEther("1");
                // 质押代币
                await metaNodeStake.deposit(1, amount);
                // 解除质押
                await metaNodeStake.unstake(1, amount);
                // 获取质押金额
                const balance = await metaNodeStake.stakingBalance(1, erc20Node.address);
                expect(balance).to.equal(0);
            });

            it("领取代币奖励", async function () {
                const balanceBefore = await erc20Node.balanceOf(metaNodeStake.address);
                // 领取奖励代币
                await metaNodeStake.claim(0);
                // 获取代币数量
                const balanceAfter = await erc20Node.balanceOf(metaNodeStake.address);
                // 代币数量增加
                expect(balanceBefore).to.lessThan(balanceAfter);
            });
        
        });  
});
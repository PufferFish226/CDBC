// SPDX-License-Identifier: MIT
import { expect } from "chai";
import hardhat from "hardhat";
const { ethers } = hardhat;

describe("CDBCConsensus", function () {
    let accessControl, utxo, regulatory, consensusCore, consensus;
    let deployer, addr1, addr2, addr3;
    let PRIMARY_BANK_ROLE;

    beforeEach(async function () {
        // 1. 获取测试账户
        [deployer, addr1, addr2, addr3] = await ethers.getSigners();

        // --------------------------------------------------------
        // 2. 部署 AccessControl
        // --------------------------------------------------------
        const CDBCAccessControl = await ethers.getContractFactory("CDBCAccessControl");
        accessControl = await CDBCAccessControl.deploy();
        await accessControl.waitForDeployment();

        // 计算角色哈希
        try {
            PRIMARY_BANK_ROLE = await accessControl.PRIMARY_BANK_ROLE();
        } catch (e) {
            PRIMARY_BANK_ROLE = ethers.keccak256(ethers.toUtf8Bytes("PRIMARY_BANK_ROLE"));
        }

        // --------------------------------------------------------
        // 3. 权限配置 (Wait for Geth Mining)
        // --------------------------------------------------------
        
        // A. 确保 Deployer 拥有一级银行权限 (构造函数里给了，但为了 roleInfo 确认一下)
        // 注意：构造函数里已经 update 了 roleInfo，所以这里其实不需要再 grant，
        // 但为了稳妥，我们在测试开始时可以打印检查一下。
        const deployerValid = await accessControl.hasValidRole(deployer.address);
        if (!deployerValid) {
             // 如果构造函数没生效(不太可能)，这里补救一下
             console.log("Re-granting Primary Bank role...");
             // 注意：AccessControl 没有 assignPrimaryBank，通常在构造函数完成
        }

        // B. 【关键修正】使用 assignValidator 而不是 grantRole
        console.log("Assigning Validators using assignValidator function...");
        
        // 为 addr1 分配验证者角色 (这将更新 roleInfo)
        let txVal1 = await accessControl.assignValidator(addr1.address, "Validator_Addr1");
        await txVal1.wait();

        // 为 addr2 分配验证者角色
        let txVal2 = await accessControl.assignValidator(addr2.address, "Validator_Addr2");
        await txVal2.wait();
        
        // 为 deployer 也分配验证者角色 (如果业务逻辑允许同一个地址既是一级银行也是验证者)
        // 注意：grantRole 允许多重角色，但你的 roleInfo 是覆盖式的。
        // 如果 assignValidator 会覆盖掉 PrimaryBank 的 roleInfo，可能会导致问题。
        // 让我们查看你的 RoleInfo 逻辑 -> 是一对一映射。
        // 为了安全起见，我们在测试中让 deployer 保持 PrimaryBank 身份，
        // 只要 PrimaryBank 身份能通过 hasValidRole 检查即可（level <= required）。
        // 你的 hasValidRole 只检查 active && addr!=0，所以 PrimaryBank 身份也是 valid 的。
        // 
        // 但是！Core 合约的 verifyBlock 可能要求 explicitly hasRole(VALIDATOR_ROLE)。
        // 如果 Deployer 需要提议区块，它必须有 VALIDATOR_ROLE。
        // 我们可以直接 grantRole 来增加 VALIDATOR_ROLE，而不覆盖 roleInfo。
        
        const VALIDATOR_ROLE = await accessControl.VALIDATOR_ROLE();
        let txVal3 = await accessControl.grantRole(VALIDATOR_ROLE, deployer.address);
        await txVal3.wait();
        
        console.log("Validators assigned.");

        // --------------------------------------------------------
        // 4. 部署其他合约
        // --------------------------------------------------------
        const CDBCUTXO = await ethers.getContractFactory("CDBCUTXO");
        utxo = await CDBCUTXO.deploy();
        await utxo.waitForDeployment();

        const CDBCRegulatory = await ethers.getContractFactory("CDBCRegulatory");
        regulatory = await CDBCRegulatory.deploy();
        await regulatory.waitForDeployment();

        // --------------------------------------------------------
        // 5. 部署 Core 并授权
        // --------------------------------------------------------
        const CDBCConsensusCore = await ethers.getContractFactory("CDBCConsensusCore");
        consensusCore = await CDBCConsensusCore.deploy(await accessControl.getAddress());
        await consensusCore.waitForDeployment();

        // --------------------------------------------------------
        // 6. 部署 Consensus (Proxy) 并授权
        // --------------------------------------------------------
        const CDBCConsensus = await ethers.getContractFactory("CDBCConsensus");
        consensus = await CDBCConsensus.deploy(
            await regulatory.getAddress(),
            await consensusCore.getAddress()
        );
        await consensus.waitForDeployment();

        // 给 Consensus 合约授予 PRIMARY_BANK_ROLE (它是管理者)
        const consensusAddress = await consensus.getAddress();
        console.log("Granting PRIMARY_BANK_ROLE to Consensus Contract...");
        
        let tx2 = await accessControl.grantRole(PRIMARY_BANK_ROLE, consensusAddress);
        await tx2.wait();
        
        // 同时也需要给 Consensus 合约手动填充 RoleInfo，否则它在某些检查中可能会失败
        // 虽然 Core 的 addValidator 是检查 msg.sender (即 Consensus合约) 是否有 PRIMARY_BANK_ROLE
        // 而不是检查 hasValidRole。但为了保险，我们手动写一个 roleInfo（如果可以的话）。
        // 你的合约没有直接写 roleInfo 的函数，只能通过 assign...。
        // 目前先这样，因为 addValidator 只检查 hasRole(PRIMARY_BANK_ROLE)，这不需要 roleInfo。
    });

    describe("Deployment", function () {
        it("Should deploy successfully with correct parameters", async function () {
            expect(await consensus.getAddress()).to.be.properAddress;
        });
    });

    describe("Validator Management", function () {
        it("Should proxy addValidator call to core contract", async function () {
            // addr1 已经被 assignValidator 了，所以 hasValidRole 应该返回 true
            // 且 !validators[addr1].active 为 true (还没加入共识层)
            
            const tx = await consensus.addValidator(addr1.address, "TestValidator");
            await tx.wait(); 

            const validatorData = await consensusCore.validators(addr1.address);
            expect(validatorData.name).to.equal("TestValidator");
            expect(validatorData.active).to.be.true;
        });
    });

    describe("Consensus Core Integration", function () {
        it("Should initialize validators correctly", async function () {
            // 注意：initialValidators 里的地址必须都通过 hasValidRole 检查
            // deployer (PrimaryBank -> Valid), addr1 (Validator -> Valid), addr2 (Validator -> Valid)
            
            const initialValidators = [deployer.address, addr1.address, addr2.address];
            const validatorNames = ["Validator1", "Validator2", "Validator3"];

            const tx = await consensus.initializeValidators(initialValidators, validatorNames);
            await tx.wait(); 

            const count = await consensusCore.currentValidatorCount();
            expect(count).to.equal(3);
        });
    });
});

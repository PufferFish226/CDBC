// SPDX-License-Identifier: MIT
import { expect } from "chai";
import hardhat from "hardhat";
const { ethers } = hardhat;

describe("CDBC Business Flow Test", function () {
    let utxo;
    let deployer, primaryBank, secondaryBank, enterpriseA, supplierC, enterpriseB;
    let PRIMARY_BANK_ROLE;

    // 辅助函数：精准提取 TransactionCreated 事件中的 ID
    async function extractTxIdFromReceipt(receipt, contract) {
        for (const log of receipt.logs) {
            try {
                const parsedLog = contract.interface.parseLog(log);
                if (parsedLog.name === "TransactionCreated") {
                    return parsedLog.args[0];
                }
            } catch (e) {}
        }
        throw new Error("无法在回执中找到 TransactionCreated 事件");
    }

    beforeEach(async function () {
        [deployer, primaryBank, secondaryBank, enterpriseA, supplierC, enterpriseB] = await ethers.getSigners();
        const CDBCUTXO = await ethers.getContractFactory("CDBCUTXO");
        utxo = await CDBCUTXO.deploy();
        await utxo.waitForDeployment();

        try {
             PRIMARY_BANK_ROLE = await utxo.PRIMARY_BANK_ROLE();
        } catch {
             PRIMARY_BANK_ROLE = ethers.keccak256(ethers.toUtf8Bytes("PRIMARY_BANK_ROLE"));
        }

        console.log("配置初始权限...");
        let tx = await utxo.grantRole(PRIMARY_BANK_ROLE, primaryBank.address);
        await tx.wait(); 
    });

    describe("Business Flow Simulation", function () {
        it("Should simulate the complete business flow with regulatory compliance", async function () {
            const ONE_BILLION = ethers.parseEther("100000000"); 
            const FIFTY_MILLION = ethers.parseEther("50000000"); 
            const TEN_MILLION = ethers.parseEther("10000000"); 
            const TWO_MILLION = ethers.parseEther("2000000"); 
            const EIGHT_MILLION = ethers.parseEther("8000000"); 

            // ========================================================
            // 1. 央行铸币与分发
            // ========================================================
            console.log("\n1. [央行] 铸币 1亿，并下发 5000万 给商业银行");
            
            let tx1 = await utxo.mint(deployer.address, ONE_BILLION);
            await tx1.wait();

            let pbUTXOs = await utxo.getAddressUTXOs(deployer.address);
            if (pbUTXOs.length === 0) throw new Error("铸币未产生 UTXO");
            let mintTxId = ethers.zeroPadValue(ethers.toBeHex(pbUTXOs[0]), 32);

            console.log("   [Action] 预先授权二级银行角色...");
            let txAuth = await utxo.assignSecondaryBank(secondaryBank.address, "Verified_Secondary_Bank");
            await txAuth.wait();

            let inputs1 = [{ prevTxId: mintTxId, outputIndex: 0, signature: "0x" }];
            let outputs1 = [
                { value: FIFTY_MILLION, recipient: secondaryBank.address, isSpent: false, lockTime: 0 },
                { value: ONE_BILLION - FIFTY_MILLION, recipient: deployer.address, isSpent: false, lockTime: 0 } 
            ];

            let tx2 = await utxo.createTransaction(inputs1, outputs1);
            let receipt2 = await tx2.wait();
            
            let txId_Step1 = await extractTxIdFromReceipt(receipt2, utxo);
            console.log("   [Debug] 交易1 ID:", txId_Step1);

            let sbBalance = await utxo.getAddressBalance(secondaryBank.address);
            expect(sbBalance).to.equal(FIFTY_MILLION);
            console.log("   ✅ 资金下发成功");

            // ========================================================
            // 2. 商业银行 KYC 与放款
            // ========================================================
            console.log("\n2. [商业银行] 认证企业A并放款 1000万");

            let tx4 = await utxo.connect(secondaryBank).assignEnterprise(enterpriseA.address, "Green_Enterprise_A");
            await tx4.wait();
            let tx5 = await utxo.connect(secondaryBank).assignEnterprise(supplierC.address, "Verified_Supplier_C");
            await tx5.wait();

            let inputs2 = [{ prevTxId: txId_Step1, outputIndex: 0, signature: "0x" }];
            let outputs2 = [
                { value: TEN_MILLION, recipient: enterpriseA.address, isSpent: false, lockTime: 0 },
                { value: FIFTY_MILLION - TEN_MILLION, recipient: secondaryBank.address, isSpent: false, lockTime: 0 }
            ];

            let tx6 = await utxo.connect(secondaryBank).createTransaction(inputs2, outputs2);
            let receipt6 = await tx6.wait();
            
            let txId_Step2 = await extractTxIdFromReceipt(receipt6, utxo);
            console.log("   [Debug] 交易2 ID:", txId_Step2);

            expect(await utxo.getAddressBalance(enterpriseA.address)).to.equal(TEN_MILLION);
            console.log("   ✅ KYC认证完成，专项资金已到账");

            // ========================================================
            // 3. 企业合规消费
            // ========================================================
            console.log("\n3. [企业A] 支付 200万 给合规供应商C");

            let inputs3 = [{ prevTxId: txId_Step2, outputIndex: 0, signature: "0x" }];
            let outputs3 = [
                { value: TWO_MILLION, recipient: supplierC.address, isSpent: false, lockTime: 0 },
                { value: TEN_MILLION - TWO_MILLION, recipient: enterpriseA.address, isSpent: false, lockTime: 0 }
            ];

            let tx7 = await utxo.connect(enterpriseA).createTransaction(inputs3, outputs3);
            let receipt7 = await tx7.wait();

            let txId_Step3 = await extractTxIdFromReceipt(receipt7, utxo);
            
            expect(await utxo.getAddressBalance(supplierC.address)).to.equal(TWO_MILLION);
            console.log("   ✅ 合规交易成功");

            // ========================================================
            // 4. 非法转账拦截测试
            // ========================================================
            console.log("\n4. [监管拦截] 企业A 试图转账 800万 给未认证企业B");

            let inputs4 = [{ prevTxId: txId_Step3, outputIndex: 1, signature: "0x" }];
            let outputs4 = [
                { value: EIGHT_MILLION, recipient: enterpriseB.address, isSpent: false, lockTime: 0 }
            ];

            await expect(
                utxo.connect(enterpriseA).createTransaction(inputs4, outputs4)
            ).to.be.reverted; 
            
            console.log("   ✅ 交易被链上合约自动拦截 (Reverted)");

            let entB_Balance = await utxo.getAddressBalance(enterpriseB.address);
            expect(entB_Balance).to.equal(0);

            // ========================================================
            // 5. 央行执行惩罚
            // ========================================================
            console.log("\n5. [央行惩罚] 检测到违规尝试，撤销企业A白名单");

            let ENTERPRISE_ROLE;
            try { ENTERPRISE_ROLE = await utxo.ENTERPRISE_ROLE(); } 
            catch { ENTERPRISE_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ENTERPRISE_ROLE")); }

            // 【关键修改】使用函数签名显式调用你自定义的 (address, bytes32) 版本
            let txPunish = await utxo["revokeRole(address,bytes32)"](enterpriseA.address, ENTERPRISE_ROLE);
            await txPunish.wait();

            // 验证角色丢失
            // hasRole 是标准函数，没有重载，可以直接调
            let hasRole = await utxo.hasRole(ENTERPRISE_ROLE, enterpriseA.address);
            expect(hasRole).to.be.false;

            console.log("   ✅ 惩罚执行完毕，企业A已被移出白名单");
        });
    });
});

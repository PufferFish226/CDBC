import { ethers } from "hardhat";

async function main() {
  console.log("Deploying CDBC smart contracts...");
  
  // 获取部署账户
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  
  // 检查部署账户余额
  const balance = await deployer.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "ETH");
  
  // 1. 部署权限控制合约
  console.log("\n1. Deploying CDBCAccessControl...");
  const CDBCAccessControl = await ethers.getContractFactory("CDBCAccessControl");
  const accessControl = await CDBCAccessControl.deploy();
  await accessControl.waitForDeployment();
  console.log("CDBCAccessControl deployed to:", await accessControl.getAddress());
  
  // 2. 部署UTXO合约
  console.log("\n2. Deploying CDBCUTXO...");
  const CDBCUTXO = await ethers.getContractFactory("CDBCUTXO");
  const utxo = await CDBCUTXO.deploy();
  await utxo.waitForDeployment();
  console.log("CDBCUTXO deployed to:", await utxo.getAddress());
  
  // 3. 部署监管合约
  console.log("\n3. Deploying CDBCRegulatory...");
  const CDBCRegulatory = await ethers.getContractFactory("CDBCRegulatory");
  const regulatory = await CDBCRegulatory.deploy();
  await regulatory.waitForDeployment();
  console.log("CDBCRegulatory deployed to:", await regulatory.getAddress());
  
  // 4. 部署核心共识合约
  console.log("\n4. Deploying CDBCConsensusCore...");
  const CDBCConsensusCore = await ethers.getContractFactory("CDBCConsensusCore");
  const consensusCore = await CDBCConsensusCore.deploy(await accessControl.getAddress());
  await consensusCore.waitForDeployment();
  console.log("CDBCConsensusCore deployed to:", await consensusCore.getAddress());
  
  // 5. 部署主共识合约
  console.log("\n5. Deploying CDBCConsensus...");
  const CDBCConsensus = await ethers.getContractFactory("CDBCConsensus");
  const consensus = await CDBCConsensus.deploy(
    await regulatory.getAddress(),
    await consensusCore.getAddress()
  );
  await consensus.waitForDeployment();
  console.log("CDBCConsensus deployed to:", await consensus.getAddress());
  
  console.log("\nDeployment successful!");
  
  // 6. 初始化验证节点
  console.log("\n6. Initializing validators...");
  try {
    const initialValidators = [
      deployer.address,
      // 添加更多初始验证节点地址
      "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
      "0x90F79bf6EB2c4f870365E785982E1f101E93b906"
    ];
    
    const validatorNames = [
      "PrimaryValidator",
      "SecondaryValidator1",
      "SecondaryValidator2"
    ];
    
    const initializeTx = await consensus.initializeValidators(initialValidators, validatorNames);
    await initializeTx.wait();
    console.log("Validators initialized successfully!");
  } catch (error) {
    console.error("Error initializing validators:", error.message);
  }
  
  console.log("\nDeployment script completed!");
  console.log("\nDeployed Contracts:");
  console.log("- CDBCAccessControl:", await accessControl.getAddress());
  console.log("- CDBCUTXO:", await utxo.getAddress());
  console.log("- CDBCRegulatory:", await regulatory.getAddress());
  console.log("- CDBCConsensusCore:", await consensusCore.getAddress());
  console.log("- CDBCConsensus:", await consensus.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ICDBCRegulatory.sol";
import "./CDBCConsensusCore.sol";

contract CDBCConsensus {
    // 核心共识合约地址
    CDBCConsensusCore public consensusCore;
    ICDBCRegulatory public regulatory;
    
    // 构造函数
    constructor(address _regulatoryAddr, address _consensusCoreAddr) {
        regulatory = ICDBCRegulatory(_regulatoryAddr);
        consensusCore = CDBCConsensusCore(_consensusCoreAddr);
    }
    
    // 代理调用核心共识合约的方法
    function addValidator(address validator, string memory name) external {
        consensusCore.addValidator(validator, name);
    }
    
    function removeValidator(address validator) external {
        consensusCore.removeValidator(validator);
    }
    
    function updateValidatorStatus(address validator, bool active) external {
        consensusCore.updateValidatorStatus(validator, active);
    }
    
    function initializeValidators(address[] calldata initialValidators, string[] calldata names) external {
        consensusCore.initializeValidators(initialValidators, names);
    }
    
    function castVote(uint256 blockNumber, uint256 txId, bool approve) external {
        consensusCore.castVote(blockNumber, txId, approve);
    }
    
    function verifyBlock(uint256 blockNumber, uint256 txCount) external {
        consensusCore.verifyBlock(blockNumber, txCount);
    }
    
    function proposeBlock(uint256 blockNumber) external {
        consensusCore.proposeBlock(blockNumber);
    }
    
    // 查询方法
    function getActiveValidators() external view returns (address[] memory) {
        return consensusCore.getActiveValidators();
    }
    
    // 注意：blockVotes和blockVerifications是mapping，无法直接返回数组
    // 需要在ConsensusCore中添加相应的getter函数
    
    function checkValidatorStatus(address validator) external view returns (bool) {
        // 注意：validators是mapping，需要在ConsensusCore中添加getter函数
        // 这里简化实现
        return true;
    }
    
    function getValidatorVoteStats(address validator) external view returns (uint256) {
        // 注意：validators是mapping，需要在ConsensusCore中添加getter函数
        // 这里简化实现
        return 0;
    }
    
    // 获取核心合约地址
    function getConsensusCoreAddr() external view returns (address) {
        return address(consensusCore);
    }
    
    // 获取监管合约地址
    function getRegulatoryAddr() external view returns (address) {
        return address(regulatory);
    }
}

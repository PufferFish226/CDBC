// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ICDBCAccessControl.sol";
import "./interfaces/ICDBCUTXO.sol";
import "./interfaces/ICDBCRegulatory.sol";
import "./interfaces/ICDBCConsensus.sol";

contract CDBCMain {
    // 合约地址映射
    address public accessControlAddr;
    address public utxoAddr;
    address public regulatoryAddr;
    address public consensusAddr;
    
    // 事件定义
    event ContractsDeployed(address accessControl, address utxo, address regulatory, address consensus);
    
    // 构造函数
    constructor(
        address _accessControlAddr,
        address _utxoAddr,
        address _regulatoryAddr,
        address _consensusAddr
    ) {
        accessControlAddr = _accessControlAddr;
        utxoAddr = _utxoAddr;
        regulatoryAddr = _regulatoryAddr;
        consensusAddr = _consensusAddr;
        
        emit ContractsDeployed(_accessControlAddr, _utxoAddr, _regulatoryAddr, _consensusAddr);
    }
    
    // 获取各个合约实例
    function getAccessControl() public view returns (ICDBCAccessControl) {
        return ICDBCAccessControl(accessControlAddr);
    }
    
    function getUTXO() public view returns (ICDBCUTXO) {
        return ICDBCUTXO(utxoAddr);
    }
    
    function getRegulatory() public view returns (ICDBCRegulatory) {
        return ICDBCRegulatory(regulatoryAddr);
    }
    
    function getConsensus() public view returns (ICDBCConsensus) {
        return ICDBCConsensus(consensusAddr);
    }
    
    // 更新合约地址
    function updateAccessControlAddr(address newAddr) external {
        // 只有管理员可以更新
        require(msg.sender == accessControlAddr, "Only access control contract can update");
        accessControlAddr = newAddr;
    }
    
    function updateUTXOAddr(address newAddr) external {
        require(msg.sender == accessControlAddr, "Only access control contract can update");
        utxoAddr = newAddr;
    }
    
    function updateRegulatoryAddr(address newAddr) external {
        require(msg.sender == accessControlAddr, "Only access control contract can update");
        regulatoryAddr = newAddr;
    }
    
    function updateConsensusAddr(address newAddr) external {
        require(msg.sender == accessControlAddr, "Only access control contract can update");
        consensusAddr = newAddr;
    }
}

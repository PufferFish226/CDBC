// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./UTXO.sol";

contract CDBCRegulatory is CDBCUTXO {
    // 交易监控相关映射
    mapping(uint256 => bool) public auditedTransactions;
    mapping(uint256 => AuditReport) public auditReports;
    mapping(address => uint256[]) public addressAuditReports;
    mapping(uint256 => SuspiciousTransaction) public suspiciousTransactions;
    
    // 审计报告结构体
    struct AuditReport {
        uint256 reportId;
        uint256 txId;
        address auditor;
        string result;
        string notes;
        uint256 timestamp;
        bool passed;
    }
    
    // 可疑交易结构体
    struct SuspiciousTransaction {
        uint256 txId;
        address sender;
        address recipient;
        uint256 amount;
        string reason;
        bool investigated;
        uint256 timestamp;
    }
    
    // 监管参数
    uint256 public LARGE_TRANSACTION_THRESHOLD = 100000 * 10 ** 18;
    uint256 public FREQUENT_TRANSACTION_THRESHOLD = 10;
    
    // 交易频率监控
    mapping(address => uint256) public recentTransactionCount;
    mapping(address => uint256) public recentTransactionWindow;
    
    // 计数器
    uint256 public reportCounter;
    uint256 public suspiciousCounter;
    
    // 事件定义
    event TransactionAudited(uint256 indexed reportId, uint256 indexed txId, bool passed, string result);
    event SuspiciousTransactionDetected(uint256 indexed suspiciousId, uint256 indexed txId, string reason);
    event TransactionInvestigated(uint256 indexed suspiciousId, bool confirmed, string notes);
    event RegulatoryAction(uint256 indexed txId, string action, string reason, address indexed regulator);
    
    // 构造函数
    constructor() {
        reportCounter = 0;
        suspiciousCounter = 0;
    }
    
    // 审计交易（只有监管机构可以执行）
    function auditTransaction(uint256 txId, string memory result, string memory notes, bool passed) external onlyRole(REGULATOR_ROLE) {
        require(txIdExists[txId], "Transaction does not exist");
        
        uint256 reportId = uint256(keccak256(abi.encodePacked(txId, msg.sender, block.timestamp)));
        
        AuditReport memory report = AuditReport({
            reportId: reportId,
            txId: txId,
            auditor: msg.sender,
            result: result,
            notes: notes,
            timestamp: block.timestamp,
            passed: passed
        });
        
        auditReports[reportId] = report;
        auditedTransactions[txId] = true;
        
        Transaction memory txn = transactions[txId];
        addressAuditReports[txn.sender].push(reportId);
        if (txn.outputs.length > 0) {
            addressAuditReports[txn.outputs[0].recipient].push(reportId);
        }
        
        emit TransactionAudited(reportId, txId, passed, result);
        reportCounter++;
    }
    
    // 检测可疑交易（内部函数）
    function detectSuspiciousTransaction(uint256 txId, Transaction memory txn) internal {
        bool isSuspicious = false;
        string memory reason = "";
        
        // 计算交易总金额
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < txn.outputs.length; i++) {
            totalAmount += txn.outputs[i].value;
        }
        
        // 检查大额交易
        if (totalAmount > LARGE_TRANSACTION_THRESHOLD) {
            isSuspicious = true;
            reason = "Large transaction amount";
        }
        
        // 检查交易频率
        if (block.timestamp - recentTransactionWindow[txn.sender] < 3600) {
            recentTransactionCount[txn.sender]++;
            if (recentTransactionCount[txn.sender] > FREQUENT_TRANSACTION_THRESHOLD) {
                isSuspicious = true;
                reason = "Frequent transactions";
            }
        } else {
            recentTransactionWindow[txn.sender] = block.timestamp;
            recentTransactionCount[txn.sender] = 1;
        }
        
        // 检查发送方和接收方是否为同一地址
        for (uint256 i = 0; i < txn.outputs.length; i++) {
            if (txn.sender == txn.outputs[i].recipient) {
                isSuspicious = true;
                reason = "Self transaction";
                break;
            }
        }
        
        // 如果检测到可疑交易，记录下来
        if (isSuspicious) {
            uint256 suspiciousId = suspiciousCounter;
            
            SuspiciousTransaction memory suspiciousTx = SuspiciousTransaction({
                txId: txId,
                sender: txn.sender,
                recipient: txn.outputs.length > 0 ? txn.outputs[0].recipient : address(0),
                amount: totalAmount,
                reason: reason,
                investigated: false,
                timestamp: block.timestamp
            });
            
            suspiciousTransactions[suspiciousId] = suspiciousTx;
            emit SuspiciousTransactionDetected(suspiciousId, txId, reason);
            suspiciousCounter++;
        }
    }
    
    // 重写创建交易函数，添加监管监控
    function createTransaction(
        Input[] calldata inputs,
        Output[] calldata outputs
    ) public virtual override returns (uint256) {
        uint256 txId = super.createTransaction(inputs, outputs);
        
        // 监控新创建的交易
        Transaction memory newTx = transactions[txId];
        detectSuspiciousTransaction(txId, newTx);
        
        return txId;
    }
    
    // 调查可疑交易
    function investigateSuspiciousTransaction(uint256 suspiciousId, bool confirmed, string memory notes) external onlyRole(REGULATOR_ROLE) {
        require(suspiciousId < suspiciousCounter, "Suspicious transaction does not exist");
        
        SuspiciousTransaction storage suspiciousTx = suspiciousTransactions[suspiciousId];
        require(!suspiciousTx.investigated, "Transaction already investigated");
        
        suspiciousTx.investigated = true;
        
        emit TransactionInvestigated(suspiciousId, confirmed, notes);
        
        // 如果确认是可疑交易，执行监管措施
        if (confirmed) {
            emit RegulatoryAction(suspiciousTx.txId, "Confirmed suspicious", notes, msg.sender);
        }
    }
    
    // 获取地址的审计报告
    function getAddressAuditReports(address addr) external view returns (uint256[] memory) {
        return addressAuditReports[addr];
    }
    
    // 获取审计报告详情
    function getAuditReport(uint256 reportId) external view returns (AuditReport memory) {
        return auditReports[reportId];
    }
    
    // 获取可疑交易详情
    function getSuspiciousTransaction(uint256 suspiciousId) external view returns (SuspiciousTransaction memory) {
        return suspiciousTransactions[suspiciousId];
    }
    
    // 生成地址审计报告（只有监管机构可以执行）
    function generateAddressAuditReport(address addr, string memory notes) external onlyRole(REGULATOR_ROLE) returns (uint256) {
        uint256 reportId = uint256(keccak256(abi.encodePacked(addr, msg.sender, block.timestamp, reportCounter)));
        
        // 这里可以添加更复杂的地址审计逻辑
        uint256 balance = getAddressBalance(addr);
        uint256[] memory addrUTXOs = getAddressUTXOs(addr);
        
        string memory result = balance > 0 ? "Normal" : "Low balance";
        bool passed = true;
        
        AuditReport memory report = AuditReport({
            reportId: reportId,
            txId: 0, // 地址审计报告没有特定交易ID
            auditor: msg.sender,
            result: result,
            notes: notes,
            timestamp: block.timestamp,
            passed: passed
        });
        
        auditReports[reportId] = report;
        addressAuditReports[addr].push(reportId);
        
        emit TransactionAudited(reportId, 0, passed, result);
        reportCounter++;
        
        return reportId;
    }
    
    // 查询交易历史（只有监管机构可以执行）
    function getTransactionHistory(address addr, uint256 startIndex, uint256 count) external view onlyRole(REGULATOR_ROLE) returns (Transaction[] memory) {
        // 这里简化实现，实际应该维护地址到交易ID的映射
        Transaction[] memory result = new Transaction[](count);
        uint256 found = 0;
        
        for (uint256 i = startIndex; i < txCounter && found < count; i++) {
            Transaction memory txn = transactions[i];
            if (txn.sender == addr) {
                result[found] = txn;
                found++;
            } else {
                for (uint256 j = 0; j < txn.outputs.length; j++) {
                    if (txn.outputs[j].recipient == addr) {
                        result[found] = txn;
                        found++;
                        break;
                    }
                }
            }
        }
        
        // 调整结果数组大小
        Transaction[] memory finalResult = new Transaction[](found);
        for (uint256 i = 0; i < found; i++) {
            finalResult[i] = result[i];
        }
        
        return finalResult;
    }
    
    // 设置大额交易阈值
    function setLargeTransactionThreshold(uint256 newThreshold) external onlyRole(PRIMARY_BANK_ROLE) {
        LARGE_TRANSACTION_THRESHOLD = newThreshold;
    }
    
    // 设置频繁交易阈值
    function setFrequentTransactionThreshold(uint256 newThreshold) external onlyRole(PRIMARY_BANK_ROLE) {
        FREQUENT_TRANSACTION_THRESHOLD = newThreshold;
    }
}
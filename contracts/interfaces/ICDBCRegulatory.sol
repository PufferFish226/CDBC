// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ICDBCUTXO.sol";

interface ICDBCRegulatory {
    // 事件定义
    event TransactionAudited(uint256 indexed reportId, uint256 indexed txId, bool passed, string result);
    event SuspiciousTransactionDetected(uint256 indexed suspiciousId, uint256 indexed txId, string reason);
    event TransactionInvestigated(uint256 indexed suspiciousId, bool confirmed, string notes);
    event RegulatoryAction(uint256 indexed txId, string action, string reason, address indexed regulator);

    // 审计功能
    function auditTransaction(uint256 txId, string memory result, string memory notes, bool passed) external;
    function generateAddressAuditReport(address addr, string memory notes) external returns (uint256);
    function getTransactionHistory(address addr, uint256 startIndex, uint256 count) external view returns (ICDBCUTXO.Transaction[] memory);
    
    // 可疑交易处理
    function investigateSuspiciousTransaction(uint256 suspiciousId, bool confirmed, string memory notes) external;
    
    // 查询功能
    function getAddressAuditReports(address addr) external view returns (uint256[] memory);
    function getAuditReport(uint256 reportId) external view returns (AuditReport memory);
    function getSuspiciousTransaction(uint256 suspiciousId) external view returns (SuspiciousTransaction memory);
    
    // 监管参数配置
    function setLargeTransactionThreshold(uint256 newThreshold) external;
    function setFrequentTransactionThreshold(uint256 newThreshold) external;
    
    // 数据结构
    struct AuditReport {
        uint256 reportId;
        uint256 txId;
        address auditor;
        string result;
        string notes;
        uint256 timestamp;
        bool passed;
    }
    
    struct SuspiciousTransaction {
        uint256 txId;
        address sender;
        address recipient;
        uint256 amount;
        string reason;
        bool investigated;
        uint256 timestamp;
    }
}

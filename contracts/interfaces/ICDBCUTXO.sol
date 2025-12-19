// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ICDBCAccessControl.sol";

interface ICDBCUTXO {
    // 事件定义
    event UTXOCreated(uint256 indexed utxoId, uint256 value, address indexed recipient);
    event UTXOSpent(uint256 indexed utxoId, uint256 txId);
    event TransactionCreated(uint256 indexed txId, address indexed sender, uint256 outputsCount);
    event CoinsMinted(uint256 amount, address indexed minter);

    // 铸币功能
    function mint(address recipient, uint256 amount) external;
    
    // 交易功能
    function createTransaction(
        Input calldata input,
        Output[] calldata outputs
    ) external returns (uint256);
    
    // 查询功能
    function getAddressUTXOs(address owner) external view returns (uint256[] memory);
    function getUTXODetails(uint256 utxoId) external view returns (Output memory);
    function getTransaction(uint256 txId) external view returns (Transaction memory);
    function getAddressBalance(address owner) external view returns (uint256);
    
    // 模型转换功能
    function convertAccountToUTXO(uint256 amount) external;
    function convertUTXOToAccount(uint256[] calldata utxoIds, uint256 amount) external;
    
    // 数据结构
    struct Output {
        uint256 value;
        address payable recipient;
        bool isSpent;
        uint256 lockTime;
    }
    
    struct Input {
        uint256 prevTxId;
        uint256 outputIndex;
        bytes signature;
    }
    
    struct Transaction {
        uint256 txId;
        Input[] inputs;
        Output[] outputs;
        uint256 timestamp;
        address sender;
    }
}

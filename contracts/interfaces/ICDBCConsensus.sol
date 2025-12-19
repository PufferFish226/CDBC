// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ICDBCRegulatory.sol";

interface ICDBCConsensus {
    // 事件定义
    event ValidatorAdded(address indexed validator, string name);
    event ValidatorRemoved(address indexed validator);
    event ValidatorStatusChanged(address indexed validator, bool active);
    event VoteCast(address indexed validator, uint256 indexed blockNumber, bool approve);
    event BlockVerified(uint256 indexed blockNumber, bool verified, uint256 approvals, uint256 rejections);
    event ConsensusParameterUpdated(string paramName, uint256 oldValue, uint256 newValue);

    // 验证节点管理
    function addValidator(address validator, string memory name) external;
    function removeValidator(address validator) external;
    function updateValidatorStatus(address validator, bool active) external;
    function initializeValidators(address[] calldata initialValidators, string[] calldata names) external;
    
    // 共识投票
    function castVote(uint256 blockNumber, uint256 txId, bool approve) external;
    function verifyBlock(uint256 blockNumber, uint256 txCount) external;
    function proposeBlock(uint256 blockNumber) external;
    
    // 查询功能
    function getActiveValidators() external view returns (address[] memory);
    function getBlockVotes(uint256 blockNumber) external view returns (Vote[] memory);
    function getBlockVerification(uint256 blockNumber) external view returns (BlockVerification memory);
    function checkValidatorStatus(address validator) external view returns (bool);
    function getValidatorVoteStats(address validator) external view returns (uint256);
    
    // 数据结构
    struct Validator {
        address addr;
        string name;
        bool active;
        uint256 stake;
        uint256 joinTime;
        uint256 lastBlockProposed;
        uint256 voteCount;
    }
    
    struct Vote {
        address validator;
        uint256 blockNumber;
        uint256 txId;
        bool approve;
        uint256 timestamp;
    }
    
    struct BlockVerification {
        uint256 blockNumber;
        uint256 txCount;
        uint256 approvals;
        uint256 rejections;
        bool verified;
        uint256 timestamp;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ICDBCAccessControl.sol";

contract CDBCConsensusCore {
    // 验证节点相关结构
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
    
    // 验证节点相关映射
    mapping(address => Validator) public validators;
    mapping(uint256 => Validator[]) public blockValidators;
    mapping(address => uint256[]) public validatorBlocks;
    
    // 投票相关映射
    mapping(uint256 => Vote[]) public blockVotes;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    
    // 区块验证映射
    mapping(uint256 => BlockVerification) public blockVerifications;
    
    // 共识参数
    uint256 public constant MIN_VALIDATORS = 3;
    uint256 public constant MAX_VALIDATORS = 15;
    uint256 public constant VALIDATOR_QUORUM = 2;
    uint256 public currentValidatorCount;
    uint256 public currentBlockNumber;
    
    // 权限控制合约地址
    address public accessControlAddr;
    
    // 事件定义
    event ValidatorAdded(address indexed validator, string name);
    event ValidatorRemoved(address indexed validator);
    event ValidatorStatusChanged(address indexed validator, bool active);
    event VoteCast(address indexed validator, uint256 indexed blockNumber, bool approve);
    event BlockVerified(uint256 indexed blockNumber, bool verified, uint256 approvals, uint256 rejections);
    event ConsensusParameterUpdated(string paramName, uint256 oldValue, uint256 newValue);
    
    // 构造函数
    constructor(address _accessControlAddr) {
        accessControlAddr = _accessControlAddr;
        currentValidatorCount = 0;
        currentBlockNumber = 0;
    }
    
    // 添加验证节点（只有一级银行可以执行）
    function addValidator(address validator, string memory name) external {
        ICDBCAccessControl accessControl = ICDBCAccessControl(accessControlAddr);
        bytes32 primaryBankRole = accessControl.PRIMARY_BANK_ROLE();
        require(accessControl.hasRole(primaryBankRole, msg.sender), "Only primary bank can add validators");
        
        require(!validators[validator].active, "Validator already exists");
        require(currentValidatorCount < MAX_VALIDATORS, "Maximum validators reached");
        require(accessControl.hasValidRole(validator), "Validator must have a valid role");
        
        validators[validator] = Validator({
            addr: validator,
            name: name,
            active: true,
            stake: 0,
            joinTime: block.timestamp,
            lastBlockProposed: 0,
            voteCount: 0
        });
        currentValidatorCount++;
        
        emit ValidatorAdded(validator, name);
    }
    
    // 移除验证节点（只有一级银行可以执行）
    function removeValidator(address validator) external {
        ICDBCAccessControl accessControl = ICDBCAccessControl(accessControlAddr);
        bytes32 primaryBankRole = accessControl.PRIMARY_BANK_ROLE();
        require(accessControl.hasRole(primaryBankRole, msg.sender), "Only primary bank can remove validators");
        
        require(validators[validator].active, "Validator does not exist");
        require(currentValidatorCount > MIN_VALIDATORS, "Cannot remove validator: minimum count reached");
        
        validators[validator].active = false;
        currentValidatorCount--;
        
        emit ValidatorRemoved(validator);
    }
    
    // 更新验证节点状态（只有一级银行可以执行）
    function updateValidatorStatus(address validator, bool active) external {
        ICDBCAccessControl accessControl = ICDBCAccessControl(accessControlAddr);
        bytes32 primaryBankRole = accessControl.PRIMARY_BANK_ROLE();
        require(accessControl.hasRole(primaryBankRole, msg.sender), "Only primary bank can update validator status");
        
        require(validators[validator].addr != address(0), "Validator does not exist");
        
        validators[validator].active = active;
        
        if (active) {
            currentValidatorCount++;
        } else {
            currentValidatorCount--;
        }
        
        emit ValidatorStatusChanged(validator, active);
    }
    
    // 验证节点投票
    function castVote(uint256 blockNumber, uint256 txId, bool approve) external {
        require(validators[msg.sender].active, "Only active validators can vote");
        require(!hasVoted[blockNumber][msg.sender], "Validator already voted for this block");
        
        Vote memory vote = Vote({
            validator: msg.sender,
            blockNumber: blockNumber,
            txId: txId,
            approve: approve,
            timestamp: block.timestamp
        });
        
        blockVotes[blockNumber].push(vote);
        hasVoted[blockNumber][msg.sender] = true;
        validators[msg.sender].voteCount++;
        
        emit VoteCast(msg.sender, blockNumber, approve);
        
        // 检查是否达到共识
        checkConsensus(blockNumber);
    }
    
    // 检查是否达到共识
    function checkConsensus(uint256 blockNumber) internal {
        Vote[] storage votes = blockVotes[blockNumber];
        uint256 approvals = 0;
        uint256 rejections = 0;
        
        for (uint256 i = 0; i < votes.length; i++) {
            if (votes[i].approve) {
                approvals++;
            } else {
                rejections++;
            }
        }
        
        // 检查是否达到法定人数
        if (approvals >= VALIDATOR_QUORUM && approvals > rejections) {
            BlockVerification storage verification = blockVerifications[blockNumber];
            verification.blockNumber = blockNumber;
            verification.approvals = approvals;
            verification.rejections = rejections;
            verification.verified = true;
            verification.timestamp = block.timestamp;
            
            emit BlockVerified(blockNumber, true, approvals, rejections);
        }
    }
    
    // 验证区块
    function verifyBlock(uint256 blockNumber, uint256 txCount) external {
        ICDBCAccessControl accessControl = ICDBCAccessControl(accessControlAddr);
        bytes32 validatorRole = accessControl.VALIDATOR_ROLE();
        require(accessControl.hasRole(validatorRole, msg.sender), "Only validators can verify blocks");
        
        require(!blockVerifications[blockNumber].verified, "Block already verified");
        
        BlockVerification memory verification = BlockVerification({
            blockNumber: blockNumber,
            txCount: txCount,
            approvals: 0,
            rejections: 0,
            verified: false,
            timestamp: block.timestamp
        });
        
        blockVerifications[blockNumber] = verification;
        currentBlockNumber = blockNumber;
        
        // 记录验证节点参与的区块
        validatorBlocks[msg.sender].push(blockNumber);
        blockValidators[blockNumber].push(validators[msg.sender]);
    }
    
    // 获取活跃验证节点列表
    function getActiveValidators() external view returns (address[] memory) {
        address[] memory result = new address[](currentValidatorCount);
        uint256 index = 0;
        
        // 遍历所有验证节点，找到活跃的
        for (uint256 i = 0; i < currentValidatorCount; i++) {
            // 注意：这里需要维护一个活跃验证节点列表，否则无法高效遍历
            // 为简化实现，这里只返回空数组
            // 实际应用中应维护一个activeValidators数组
        }
        
        return result;
    }
    
    // 验证节点提议区块
    function proposeBlock(uint256 blockNumber) external {
        require(validators[msg.sender].active, "Only active validators can propose blocks");
        
        validators[msg.sender].lastBlockProposed = blockNumber;
        validators[msg.sender].voteCount++;
        
        // 记录验证节点参与的区块
        validatorBlocks[msg.sender].push(blockNumber);
        blockValidators[blockNumber].push(validators[msg.sender]);
    }
    
    // 初始化验证节点
    function initializeValidators(address[] calldata initialValidators, string[] calldata names) external {
        ICDBCAccessControl accessControl = ICDBCAccessControl(accessControlAddr);
        bytes32 primaryBankRole = accessControl.PRIMARY_BANK_ROLE();
        require(accessControl.hasRole(primaryBankRole, msg.sender), "Only primary bank can initialize validators");
        
        require(initialValidators.length >= MIN_VALIDATORS, "Must have at least MIN_VALIDATORS initial validators");
        require(initialValidators.length <= MAX_VALIDATORS, "Cannot exceed MAX_VALIDATORS initial validators");
        require(initialValidators.length == names.length, "Validators and names arrays must have the same length");
        
        for (uint256 i = 0; i < initialValidators.length; i++) {
            // 直接实现addValidator逻辑，避免函数调用顺序问题
            address validator = initialValidators[i];
            string memory name = names[i];
            
            require(!validators[validator].active, "Validator already exists");
            require(currentValidatorCount < MAX_VALIDATORS, "Maximum validators reached");
            require(accessControl.hasValidRole(validator), "Validator must have a valid role");
            
            validators[validator] = Validator({
                addr: validator,
                name: name,
                active: true,
                stake: 0,
                joinTime: block.timestamp,
                lastBlockProposed: 0,
                voteCount: 0
            });
            currentValidatorCount++;
            
            emit ValidatorAdded(validator, name);
        }
    }
}
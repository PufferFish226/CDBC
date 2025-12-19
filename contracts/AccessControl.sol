// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract CDBCAccessControl is AccessControl {
    // 定义角色常量
    bytes32 public constant PRIMARY_BANK_ROLE = keccak256("PRIMARY_BANK_ROLE");
    bytes32 public constant SECONDARY_BANK_ROLE = keccak256("SECONDARY_BANK_ROLE");
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");
    bytes32 public constant ENTERPRISE_ROLE = keccak256("ENTERPRISE_ROLE");
    bytes32 public constant REGULATOR_ROLE = keccak256("REGULATOR_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    // 角色信息结构体
    struct RoleInfo {
        address addr;
        string name;
        uint256 level;
        bool active;
        uint256 createdAt;
    }

    // 地址到角色信息的映射
    mapping(address => RoleInfo) public roleInfo;

    // 事件定义
    event RoleAssigned(address indexed account, bytes32 indexed role, string name);
    event RoleRevoked(address indexed account, bytes32 indexed role);
    event RoleUpdated(address indexed account, string name, bool active);

    // 构造函数，初始化部署者为一级银行
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PRIMARY_BANK_ROLE, msg.sender);
        
        roleInfo[msg.sender] = RoleInfo({
            addr: msg.sender,
            name: "PrimaryBank",
            level: 1,
            active: true,
            createdAt: block.timestamp
        });
        
        emit RoleAssigned(msg.sender, PRIMARY_BANK_ROLE, "PrimaryBank");
    }

    // 一级银行分配二级银行角色
    function assignSecondaryBank(address account, string memory name) external onlyRole(PRIMARY_BANK_ROLE) {
        require(!hasRole(SECONDARY_BANK_ROLE, account), "Account already has secondary bank role");
        require(!hasRole(PRIMARY_BANK_ROLE, account), "Account is already a primary bank");
        
        _grantRole(SECONDARY_BANK_ROLE, account);
        
        roleInfo[account] = RoleInfo({
            addr: account,
            name: name,
            level: 2,
            active: true,
            createdAt: block.timestamp
        });
        
        emit RoleAssigned(account, SECONDARY_BANK_ROLE, name);
    }

    // 二级银行分配用户角色
    function assignUser(address account, string memory name) external onlyRole(SECONDARY_BANK_ROLE) {
        require(!hasRole(USER_ROLE, account) && !hasRole(ENTERPRISE_ROLE, account), "Account already has user/enterprise role");
        require(!hasRole(SECONDARY_BANK_ROLE, account), "Account is already a secondary bank");
        require(!hasRole(PRIMARY_BANK_ROLE, account), "Account is already a primary bank");
        
        _grantRole(USER_ROLE, account);
        
        roleInfo[account] = RoleInfo({
            addr: account,
            name: name,
            level: 3,
            active: true,
            createdAt: block.timestamp
        });
        
        emit RoleAssigned(account, USER_ROLE, name);
    }

    // 二级银行分配企业角色
    function assignEnterprise(address account, string memory name) external onlyRole(SECONDARY_BANK_ROLE) {
        require(!hasRole(USER_ROLE, account) && !hasRole(ENTERPRISE_ROLE, account), "Account already has user/enterprise role");
        require(!hasRole(SECONDARY_BANK_ROLE, account), "Account is already a secondary bank");
        require(!hasRole(PRIMARY_BANK_ROLE, account), "Account is already a primary bank");
        
        _grantRole(ENTERPRISE_ROLE, account);
        
        roleInfo[account] = RoleInfo({
            addr: account,
            name: name,
            level: 3,
            active: true,
            createdAt: block.timestamp
        });
        
        emit RoleAssigned(account, ENTERPRISE_ROLE, name);
    }

    // 一级银行分配监管角色
    function assignRegulator(address account, string memory name) external onlyRole(PRIMARY_BANK_ROLE) {
        require(!hasRole(REGULATOR_ROLE, account), "Account already has regulator role");
        
        _grantRole(REGULATOR_ROLE, account);
        
        roleInfo[account] = RoleInfo({
            addr: account,
            name: name,
            level: 0,
            active: true,
            createdAt: block.timestamp
        });
        
        emit RoleAssigned(account, REGULATOR_ROLE, name);
    }
    
     function assignValidator(address account, string memory name) external onlyRole(PRIMARY_BANK_ROLE) {
        require(!hasRole(VALIDATOR_ROLE, account), "Account already has validator role");
        
        _grantRole(VALIDATOR_ROLE, account);
        
        // 关键：必须更新 roleInfo，否则 hasValidRole 会返回 false
        roleInfo[account] = RoleInfo({
            addr: account,
            name: name,
            level: 2, // 假设验证者级别是 2，或者你可以自定义一个级别
            active: true,
            createdAt: block.timestamp
        });
        
        emit RoleAssigned(account, VALIDATOR_ROLE, name);
    }

    // 更新角色信息
    function updateRoleInfo(address account, string memory name, bool active) external {
        require(hasRole(PRIMARY_BANK_ROLE, msg.sender) || hasRole(SECONDARY_BANK_ROLE, msg.sender), "Only banks can update roles");
        require(roleInfo[account].addr != address(0), "Account does not have a role");
        
        RoleInfo storage info = roleInfo[account];
        info.name = name;
        info.active = active;
        
        emit RoleUpdated(account, name, active);
    }

    // 撤销角色
    function revokeRole(address account, bytes32 role) external {
        require(hasRole(PRIMARY_BANK_ROLE, msg.sender), "Only primary bank can revoke roles");
        require(hasRole(role, account), "Account does not have the role");
        
        _revokeRole(role, account);
        
        // 清除角色信息
        delete roleInfo[account];
        
        emit RoleRevoked(account, role);
    }

    // 检查账户是否具有有效角色
    function hasValidRole(address account) public view returns (bool) {
        RoleInfo memory info = roleInfo[account];
        return info.active && info.addr != address(0);
    }

    // 获取账户角色级别
    function getRoleLevel(address account) public view returns (uint256) {
        return roleInfo[account].level;
    }

    // 验证账户权限级别
    function validatePermission(address account, uint256 requiredLevel) public view returns (bool) {
        RoleInfo memory info = roleInfo[account];
        return info.active && info.level <= requiredLevel;
    }
}

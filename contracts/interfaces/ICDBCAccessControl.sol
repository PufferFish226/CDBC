// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICDBCAccessControl {
    // 事件定义
    event RoleAssigned(address indexed account, bytes32 indexed role, string name);
    event RoleRevoked(address indexed account, bytes32 indexed role);
    event RoleUpdated(address indexed account, string name, bool active);

    // 角色管理函数
    function assignSecondaryBank(address account, string memory name) external;
    function assignUser(address account, string memory name) external;
    function assignEnterprise(address account, string memory name) external;
    function assignRegulator(address account, string memory name) external;
    function updateRoleInfo(address account, string memory name, bool active) external;
    function revokeRole(address account, bytes32 role) external;

    // 角色查询函数
    function hasValidRole(address account) external view returns (bool);
    function getRoleLevel(address account) external view returns (uint256);
    function validatePermission(address account, uint256 requiredLevel) external view returns (bool);
    function hasRole(bytes32 role, address account) external view returns (bool);
    
    // 获取角色常量的函数
    function PRIMARY_BANK_ROLE() external pure returns (bytes32);
    function SECONDARY_BANK_ROLE() external pure returns (bytes32);
    function USER_ROLE() external pure returns (bytes32);
    function ENTERPRISE_ROLE() external pure returns (bytes32);
    function REGULATOR_ROLE() external pure returns (bytes32);
    function VALIDATOR_ROLE() external pure returns (bytes32);
}

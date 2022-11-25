// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract AccessControl {
    address private _admin;
    mapping(bytes32 => mapping(address => bool)) private _accesses;
    bool private _isDeprecated;

    event AdminChanged(address account);
    event RoleGranted(bytes32 indexed role, address account);
    event RoleRevoked(bytes32 indexed role, address account);
    event ContractDeprecated();

    modifier onlyAdmin() {
        require(msg.sender == _admin, "AccessControl: caller should be admin");
        _;
    }

    modifier onlyRole(bytes32 role) {
        require(
            _hasRole(role, msg.sender),
            "AccessControl: caller shoud have role"
        );
        _;
    }

    modifier notDeprecated() {
        require(!_isDeprecated, "AccessControl: contract is deprecated");
        _;
    }

    constructor() {
        _admin = msg.sender;
    }

    function changeAdmin(address account) external onlyAdmin {
        require(
            account != _admin,
            "AccessControl: new and old admins should be different"
        );
        _admin = account;
        emit AdminChanged(account);
    }

    function grantRole(bytes32 role, address account) external onlyAdmin {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) external onlyAdmin {
        _revokeRole(role, account);
    }

    function renounceRole(bytes32 role) external onlyRole(role) {
        _revokeRole(role, msg.sender);
    }

    function deprecateContract() external onlyAdmin notDeprecated {
        _isDeprecated = true;
        emit ContractDeprecated();
    }

    function admin() external view returns (address) {
        return _admin;
    }

    function hasRole(bytes32 role, address account)
        external
        view
        returns (bool)
    {
        return _hasRole(role, account);
    }

    function isDeprecated() external view returns (bool) {
        return _isDeprecated;
    }

    function _grantRole(bytes32 role, address account) internal {
        require(
            !_hasRole(role, account),
            "AccessControl: role is already granted"
        );
        _accesses[role][account] = true;
        emit RoleGranted(role, account);
    }

    function _revokeRole(bytes32 role, address account) internal {
        require(_accesses[role][account], "AccessControl: role is not granted");
        _accesses[role][account] = false;
        emit RoleRevoked(role, account);
    }

    function _hasRole(bytes32 role, address account)
        internal
        view
        returns (bool)
    {
        return _accesses[role][account];
    }
}

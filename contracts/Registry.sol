// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {AccessControl} from "./utils/AccessControl.sol";

contract Registry is AccessControl {
    mapping(bytes32 => bytes) private _fields;

    event FieldSet(bytes32 indexed key, bytes value);

    function setBatch(bytes32[] calldata keys, bytes[] calldata values)
        external
    {
        require(
            keys.length == values.length,
            "Registry: keys and values should have same length"
        );
        for (uint256 i = 0; i < keys.length; i++) {
            set(keys[i], values[i]);
        }
    }

    function get(bytes32 key) external view returns (bytes memory) {
        return _fields[key];
    }

    function set(bytes32 key, bytes calldata value) public onlyRole(key) {
        _fields[key] = value;
        emit FieldSet(key, value);
    }
}

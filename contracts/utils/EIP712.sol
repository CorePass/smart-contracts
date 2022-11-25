// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

abstract contract EIP712 {
    bytes32 private immutable _HASHED_TYPE;
    bytes32 private immutable _HASHED_NAME;
    bytes32 private immutable _HASHED_VERSION;
    uint256 private immutable _NETWORK_ID;
    bytes32 private immutable _DOMAIN_SEPARATOR;

    constructor(string memory name, string memory version) {
        bytes32 hashedType = keccak256(
            bytes(
                "EIP712Domain(string name,string version,uint256 networkId,address verifyingContract)"
            )
        );
        _HASHED_TYPE = hashedType;

        bytes32 hashedName = keccak256(bytes(name));
        _HASHED_NAME = hashedName;

        bytes32 hashedVersion = keccak256(bytes(version));
        _HASHED_VERSION = hashedVersion;

        _NETWORK_ID = block.chainid;

        _DOMAIN_SEPARATOR = _computeDomainSeparator(
            hashedType,
            hashedName,
            hashedVersion
        );
    }

    function _recoverTypedSignature(bytes32 messageHash, bytes memory signature)
        internal
        view
        returns (address)
    {
        require(
            signature.length == 171,
            "EIP712: signature length is incorrect"
        );

        bytes32 domainSeparator = _NETWORK_ID == block.chainid
            ? _DOMAIN_SEPARATOR
            : _computeDomainSeparator(
                _HASHED_TYPE,
                _HASHED_NAME,
                _HASHED_VERSION
            );

        bytes32 dataHash = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, messageHash)
        );

        return ecrecover(dataHash, signature);
    }

    function _computeDomainSeparator(
        bytes32 hashedType,
        bytes32 hashedName,
        bytes32 hashedVersion
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    hashedType,
                    hashedName,
                    hashedVersion,
                    block.chainid,
                    address(this)
                )
            );
    }
}

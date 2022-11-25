// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {EIP712} from "../utils/EIP712.sol";
import {BaseToken} from "./BaseToken.sol";
import {Caller} from "./Caller.sol";

struct Bounty {
    address owner;
    address target;
    bytes data;
    uint256 reward;
    uint256 nonce;
    uint256 deadline;
    uint256 energyLimit;
    bytes signature;
}

abstract contract BountiableToken is EIP712, BaseToken {
    bytes32 private immutable _HASHED_TYPE;
    mapping(address => uint256) private _nonces;

    Caller caller;

    event BountyCashed(
        address indexed owner,
        address indexed target,
        bytes data,
        uint256 reward,
        uint256 nonce,
        uint256 deadline,
        uint256 energyLimit,
        bool success
    );

    constructor() {
        _HASHED_TYPE = keccak256(
            bytes(
                "Bounty(address target,bytes data,uint256 reward,uint256 nonce,uint256 deadline,uint256 energyLimit)"
            )
        );
        caller = new Caller(address(this));
    }

    function bountyNonceOf(address account) external view returns (uint256) {
        return _nonces[account];
    }

    function cashBounty(Bounty[] calldata bounties) external {
        for (uint256 i = 0; i < bounties.length; i++) {
            Bounty calldata bounty = bounties[i];
            address owner = bounty.owner;
            uint256 reward = bounty.reward;
            if (_balanceOf(owner) < reward) {
                continue;
            }

            uint256 nonce = bounty.nonce;
            if (nonce != _nonces[owner]) {
                continue;
            }

            uint256 deadline = bounty.deadline;
            if (deadline < block.timestamp) {
                continue;
            }

            address target = bounty.target;
            bytes memory data = bounty.data;
            uint256 energyLimit = bounty.energyLimit;
            bytes32 bountyHash = _computeBountyHash(
                target,
                data,
                reward,
                nonce,
                deadline,
                energyLimit
            );
            if (owner != _recoverTypedSignature(bountyHash, bounty.signature)) {
                continue;
            }

            _nonces[owner] += 1;
            _transfer(owner, msg.sender, reward);
            bool success = caller.bountyCall(target, data, energyLimit);
            emit BountyCashed(
                owner,
                target,
                data,
                reward,
                nonce,
                deadline,
                energyLimit,
                success
            );
        }
    }

    function _computeBountyHash(
        address target,
        bytes memory data,
        uint256 reward,
        uint256 nonce,
        uint256 deadline,
        uint256 energyLimit
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    _HASHED_TYPE,
                    target,
                    keccak256(data),
                    reward,
                    nonce,
                    deadline,
                    energyLimit
                )
            );
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {EIP712} from "../utils/EIP712.sol";
import {BaseToken} from "./BaseToken.sol";

uint256 constant MAX_INT = 2**256 - 1;

struct Cheque {
    address owner;
    address spender;
    uint256 amount;
    uint256 nonce;
    uint256 deadline;
    bytes signature;
}

abstract contract ChequableToken is EIP712, BaseToken {
    bytes32 private immutable _HASHED_TYPE;
    mapping(address => mapping(uint256 => uint256)) private _nonces;

    event ChequeCash(
        address indexed owner,
        address indexed spender,
        uint256 amount,
        uint256 nonce,
        uint256 deadline
    );

    constructor() {
        _HASHED_TYPE = keccak256(
            bytes(
                "Cheque(address spender,uint256 amount,uint256 nonce,uint256 deadline)"
            )
        );
    }

    function firstChequeNonceOf(address account)
        external
        view
        returns (uint256)
    {
        uint256 index = 0;
        for (index; _nonces[account][index] == MAX_INT; index++) {}
        uint256 word = _nonces[account][index];
        uint256 reminder = 0;
        for (reminder; (word / 2**reminder) % 2 == 1; reminder++) {}
        return index * 256 + reminder;
    }

    function chequeNonceOf(address account, uint256 nonce)
        external
        view
        returns (bool)
    {
        uint256 index = nonce / 256;
        uint256 reminder = nonce % 256;
        uint256 power = 2**reminder;
        uint256 word = _nonces[account][index];
        return (word / power) % 2 == 0;
    }

    function cashCheque(Cheque calldata cheque) external {
        address owner = cheque.owner;
        address spender = cheque.spender;
        uint256 amount = cheque.amount;
        uint256 nonce = cheque.nonce;
        uint256 deadline = cheque.deadline;

        require(
            deadline >= block.timestamp,
            "ChequableToken: deadline is passed"
        );

        _useNonce(owner, nonce);

        bytes32 chequeHash = _computeChequeHash(
            spender,
            amount,
            nonce,
            deadline
        );
        require(
            owner == _recoverTypedSignature(chequeHash, cheque.signature),
            "ChequableToken: signature is invalid"
        );

        _approve(owner, spender, amount);
        emit ChequeCash(owner, spender, amount, nonce, deadline);
    }

    function _useNonce(address account, uint256 nonce) private {
        uint256 index = nonce / 256;
        uint256 reminder = nonce % 256;
        uint256 power = 2**reminder;
        uint256 word = _nonces[account][index];
        require((word / power) % 2 == 0, "ChequableToken: nonce is used");
        _nonces[account][index] = word | power;
    }

    function _computeChequeHash(
        address spender,
        uint256 amount,
        uint256 nonce,
        uint256 deadline
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(_HASHED_TYPE, spender, amount, nonce, deadline)
            );
    }
}

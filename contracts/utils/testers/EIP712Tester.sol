// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {EIP712} from "../EIP712.sol";

contract EIP712Tester is EIP712("EIP712Tester", "1") {
    struct Message {
        string text;
        uint256 number;
        address addr;
    }

    function recover(Message memory message, bytes memory signature)
        public
        view
        returns (address)
    {
        bytes32 hashedType = keccak256(
            bytes("Message(string text,uint256 number,address addr)")
        );
        bytes32 messageHash = keccak256(
            abi.encode(
                hashedType,
                keccak256(bytes(message.text)),
                message.number,
                message.addr
            )
        );

        return _recoverTypedSignature(messageHash, signature);
    }
}

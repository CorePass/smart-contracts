// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {EIP712} from "../../utils/EIP712.sol";
import {BaseToken} from "../BaseToken.sol";
import {ChequableToken} from "../ChequableToken.sol";

contract ChequableTokenTester is
    EIP712("ChequableTokenTester", "1"),
    BaseToken("ChequableTokenTester", "CTT", 18),
    ChequableToken
{}

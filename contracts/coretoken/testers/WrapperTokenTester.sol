// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "../ERC20.sol";
import {BaseToken} from "../BaseToken.sol";
import {WrapperToken} from "../WrapperToken.sol";

contract WrapperTokenTester is
    BaseToken("WrappedTokenTester", "WTT", 18),
    WrapperToken
{
    constructor(ERC20 wrappedToken) WrapperToken(wrappedToken) {}
}

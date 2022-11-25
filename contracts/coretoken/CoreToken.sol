// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {EIP712} from "../utils/EIP712.sol";
import {ERC20} from "./ERC20.sol";
import {PriceFeed} from "./PriceFeed.sol";
import {BaseToken} from "./BaseToken.sol";
import {WrapperToken} from "./WrapperToken.sol";
import {EquivalentToken} from "./EquivalentToken.sol";
import {ChequableToken} from "./ChequableToken.sol";
import {BountiableToken} from "./BountiableToken.sol";

contract CoreToken is
    EIP712("CoreToken", "1"),
    BaseToken("CoreToken", "CTN", 18),
    WrapperToken,
    EquivalentToken,
    ChequableToken,
    BountiableToken
{
    constructor(ERC20 wrappedToken, PriceFeed priceFeed)
        WrapperToken(wrappedToken)
        EquivalentToken(priceFeed)
    {}
}

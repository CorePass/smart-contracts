// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {PriceFeed} from "../PriceFeed.sol";
import {BaseToken} from "../BaseToken.sol";
import {EquivalentToken} from "../EquivalentToken.sol";

contract EquivalentTokenTester is
    BaseToken("EquivalentTokenTester", "ETT", 18),
    EquivalentToken
{
    constructor(PriceFeed _priceFeed) EquivalentToken(_priceFeed) {}

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseToken} from "./BaseToken.sol";
import {PriceFeed} from "./PriceFeed.sol";

abstract contract EquivalentToken is BaseToken {
    PriceFeed public immutable priceFeed;

    constructor(PriceFeed _priceFeed) {
        priceFeed = _priceFeed;
    }

    function equivalentValue() external view returns (uint256) {
        return _equivalent(1);
    }

    function transferEquivalent(address recipient, uint256 amount)
        external
        returns (bool)
    {
        uint256 equivalentAmount = _equivalent(amount);
        return transfer(recipient, equivalentAmount);
    }

    function approveEquivalent(address spender, uint256 amount)
        external
        returns (bool)
    {
        uint256 equivalentAmount = _equivalent(amount);
        return approve(spender, equivalentAmount);
    }

    function transferFromEquivalent(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        uint256 equivalentAmount = _equivalent(amount);
        return transferFrom(sender, recipient, equivalentAmount);
    }

    function _equivalent(uint256 amount) private view returns (uint256) {
        (, uint256 value, uint256 count) = priceFeed.getAggregatedPrice();
        require(count > 0, "EquivalentToken: unknown equivalent value");
        return (value * amount);
    }
}

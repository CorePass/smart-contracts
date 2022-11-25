// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {PriceFeed} from "./PriceFeed.sol";
import {AccessControl} from "../utils/AccessControl.sol";

contract FixedPriceFeed is PriceFeed, AccessControl {
    uint256 private price;

    event PriceChanged(uint256 price);

    constructor(uint256 _price) {
        price = _price;
    }

    function set(uint256 _price) external onlyRole(0) {
        price = _price;
        emit PriceChanged(_price);
    }

    function getAggregatedPrice()
        external
        view
        override
        returns (
            uint256,
            uint256,
            uint32
        )
    {
        return (block.timestamp, price, 1);
    }
}

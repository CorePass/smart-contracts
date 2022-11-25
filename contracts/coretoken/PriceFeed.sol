// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface PriceFeed {
    function getAggregatedPrice()
        external
        view
        returns (
            uint256,
            uint256,
            uint32
        );
}

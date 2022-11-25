// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseToken} from "./BaseToken.sol";

contract AssetToken is BaseToken("AssetToken", "AST", 18) {
    constructor() {
        _mint(msg.sender, 10**32);
    }
}

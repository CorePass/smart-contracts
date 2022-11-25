// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseToken} from "../BaseToken.sol";

contract BaseTokenTester is BaseToken {
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) BaseToken(name_, symbol_, decimals_) {}

    function internalMint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function internalBurn(address account, uint256 amount) public {
        _burn(account, amount);
    }

    function internalTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) public {
        _transfer(sender, recipient, amount);
    }

    function internalApprove(
        address owner,
        address spender,
        uint256 amount
    ) public {
        _approve(owner, spender, amount);
    }
}

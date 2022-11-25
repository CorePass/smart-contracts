// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "./ERC20.sol";
import {BaseToken} from "./BaseToken.sol";

abstract contract WrapperToken is BaseToken {
    ERC20 private immutable _WRAPPED_TOKEN;

    constructor(ERC20 wrappedToken_) {
        _WRAPPED_TOKEN = wrappedToken_;
    }

    function wrappedToken() external view returns (ERC20) {
        return _WRAPPED_TOKEN;
    }

    function buy(uint256 amount) external payable {
        _WRAPPED_TOKEN.transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
    }

    function sell(uint256 amount) external {
        _burn(msg.sender, amount);
        _WRAPPED_TOKEN.transfer(msg.sender, amount);
    }
}

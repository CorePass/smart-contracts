// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {EIP712} from "../../utils/EIP712.sol";
import {BaseToken} from "../BaseToken.sol";
import {BountiableToken} from "../BountiableToken.sol";

contract BountiableTokenTester is
    EIP712("BountiableTokenTester", "1"),
    BaseToken("BountiableTokenTester", "BTT", 18),
    BountiableToken
{
    uint256 public numCalls;

    function testSuccess() external {
        numCalls += 1;
    }

    function testFailure() external pure {
        require(false, "Opsss...");
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}

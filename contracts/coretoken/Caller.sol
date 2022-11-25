// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Caller {

    address tokenAddress;

    constructor(address tokenAddress_) {
        tokenAddress = tokenAddress_;
    }

    function bountyCall(address target, bytes memory data, uint256 energyLimit) external returns (bool) {
        require(msg.sender == tokenAddress);
        (bool success, ) = target.call{gas: energyLimit}(data);
        return success;
    }

}
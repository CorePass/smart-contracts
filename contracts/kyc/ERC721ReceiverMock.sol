// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC721Receiver} from "./IERC721Receiver.sol";

contract ERC721ReceiverMock is IERC721Receiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

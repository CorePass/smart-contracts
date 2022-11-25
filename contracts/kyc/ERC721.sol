// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC721} from "./IERC721.sol";
import {IERC721Receiver} from "./IERC721Receiver.sol";
import {IERC721Enumerable} from "./IERC721Enumerable.sol";

abstract contract ERC721 is IERC721, IERC721Enumerable {
    uint256 private _nextTokenId;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    function approve(address to, uint256 tokenId) external virtual override {
        address owner = _owners[tokenId];
        address sender = msg.sender;
        require(to != owner, "ERC721: approval to current owner");
        require(
            owner == sender || _operatorApprovals[owner][sender],
            "ERC721: approve caller is not owner nor approved for all"
        );

        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved)
        external
        virtual
        override
    {
        address owner = msg.sender;
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external virtual override {
        address owner = _owners[tokenId];
        address sender = msg.sender;
        require(owner == from, "ERC721: transfer from incorrect owner");
        require(
            owner == sender ||
                _operatorApprovals[owner][sender] ||
                _tokenApprovals[tokenId] == sender,
            "ERC721: transfer caller is not owner nor approved"
        );
        beforeTokenTransfer(tokenId);

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external virtual override {
        address owner = _owners[tokenId];
        address sender = msg.sender;
        require(owner == from, "ERC721: transfer from incorrect owner");
        require(
            owner == sender ||
                _operatorApprovals[owner][sender] ||
                _tokenApprovals[tokenId] == sender,
            "ERC721: transfer caller is not owner nor approved"
        );
        beforeTokenTransfer(tokenId);

        _transfer(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, ""),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) external virtual override {
        address owner = _owners[tokenId];
        address sender = msg.sender;
        require(owner == from, "ERC721: transfer from incorrect owner");
        require(
            owner == sender ||
                _operatorApprovals[owner][sender] ||
                _tokenApprovals[tokenId] == sender,
            "ERC721: transfer caller is not owner nor approved"
        );
        beforeTokenTransfer(tokenId);

        _transfer(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    function balanceOf(address owner)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId)
        public
        view
        virtual
        override
        returns (address)
    {
        address owner = _owners[tokenId];
        return owner;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _nextTokenId;
    }

    function tokenByIndex(uint256 index)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            index < _nextTokenId,
            "ERC721Enumerable: global index out of bounds"
        );
        return index;
    }

    function tokenOfOwnerByIndex(address owner, uint256 index)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            index < _balances[owner],
            "ERC721Enumerable: owner index out of bounds"
        );
        return _ownedTokens[owner][index];
    }

    function getApproved(uint256 tokenId)
        public
        view
        virtual
        override
        returns (address)
    {
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        override
        returns (bool)
    {
        return _operatorApprovals[owner][operator];
    }

    function beforeTokenTransfer(uint256 tokenId) internal view virtual {}

    function _mint(address owner) internal returns (uint256) {
        uint256 tokenId = _nextTokenId;
        _nextTokenId += 1;

        uint256 balance = _balances[owner];
        _balances[owner] = balance + 1;
        _ownedTokens[owner][balance] = tokenId;
        _owners[tokenId] = owner;

        return tokenId;
    }

    function _swapOwnerTokens(
        address owner,
        uint256 first,
        uint256 second
    ) internal {
        uint256 firstToken = _ownedTokens[owner][first];
        uint256 secondToken = _ownedTokens[owner][second];
        _ownedTokens[owner][first] = secondToken;
        _ownedTokens[owner][second] = firstToken;
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal {
        delete _tokenApprovals[tokenId];
        _owners[tokenId] = to;

        uint256 fromBalance = _balances[from] - 1;
        _balances[from] = fromBalance;
        for (uint256 i = 0; i < fromBalance; i++) {
            uint256 t = _ownedTokens[from][i];
            if (t == tokenId) {
                _ownedTokens[from][i] = _ownedTokens[from][fromBalance];
            }
        }
        delete _ownedTokens[from][fromBalance];

        uint256 toBalance = _balances[to];
        _ownedTokens[to][toBalance] = tokenId;
        _balances[to] = toBalance + 1;

        emit Transfer(from, to, tokenId);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.code.length > 0) {
            try
                IERC721Receiver(to).onERC721Received(
                    msg.sender,
                    from,
                    tokenId,
                    _data
                )
            returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721: transfer to non ERC721Receiver implementer"
                    );
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
}

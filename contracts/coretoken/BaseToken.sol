// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "./ERC20.sol";

abstract contract BaseToken is ERC20 {
    string private _name;
    string private _symbol;
    uint8 private immutable _DECIMALS;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Mint(address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) {
        _name = name_;
        _symbol = symbol_;
        _DECIMALS = decimals_;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external view returns (uint8) {
        return _DECIMALS;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account)
        external
        view
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function allowance(address owner, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function batchTransfer(
        address[] memory recipients,
        uint256[] memory amounts
    ) public override returns (bool) {
        require(
            recipients.length == amounts.length,
            "BaseToken: recipients and amounts should have same length"
        );

        for (uint256 i = 0; i < recipients.length; i++)
            _transfer(msg.sender, recipients[i], amounts[i]);

        return true;
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(
            currentAllowance >= amount,
            "BaseToken: transfer amount exceeds allowance"
        );

        uint256 newAllowance;
        unchecked {
            newAllowance = currentAllowance - amount;
        }

        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, newAllowance);
        return true;
    }

    function _mint(address account, uint256 amount) internal {
        _balances[account] += amount;
        _totalSupply += amount;

        emit Mint(account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        uint256 accountBalance = _balances[account];
        require(
            accountBalance >= amount,
            "BaseToken: burn amount exceeds balance"
        );

        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }

        emit Burn(account, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "BaseToken: transfer amount exceeds balance"
        );

        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _balanceOf(address account) internal view returns (uint256) {
        return _balances[account];
    }
}

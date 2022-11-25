// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Cheque} from "../coretoken/ChequableToken.sol";
import {CoreToken} from "../coretoken/CoreToken.sol";
import {EIP712} from "../utils/EIP712.sol";
import {AccessControl} from "../utils/AccessControl.sol";
import {ERC721} from "./ERC721.sol";
import {KYCVault, Info} from "./KYCVault.sol";

contract KYCVoucherer is EIP712, AccessControl, ERC721 {
    enum State {
        NotIssued,
        Issued,
        Verified,
        Rejected
    }

    bytes32 private constant _CONFIRM_HASH_TYPE =
        keccak256(bytes("Confirm(uint256 tokenId)"));

    bytes32 private constant _AUTHORIZE_HASH_TYPE =
        keccak256(
            bytes("Authorize(uint256 tokenId,address userId,uint256 deadline)")
        );

    CoreToken private _priceToken;
    uint256 private _priceAmount;
    KYCVault private _vault;
    bytes32 private _role;

    mapping(uint256 => State) private _states;

    event PriceChanged(CoreToken token, uint256 amount);
    event Issued(uint256 indexed tokenId, address indexed owner);
    event Verified(uint256 indexed tokenId, uint256 submission);
    event Rejected(uint256 indexed tokenId, string reason);

    constructor(
        CoreToken priceToken,
        uint256 priceAmount,
        KYCVault vault,
        bytes32 role,
        string memory name
    ) EIP712(name, "1") {
        _priceToken = priceToken;
        _priceAmount = priceAmount;
        _vault = vault;
        _role = role;
    }

    /**
    * @dev 
    */
    function price() external view returns (CoreToken, uint256) {
        return (_priceToken, _priceAmount);
    }

    function state(uint256 tokenId) public view returns (State) {
        return _states[tokenId];
    }

    /**
    * @dev Issues a Voucher if purchaser has signed cheque for at least priceAmount
    */
    function purchase(Cheque memory cheque) public notDeprecated {
        address purchaser_ = cheque.owner;
        _priceToken.cashCheque(cheque);
        _priceToken.transferFromEquivalent(
            purchaser_,
            address(this),
            _priceAmount
        );
        _issue(purchaser_);
    }

    /**
    * @dev Batch issues Vouchers for a list of purchasers
    */
    function batchPurchase(Cheque[] memory cheques) external notDeprecated {
        for (uint256 i = 0; i < cheques.length; i++) purchase(cheques[i]);
    }

    /**
    * @dev Changes token and/or price to purchase Voucher by Admin
    *
    * PLEASE WITHDRAW ALL THE TOKENS FROM CONTRACT BEFORE CHANGING PRICE TOKEN
    */
    function changePrice(CoreToken token, uint256 amount) external onlyAdmin {
        _priceToken = token;
        _priceAmount = amount;
        emit PriceChanged(token, amount);
    }

    /**
    * @dev Withdraws all the tokens from contract balance by Admin.
    *
    */
    function withdraw(address recipient) external onlyAdmin {
        uint256 balance = _priceToken.balanceOf(address(this));
        _priceToken.transfer(recipient, balance);
    }

    /**
    * @dev Issues a Voucher. Issuer must have role(0) priveledges.
    *
    */
    function issue(address purchaser_) external onlyRole(0) {
        _issue(purchaser_);
    }

    function batchIssue(address[] memory purchasers) external onlyRole(0) {
        for (uint256 i = 0; i < purchasers.length; i++) _issue(purchasers[i]);
    }

    /**
    * @dev Batch verifies data in KYCVault by the list of Voucher Owners. Verifier must have role(0) priveledges
    *
    * (!!!) Signature only approves that user allowed to use his Voucher, but doesnt indicates a correspondent data.
    */
    function verifyByConfirm(
        Info[] calldata infos,
        uint256[] calldata tokenIds,
        bytes[] calldata signatures
    ) external onlyRole(0) {
        require(
            infos.length == tokenIds.length,
            "KYCVoucherer: infos and tokenIds should have same length"
        );
        require(
            infos.length == signatures.length,
            "KYCVoucherer: infos and signatures should have same length"
        );

        address[] memory owners = new address[](tokenIds.length); // DONT NEED THIS ARRAY
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                _states[tokenIds[i]] == State.Issued,
                "KYCVoucherer: voucher state is not Issued"
            );
            bytes32 verifyHash = keccak256(
                abi.encode(_CONFIRM_HASH_TYPE, tokenIds[i])
            );
            address owner = ownerOf(tokenIds[i]);
            owners[i] = owner;
            address signer = _recoverTypedSignature(verifyHash, signatures[i]);
            require(
                owner == signer,
                "KYCVoucherer: confirm signature is invalid"
            );
        }
        _verify(infos, tokenIds);
    }

    /**
    * @dev Batch data verify in KYCVault by the list of Voucher Owners, or operators, or approved persons.
    *
    * Function verifies all the data or none.
    * Every signer must be the owner, operator or approved person of Voucher
    * After verification Vouchers are transferred to tos address
    */
    function verifyByAuthorization(
        Info[] calldata infos,
        uint256[] calldata tokenIds,
        address[] calldata tos,
        uint256[] calldata deadlines,
        bytes[] calldata signatures
    ) external onlyRole(0) {
        require(
            infos.length == tokenIds.length,
            "KYCVoucherer: infos and tokenIds should have same length"
        );
        require(
            infos.length == tos.length,
            "KYCVoucherer: infos and tos should have same length"
        );
        require(
            infos.length == deadlines.length,
            "KYCVoucherer: infos and deadlines should have same length"
        );
        require(
            infos.length == signatures.length,
            "KYCVoucherer: infos and signatures should have same length"
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                deadlines[i] >= block.timestamp,
                "KYCVoucherer: deadline has been passed"
            );
            require(
                _states[tokenIds[i]] == State.Issued, 
                "KYCVoucherer: voucher state is not Issued" // Maybe already verified
            );
            bytes32 verifyHash = keccak256(
                abi.encode(
                    _AUTHORIZE_HASH_TYPE,
                    tokenIds[i],
                    tos[i],
                    deadlines[i]
                )
            );
            address owner = ownerOf(tokenIds[i]);
            address signer = _recoverTypedSignature(verifyHash, signatures[i]);
            require(
                owner == signer ||
                    getApproved(tokenIds[i]) == signer ||
                    isApprovedForAll(owner, signer),
                "KYCVoucherer: authorizeSignature is invalid"
            );
            _transfer(owner, tos[i], tokenIds[i]);
        }
        _verify(infos, tokenIds);
    }

    /**
    * @dev Sets rejected status for a list of Vouchers with a reasons. Sender must have role(0) priveledges.
    *
    */

    function reject(uint256[] calldata tokenIds, string[] memory reasons)
        external
        onlyRole(0)
    {
        require(
            tokenIds.length == reasons.length,
            "KYCVoucherer: tokenIds and reasons should have same length"
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            State state_ = _states[tokenIds[i]];
            require(
                state_ != State.NotIssued,
                "KYCVoucherer: voucher is not issued"
            );
            _states[tokenIds[i]] = State.Rejected;
            emit Rejected(tokenIds[i], reasons[i]);
        }
    }

    function beforeTokenTransfer(uint256 tokenId) internal view override {
        require(
            _states[tokenId] == State.Issued,
            "VouchererVerifier: token state is not Issued"
        );
    }

    function _issue(address owner) private {
        uint256 tokenId = _mint(owner);
        _states[tokenId] = State.Issued;
        emit Issued(tokenId, owner);
    }

    /**
    * @dev Submits infos into the KYCVault contract
    *
    * Doesn't checks if identity of data owner is the same as owner of token. (TODO: Is that correct?)
    */
    function _verify(Info[] calldata infos, uint256[] calldata tokenIds)
        private
    {
        uint256[] memory submissions = _vault.submit(_role, infos);
        for (uint256 i = 0; i < submissions.length; i++) {
            _states[tokenIds[i]] = State.Verified;
            emit Verified(tokenIds[i], submissions[i]);
        }
    }
}

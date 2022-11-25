// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Cheque} from "../coretoken/ChequableToken.sol";
import {CoreToken} from "../coretoken/CoreToken.sol";
import {EIP712} from "../utils/EIP712.sol";
import {AccessControl} from "../utils/AccessControl.sol";
import {KYCVault} from "./KYCVault.sol";

contract KYCTransmitter is EIP712("KYCTransmitter", "1"), AccessControl {
    bytes32 private constant _PROVIDE_HASH_TYPE =
        keccak256(
            bytes(
                "Provide(address requester,uint256 nonce,uint256 deadline,bytes32[] fields)"
            )
        );
    bytes32 private constant _REQUEST_HASH_TYPE =
        keccak256(
            bytes(
                "Request(address provider,uint256 nonce,uint256 deadline,bytes32[] fields)"
            )
        );
    bytes32 private constant _CONFIRM_HASH_TYPE =
        keccak256(bytes("Confirm(bytes32 transmission)"));

    struct Request {
        Cheque providerCheque;
        Cheque requesterCheque;
        bytes providerSignature;
        bytes requesterSignature;
        bytes32[] fields;
    }

    address private corepassAddress;
    uint256 private corepassFee;
    KYCVault private _vault;
    CoreToken private _priceToken;
    mapping(bytes32 => uint256) private _priceAmounts;

    uint256 private _nextTransmission;
    mapping(bytes32 => address) private _transmissionProvider;
    mapping(bytes32 => address) private _transmissionRequester;
    mapping(bytes32 => CoreToken) private _transmissionToken;
    mapping(bytes32 => uint256) private _transmissionAmount;
    mapping(bytes32 => bytes32) private _transmissionInformation;

    event PriceTokenChanged(CoreToken token);
    event PriceAmountChanged(bytes32 indexed field, uint256 amount);
    event CorepassAddressChanged(address corepassAddress);
    event CorepassFeeChanged(uint256 fee);
    event Initiated(
        bytes32 indexed transmission,
        address indexed provider,
        address indexed requester,
        bytes32[] fields,
        uint256[] amounts
    );
    event Invalidated(bytes32 indexed transmission, uint256 index);
    event Confirmed(bytes32 indexed transmission);

    constructor(KYCVault vault, CoreToken priceToken_, address corepassAddress_, uint256 corepassFee_) {
        _vault = vault;
        _priceToken = priceToken_;
        corepassAddress = corepassAddress_;
        corepassFee = corepassFee_;
    }

    function getCorepassAddress() public view returns (address) {
        return corepassAddress;
    }

    function getCorepassFee() public view returns (uint256) {
        return corepassFee;
    }

    function priceToken() external view returns (CoreToken) {
        return _priceToken;
    }

    function priceAmount(bytes32 field) external view returns (uint256) {
        return _priceAmounts[field];
    }

    /**
    * @dev Function initiats data transfer.
    *
    * Creates Transmission Request from requester to provider on set of fields.
    * Transmission amount (TA) is calcualted from transmission prices for every field.
    * Provider pays TA, Requester pays 2*TA. This sum is locked on contract.
    */
    function initiate(
        Cheque memory providerCheque,
        Cheque memory requesterCheque,
        bytes memory providerSignature,
        bytes memory requesterSignature,
        bytes32[] memory fields
    ) public notDeprecated {
        uint256 numInformation = fields.length;
        uint256 equivalentValue = _priceToken.equivalentValue();
        uint256[] memory amounts = new uint256[](numInformation);
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < numInformation; i++) {
            uint256 amount = _priceAmounts[fields[i]];
            require(amount != 0, "KYCTransmitter: invalid field");
            amount *= equivalentValue;
            amounts[i] = amount;
            totalAmount += amount;
        }

        bytes32 fieldsHash = keccak256(abi.encodePacked(fields));

        bytes32 providerHash = keccak256(
            abi.encode(
                _PROVIDE_HASH_TYPE,
                requesterCheque.owner,
                providerCheque.nonce,
                providerCheque.deadline,
                fieldsHash
            )
        );
        require(
            providerCheque.owner ==
                _recoverTypedSignature(providerHash, providerSignature),
            "KYCTransmitter: providerSignature is invalid"
        );
        _priceToken.cashCheque(providerCheque);
        _priceToken.transferFrom(
            providerCheque.owner,
            address(this),
            totalAmount
        );

        bytes32 requesterHash = keccak256(
            abi.encode(
                _REQUEST_HASH_TYPE,
                providerCheque.owner,
                requesterCheque.nonce,
                requesterCheque.deadline,
                fieldsHash
            )
        );
        require(
            requesterCheque.owner ==
                _recoverTypedSignature(requesterHash, requesterSignature),
            "KYCTransmitter: requesterSignature is invalid"
        );
        _priceToken.cashCheque(requesterCheque);
        _priceToken.transferFrom(
            requesterCheque.owner,
            address(this),
            2 * totalAmount
        );

        bytes32 transmission = bytes32(_nextTransmission);
        _nextTransmission += 1;

        _transmissionProvider[transmission] = providerCheque.owner;
        _transmissionRequester[transmission] = requesterCheque.owner;
        _transmissionToken[transmission] = _priceToken;
        _transmissionAmount[transmission] = totalAmount;
        _transmissionInformation[transmission] = fieldsHash;
        emit Initiated(
            transmission,
            providerCheque.owner,
            requesterCheque.owner,
            fields,
            amounts
        );
    }

    /**
    * @dev Batch initiate data transfer.
    */

    function batchInitiate(Request[] memory list) external {
        for (uint i = 0; i < list.length; i++) {
            Cheque memory providerCheque = list[i].providerCheque;
            Cheque memory requesterCheque = list[i].requesterCheque;
            bytes memory providerSignature = list[i].providerSignature;
            bytes memory requesterSignature = list[i].requesterSignature;
            bytes32[] memory fields = list[i].fields;
            initiate(providerCheque, requesterCheque, providerSignature, requesterSignature, fields);
        }
    }

    /**
    * @dev Function invalidates data transfer if field with given index is not verified.
    *
    * Fields must be the same, as in Transmission.
    * TA returns to provider, 2*TA returns to requester.
    */
    function invalidate(
        bytes32 transmission,
        uint256 index,
        bytes32[] memory fields
    ) external {
        bytes32 fieldsHash = keccak256(abi.encodePacked(fields));
        require(
            _transmissionInformation[transmission] == fieldsHash,
            "KYCTransmitter: fields are incorrect"
        );
        require(index < fields.length, "KYCTransmitter: index is invalid");

        bytes32 field = fields[index];
        address provider = _transmissionProvider[transmission];
        bool isVerified = _vault.isVerified(provider, field);
        require(!isVerified, "KYCTransmitter: information is verified");

        address requester = _transmissionRequester[transmission];
        CoreToken token = _transmissionToken[transmission];
        uint256 amount = _transmissionAmount[transmission];
        token.transfer(provider, amount);
        token.transfer(requester, 2 * amount);

        _clearTransmission(transmission);
        emit Invalidated(transmission, index);
    }

    /**
    * @dev Function confirms that data transfer is finished and returns locked funds.
    *
    * Must be signed by Requester.
    * Returns 2*TA to provider, TA to requester (minus fee)
    */
    function confirm(bytes32 transmission, bytes memory signature) public {
        bytes32 confirmHash = keccak256(
            abi.encode(_CONFIRM_HASH_TYPE, transmission)
        );
        address requester = _transmissionRequester[transmission];
        require(
            requester == _recoverTypedSignature(confirmHash, signature),
            "KYCTransmitter: signature is invalid"
        );

        address provider = _transmissionProvider[transmission];
        CoreToken token = _transmissionToken[transmission];
        uint256 amount = _transmissionAmount[transmission];
        uint256 fee = (amount * corepassFee) / 20000;
        token.transfer(provider, 2 * amount - fee);
        token.transfer(requester, amount - fee);

        _clearTransmission(transmission);
        emit Confirmed(transmission);
    }

    /**
    * @dev Batch confirms several data transfers.
    */
    function batchConfirm(bytes32[] calldata transmissions, bytes[] calldata signatures) external {
        require(transmissions.length == signatures.length, 
            "KYCTransmitter: transmissions and signatures should have same length");
        for (uint i = 0; i < transmissions.length; i++) {
            bytes32 transmission = transmissions[i];
            bytes memory signature = signatures[i];
            confirm(transmission, signature);
        }
    }

    /**
    * @dev Changes price token. Could be called only by admin.
    */
    function changePriceToken(CoreToken token) external onlyAdmin {
        _priceToken = token;
        emit PriceTokenChanged(token);
    }

    /**
    * @dev Sets price amount for a field. Could be set only by admin.
    */
    function changePriceAmount(bytes32 field, uint256 amount)
        external
        onlyAdmin
    {
        _priceAmounts[field] = amount;
        emit PriceAmountChanged(field, amount);
    }

    /**
    * @dev Changes address for receiving Corepass Fee. Could be set only by admin.
    */
    function changeCorepassAddress(address corepassAddress_) external onlyAdmin {
        corepassAddress = corepassAddress_;
        emit CorepassAddressChanged(corepassAddress_);
    }

    /**
    * @dev Changes percent of Corepass Fee. Could be set only by admin.
    *
    * Corepass Fee is a percent with precicion of 2 decimals. I.e. 2.5% = 250
    */
    function changeCorepassFee(uint256 fee_) external onlyAdmin {
        corepassFee = fee_;
        emit CorepassFeeChanged(fee_);
    }

    function _clearTransmission(bytes32 transmission) private {
        delete _transmissionProvider[transmission];
        delete _transmissionRequester[transmission];
        delete _transmissionToken[transmission];
        delete _transmissionAmount[transmission];
        delete _transmissionInformation[transmission];
    }
}

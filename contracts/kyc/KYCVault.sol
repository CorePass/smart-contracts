// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {AccessControl} from "../utils/AccessControl.sol";
import {EIP712} from "../utils/EIP712.sol";

struct Field {
    bytes32 role;
    bool required;
    bool complete;
}

struct Submission {
    bytes32 role;
    uint256 expiration;
    address user;
    bool removed;
    bool invalidated;
}

struct Info {
    uint256 expiration;
    address user;
    bytes32[] fingerprints;
}

contract KYCVault is AccessControl, EIP712("KYCVault", "1") {
    bytes32 private constant _REMOVE_HASH_TYPE =
        keccak256(bytes("Remove(uint256 submission)"));

    uint256 private _nextSubmission;
    mapping(bytes32 => Field) private _fields;
    mapping(uint256 => Submission) private _submissions;
    mapping(address => mapping(uint256 => mapping(bytes32 => bytes32)))
        private _fingerprints;
    mapping(bytes32 => bytes32[]) private _roleFields;
    mapping(bytes32 => mapping(address => uint256[])) private _roleSubmissions;

    event Submitted(uint256 indexed submission, address indexed user);
    event Removed(uint256 indexed submission);
    event Invalidated(uint256 indexed submission, string reason);

    /**
    * @dev Marks a submission as "Removed"
    *
    * This function could be called by anyone. 
    * Signature must be signed by the data owner of this Submission.
    */
    function remove(uint256 submission_, bytes memory signature) external {
        bytes32 removeHash = keccak256(
            abi.encode(_REMOVE_HASH_TYPE, submission_)
        );
        address signer = _recoverTypedSignature(removeHash, signature);
        require(
            _submissions[submission_].user == signer,
            "KYCVault: signature is invalid"
        );

        _submissions[submission_].removed = true;
        emit Removed(submission_);
    }

    /**
    * @dev Batch marks submissions from the list as "Invalidated"
    *
    * This function must be called by account with role(0) priveledges.
    * Invalidation reason is recorded in the event.
    */
    function invalidate(
        uint256[] calldata submissions_,
        string[] calldata reasons
    ) external onlyRole(0) {
        for (uint256 i = 0; i < submissions_.length; i++) {
            _submissions[submissions_[i]].invalidated = true;
            emit Invalidated(submissions_[i], reasons[i]);
        }
    }

    /**
    * @dev Submits fingerprints for a given document and list of users into the database
    *
    * Sender must be a KYCVoucherer contract, desigened for this type of document, with the role set with grantRole().
    * This function creates one Submission for every user in the list (and his set of fingerprints).
    * Failing of one Submission results in overall fail of the call. So Submissions are set for all or for none.
    * Each Submission creates an event.
    */
    function submit(bytes32 role, Info[] calldata infos)
        external
        onlyRole(role)
        returns (uint256[] memory)
    {
        bytes32[] memory fields_ = _roleFields[role];
        uint256[] memory submissions_ = new uint256[](infos.length);
        for (uint256 i = 0; i < infos.length; i++) {
            Info calldata info = infos[i];
            require(
                fields_.length == info.fingerprints.length,
                "KYCVault: role fields and fingerprints should have same length"
            );
            uint256 currentSubmission = _nextSubmission++;
            _submissions[currentSubmission].role = role;
            _submissions[currentSubmission].expiration = info.expiration;
            _submissions[currentSubmission].user = info.user;
            submissions_[i] = currentSubmission;
            _roleSubmissions[role][info.user].push(currentSubmission);
            for (uint256 j = 0; j < fields_.length; j++) {
                require(
                    !_fields[fields_[j]].required || info.fingerprints[j] != 0,
                    "KYCVault: required field can not be zero"
                );
                _fingerprints[info.user][currentSubmission][fields_[j]] = info
                    .fingerprints[j];
            }
            emit Submitted(currentSubmission, info.user);
        }
        return submissions_;
    }

    /**
    * @dev Batch sets required/completed property for a number of fields.
    *
    * MUST be called after setRoleFields
    */
    function setFields(
        bytes32[] calldata fields_,
        bool[] calldata requireds,
        bool[] calldata completes
    ) external onlyAdmin {
        require(
            fields_.length == requireds.length,
            "KYCVault: fields_ and requireds should have same length"
        );
        require(
            fields_.length == completes.length,
            "KYCVault: fields_ and completes should have same length"
        );
        for (uint256 i = 0; i < fields_.length; i++) {
            _fields[fields_[i]].required = requireds[i];
            _fields[fields_[i]].complete = completes[i];
        }
    }

    /**
    * @dev Sets a list of fields for a new role, or modified existent list.
    *
    * One MUST call setFields for the list afterwards, to set required/completed fields.
    */
    function setRoleFields(bytes32 role, bytes32[] calldata fields_)
        external
        onlyAdmin
    {
        bytes32[] memory oldFields = _roleFields[role];
        for (uint256 i = 0; i < oldFields.length; i++) {
            _fields[oldFields[i]].role = 0;
        }
        for (uint256 i = 0; i < fields_.length; i++) {
            require(
                _fields[fields_[i]].role == 0,
                "KYCVault: fields_ should not have a diffrent role"
            );
            _fields[fields_[i]].role = role;
        }
        _roleFields[role] = fields_;
    }

    /**
    * @dev Returns iformation about the field: what role it belongs, required/completed status.
    *
    */
    function field(bytes32 field_) external view returns (Field memory) {
        return _fields[field_];
    }

    /**
    * @dev Returns details of the given submission.
    *
    */
    function submission(uint256 submission_)
        external
        view
        returns (Submission memory)
    {
        return _submissions[submission_];
    }

    /**
    * @dev Returns fingerprints of the given user, sent in submission with given number, for given field.
    *
    */
    function fingerprint(
        address user,
        bytes32 field_,
        uint256 submission_
    ) external view returns (bytes32) {
        return _fingerprints[user][submission_][field_];
    }

    /**
    * @dev Returns verified status of the given field for the given user
    *
    * Submission is PROPER, if it is not expired, removed or invalidated.
    * 
    * Field is verified if:
    * 1) The field is completed, and the LATEST Submission is PROPER and fingerprints for this field are non-zero. 
    * 2) The field is not completed, and AT LEAST one Submission is PROPER whith non-zero fingerprints. 
    */
    function isVerified(address user, bytes32 field_)
        external
        view
        returns (bool)
    {
        bool complete = _fields[field_].complete;
        bytes32 role = _fields[field_].role;
        uint256[] memory submissions_ = _roleSubmissions[role][user];
        for (uint256 i = submissions_.length; i > 0; i--) {
            Submission memory submission_ = _submissions[submissions_[i - 1]];
            if (
                (submission_.expiration != 0 &&
                    submission_.expiration <= block.timestamp) ||
                submission_.removed ||
                submission_.invalidated
            ) {
                if (complete) return false;
                continue;
            }

            bytes32 fing = _fingerprints[user][submissions_[i - 1]][field_];
            if (fing != 0) return true;
            if (complete) return false;
        }
        return false;
    }

    
    /**
    * @dev Returns valid status of the given field with given fingerprints for the given user
    *
    * Field is valid if:
    * 1) The field is completed, and the LATEST Submission is PROPER with correct fingerprints. 
    * 2) The field is not completed, and AT LEAST one Submission is PROPER with correct fingerprints. 
    */
    function isValid(
        address user,
        bytes32 field_,
        bytes32 fingerprint_
    ) external view returns (bool) {
        bool complete = _fields[field_].complete;
        bytes32 role = _fields[field_].role;
        uint256[] memory submissions_ = _roleSubmissions[role][user];
        for (uint256 i = submissions_.length; i > 0; i--) {
            Submission memory submission_ = _submissions[submissions_[i - 1]];
            if (
                (submission_.expiration != 0 &&
                    submission_.expiration <= block.timestamp) ||
                submission_.removed ||
                submission_.invalidated
            ) {
                if (complete) return false;
                continue;
            }

            bytes32 fing = _fingerprints[user][submissions_[i - 1]][field_];
            if (fing == fingerprint_) return true;
            if (complete) return false;
        }
        return false;
    }
}

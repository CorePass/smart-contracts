## CorePass Smart Contracts

Repository with CorePass Smart Contracts.

### Roles and Fields

A Role is an abstraction of a document. It is calculated as sha256 of the document name. The Role is a unique ID of a document.

Each document field also has a unique ID, calculated as sha3 of the string "SH_documentName_fieldName". So, different documents have different IDs for similar fields (phone number, etc).

A list of all fields, connected with the Role, is stored inside the KYCVault contract in the _roleFields mapping. This mapping doesn't have a public getter.

A list of all the field's parameters (parent role, required, and completed parameters) is stored inside the KYCVault contract in the _fields mapping. One could get this information about any field with the public function **field(bytes32 id)**.

To create a new role and connect a new list of fields to it, one must call **setRoleFields** function (only Admin). To rewrite an existing list, connected to an old role, one must call the same function. WARNING: it just sets a list of fields, connected to a role. To define the parameters of those fields, you should use **setFields**

To batch define or redefine required/completed parameters of fields, you should use **setFields**

#### Managing Roles

To add or modify a role one must:

1. call **setRoleFields** with the list of new fields, connected to this role (document)
1. call **setFields** with the list of all new fields for this role, alongside two boolean lists of required and completed parameters, corresponding to the new list of fields.
1. create a new KYCVoucherer for a new document, connected with this role. Call **grantRole(role, KYCVouchere.address)** in KYCVault, to get this Voucherer rights to submit.
1. in KYCVoucherer call **grantRole(0, accountAddress)** for the account, that will verify the data.

## License

Licensed under the [CORE License](LICENSE).

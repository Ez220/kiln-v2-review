// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: 2024 Kiln <contact@kiln.fi>
//
// ██╗  ██╗██╗██╗     ███╗   ██╗
// ██║ ██╔╝██║██║     ████╗  ██║
// █████╔╝ ██║██║     ██╔██╗ ██║
// ██╔═██╗ ██║██║     ██║╚██╗██║
// ██║  ██╗██║███████╗██║ ╚████║
// ╚═╝  ╚═╝╚═╝╚══════╝╚═╝  ╚═══╝
//
pragma solidity 0.8.20;

/// @title IAccountList
/// @notice A contract that manages the rights of accounts
/// @dev The rights are stored as a mapping of account address to rights
/// @dev The least significant bit is a flag indicating if the rights are set
/// @dev The remaining bits are the rights, stored on a uint248
/// @dev The rights value is padded with 1 to the left
/// @dev Includes utility to verify EIP712 signatures
interface IAccountList {
    /// @notice Emitted when the default rights are set
    /// @param rights The new default rights
    event SetDefaultRights(uint256 rights);

    /// @notice Emitted when the rights of an account are updated
    /// @param account The account whose rights were updated
    /// @param rights The new rights of the account
    /// @param signer The account that signed the authorization
    event UpdatedAccountRights(address account, uint256 rights, address signer);

    /// @notice Emitted when the rights of an account are cleared
    /// @param account The account whose rights were cleared
    /// @param signer The account that signed the authorization
    event ClearedAccountRights(address account, address signer);

    /// @notice Thrown when the expiration of an authorization has passed
    /// @param expiration The expiration of the authorization
    /// @param blockTimestamp The current block timestamp
    error AuthorizationExpired(uint256 expiration, uint256 blockTimestamp);

    /// @notice Thrown when the signature of an authorization is invalid
    /// @param rights The rights that were being applied
    /// @param account The account that was being updated
    /// @param expiration The expiration of the authorization
    /// @param nonce The nonce of the authorization
    /// @param v The recovery id of the signature
    /// @param r The r component of the signature
    /// @param s The s component of the signature
    error InvalidSignature(uint248 rights, address account, uint256 expiration, uint256 nonce, uint8 v, bytes32 r, bytes32 s);

    /// @notice Thrown when the the s component of the signature is invalid
    /// @param s The s component of the signature
    error InvalidSignatureS(bytes32 s);

    /// @notice Thrown when the the v component of the signature is invalid
    /// @param v The v component of the signature
    error InvalidSignatureV(uint8 v);

    /// @notice Thrown when the rights value is invalid
    /// @param rights The rights value that was invalid
    error InvalidRightsValue(uint256 rights);

    /// @notice Thrown when the nonce is invalid
    /// @param nonce The nonce that was provided
    /// @param expectedNonce The expected minimum nonce
    error InvalidNonce(uint256 nonce, uint256 expectedNonce);

    /// @notice Thrown when the account does not have the required authorizations
    /// @param rights The rights of the account
    /// @param expectedRights The rights that were required
    /// @param account The account that was missing the required authorizations
    error MissingAuthorizations(uint248 rights, uint248 expectedRights, address account);

    /// @notice Thrown when the account is forbidden
    /// @param account The account that is forbidden
    error Forbidden(address account);

    /// @notice Retrieves the computed rights of an account
    /// @dev This method won't be able to tell whether the rights are the default rights or not
    /// @param account The account whose rights to retrieve
    /// @return The rights of the account
    function accountRights(address account) external view returns (uint248);

    /// @notice Retrieves the raw rights of an account
    /// @dev This method will return the rights as they are stored in the contract
    /// @param account The account whose rights to retrieve
    /// @return The raw rights of the account
    function accountRawRights(address account) external view returns (uint256);

    /// @notice Get the nonce of an account
    /// @param account The account whose nonce to retrieve
    /// @return The nonce of the account
    function accountNonce(address account) external view returns (uint256);
}

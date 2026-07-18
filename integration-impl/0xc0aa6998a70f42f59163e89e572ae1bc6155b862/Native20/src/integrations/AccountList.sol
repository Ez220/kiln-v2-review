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

import {IAccountList} from "@src/interfaces/integrations/IAccountList.sol";
import {SafeCast} from "@dependency/openzeppelin-contracts/utils/math/SafeCast.sol";

import {types} from "@src/utils/types/types.sol";
import {LUint256} from "@src/utils/types/uint256.sol";
import {LMapping} from "@src/utils/types/mapping.sol";
import {CAddress} from "@src/utils/types/address.sol";

/// @title AccountList
/// @notice A contract that manages the rights of accounts
/// @dev The rights are stored as a mapping of account address to rights
/// @dev The least significant bit is a flag indicating if the rights are set
/// @dev The remaining bits are the rights, stored on a uint248
/// @dev The rights value is padded with 1 to the left
/// @dev Includes utility to verify EIP712 signatures
abstract contract AccountList is IAccountList {
    using LUint256 for types.Uint256;
    using LMapping for types.Mapping;

    using CAddress for address;

    using SafeCast for uint256;
    using SafeCast for int256;

    /// @dev The default rights that accounts have
    /// @dev Slot: keccak256(bytes("accountList.1.defaultRights")) - 1
    types.Uint256 internal constant $defaultRights = types.Uint256.wrap(0xff5e02e90d325706e6de17669aae88a35d626968024c3c331743d760a8fa4e76);

    /// @dev The rights of each account
    /// @dev Slot: keccak256(bytes("accountList.1.rights")) - 1
    /// @dev Mapping: address => uint256
    types.Mapping internal constant $rights = types.Mapping.wrap(0xada16803d547c21843051207ed5d3613c9b049bc5cfaab4f2702a4950cd76527);

    /// @dev The nonce of each account
    /// @dev Slot: keccak256(bytes("accountList.1.nonces")) - 1
    /// @dev Mapping: address => uint256
    types.Mapping internal constant $nonces = types.Mapping.wrap(0x0c587d8ee64af0684d06ddc50d5b1583b989cb26563ef92379d6eaf2d0ee2f2d);

    /// @notice Retrieves the computed rights of an account
    /// @dev This method won't be able to tell whether the rights are the default rights or not
    /// @param account The account whose rights to retrieve
    /// @return The rights of the account
    function accountRights(address account) external view returns (uint248) {
        return _getRights(account);
    }

    /// @notice Retrieves the raw rights of an account
    /// @dev This method will return the rights as they are stored in the contract
    /// @param account The account whose rights to retrieve
    /// @return The raw rights of the account
    function accountRawRights(address account) external view returns (uint256) {
        return _getRawRights(account);
    }

    /// @notice Get the nonce of an account
    /// @dev Returns the minimal nonce that can be used for an authorization
    /// @param account The account whose nonce to retrieve
    /// @return The nonce of the account
    function accountNonce(address account) external view returns (uint256) {
        return $nonces.get()[account.k()];
    }

    /// @notice Initializes the account list with the default rights
    /// @param defaultRights The default rights to set
    function _initAccountList(uint248 defaultRights) internal {
        _setDefaultRights(defaultRights);
    }

    /// @notice Sets the default rights of the account list
    /// @param rights The new default rights
    function _setDefaultRights(uint248 rights) internal {
        $defaultRights.set(rights);
        emit SetDefaultRights(rights);
    }

    /// @notice Applies rights to an account
    /// @param rights The rights to apply
    /// @param account The account to apply the rights to
    /// @param signer The signer of the authorization
    function _applyRights(uint248 rights, address account, address signer) internal {
        uint256 rightsValue = (uint256(rights) << 1) + 1;
        $rights.get()[account.k()] = rightsValue;
        emit UpdatedAccountRights(account, rights, signer);
    }

    /// @notice Clears the rights of an account
    /// @param account The account whose rights to clear
    /// @param signer The signer of the authorization
    function _clearRights(address account, address signer) internal {
        $rights.get()[account.k()] = 0;
        emit ClearedAccountRights(account, signer);
    }

    /// @notice Verifies the authorization signature of an account
    /// @dev This expects and EIP712 signature, and returns the address that signed the authorization
    /// @dev Reverts if the signature expired
    /// @dev Reverts if the signature is invalid and ecrecover returns address(0)
    /// @param rights The rights that were being applied
    /// @param account The account that was being updated
    /// @param expiration The expiration of the authorization
    /// @param nonce The nonce of the authorization
    /// @param v The recovery id of the signature
    /// @param r The r component of the signature
    /// @param s The s component of the signature
    /// @return The address that signed the authorization
    function _verifyApplyRightsAuthorization(
        uint248 rights,
        address account,
        uint256 expiration,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal returns (address) {
        if (block.timestamp > expiration) {
            revert AuthorizationExpired(expiration, block.timestamp);
        }

        if ($nonces.get()[account.k()] != nonce) {
            revert InvalidNonce(nonce, $nonces.get()[account.k()]);
        }

        $nonces.get()[account.k()] += 1;

        uint256 chainId = block.chainid;

        bytes32 eip712DomainHash = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("AccountList")),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );

        bytes32 hashStruct = keccak256(
            abi.encode(
                keccak256("ApplyRights(uint248 rights,address account,uint256 expiration,uint256 nonce)"),
                rights,
                account,
                expiration,
                nonce
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", eip712DomainHash, hashStruct));

        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            revert InvalidSignature(rights, account, expiration, nonce, v, r, s);
        }

        return signer;
    }

    /// @notice Increments the nonce of an account
    /// @param account The account whose nonce to increment
    function _incrementNonce(address account) internal {
        $nonces.get()[account.k()]++;
    }

    /// @notice Retrieves the rights of an account
    /// @param account The account whose rights to retrieve
    /// @return The rights of the account
    function _getRights(address account) internal view returns (uint248) {
        uint256 rights = _getRawRights(account);
        if (rights & 1 == 0) {
            return $defaultRights.get().toUint248();
        }
        return (rights >> 1).toUint248();
    }

    /// @notice Retrieves the raw rights of an account
    /// @param account The account whose rights to retrieve
    /// @return The raw rights of the account
    function _getRawRights(address account) internal view returns (uint256) {
        return $rights.get()[account.k()];
    }

    /// @notice Checks if an account has the required rights and is not forbidden
    /// @dev It's up to the caller to provide the forbidden mask and the required rights
    /// @dev Reverts with the appropriate error if the account is forbidden or does not have the required rights
    /// @param forbiddenRights The rights that are forbidden, used as a bit mask
    /// @param requiredRights The rights that are required, used as a bit mask
    /// @param account The account to check
    function _checkNotForbiddenAndAuthorizations(uint256 forbiddenRights, uint256 requiredRights, address account) internal view {
        uint256 _accountRights = _getRights(account);
        if (_accountRights & forbiddenRights == forbiddenRights) {
            revert Forbidden(account);
        }
        if (_accountRights & requiredRights != requiredRights) {
            revert MissingAuthorizations(_accountRights.toUint248(), requiredRights.toUint248(), account);
        }
    }
}

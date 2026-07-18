// SPDX-License-Identifier: MIT
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

import {IMultiPool20} from "./IMultiPool20.sol";

/// @notice Configuration parameters for the Native20 contract.
/// @param admin The address of the admin.
/// @param name ERC-20 style display name.
/// @param symbol ERC-20 style display symbol.
/// @param pools List of pool addresses.
/// @param poolFees List of fee for each pool, in basis points.
/// @param commissionRecipients List of recipients among which the withdrawn fees are shared.
/// @param commissionDistribution Share of each fee recipient, in basis points, must add up to 10 000.
/// @param poolPercentages The amount of ETH to route to each pool when staking, in basis points, must add up to 10 000.
/// @param maxCommissionBps The maximum commission in basis points.
/// @param monoTicketThreshold The minimum amount of ETH to stake in order to receive a mono-ticket.
/// @param defaultRights The default rights for all the accounts.
/// @param authorizer The address of the authorizer.
struct Native20Configuration {
    string name;
    string symbol;
    address admin;
    address[] pools;
    uint256[] poolFees;
    address[] commissionRecipients;
    uint256[] commissionDistribution;
    uint256[] poolPercentages;
    uint256 maxCommissionBps;
    uint256 monoTicketThreshold;
    uint248 defaultRights;
    address authorizer;
}

/// @title Native20 (V1) Interface
/// @author 0xvv @ Kiln
/// @notice This contract allows users to stake any amount of ETH in the vPool(s).
///         Users are given a soulbound ERC-20 token to track their stake.
interface INative20 is IMultiPool20 {
    /// @notice Initializes the contract with the given parameters.
    /// @param args The initialization arguments.
    function initialize(Native20Configuration calldata args) external;

    /// @notice Function to stake ETH.
    function stake() external payable;

    /// @notice Function to stake ETH on behalf of another account.
    /// @param account The address of the account to stake for.
    function stakeFor(address account) external payable;

    /// @notice Function to authorize and stake ETH.
    /// @dev Takes an EIP712 signature as input
    /// @dev Allows atomic authorize + stake
    /// @param rights The rights to authorize.
    /// @param expiration The expiration of the authorization.
    /// @param nonce The nonce of the authorization.
    /// @param v The recovery id of the signature.
    /// @param r The r component of the signature.
    /// @param s The s component of the signature.
    function authorizeAndStake(uint248 rights, uint256 expiration, uint256 nonce, uint8 v, bytes32 r, bytes32 s) external payable;

    /// @notice Returns the name of the token.
    function name() external view returns (string memory);

    /// @notice Returns the symbol of the token, usually a shorter version of the name.
    function symbol() external view returns (string memory);

    /// @notice Returns the number of decimals used to get its user representation.
    function decimals() external view returns (uint8);

    /// @notice Returns the total amount of tokens.
    /// @return Total amount of tokens.
    function totalSupply() external view returns (uint256);

    /// @notice Returns the amount of ETH owned by the users in the pool(s).
    /// @return ETH value of the pool shares owned by the users.
    function totalUnderlyingSupply() external view returns (uint256);

    /// @notice Returns the amount of token owned by an account.
    /// @param account The address of the account.
    /// @return amount of tokens.
    function balanceOf(address account) external view returns (uint256);

    /// @notice Returns the ETH value of the account balance.
    /// @param account The address of the account.
    /// @return amount of ETH.
    function balanceOfUnderlying(address account) external view returns (uint256);
}

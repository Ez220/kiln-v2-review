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

import {IMultiPool} from "./IMultiPool.sol";

/// @title MultiPool-20 (V1) Interface
/// @author 0xvv @ Kiln
/// @notice This contract contains the internal logic for an ERC-20 token based on one or multiple pools.
interface IMultiPool20 is IMultiPool {
    /// @notice Emitted when tokens are transferred.
    /// @param from The address sending the tokens
    /// @param to The address receiving the tokens
    /// @param value The transfer amount
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Emitted when an allowance is created.
    /// @param owner The owner of the shares
    /// @param spender The address that can spend
    /// @param value The allowance amount
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice Emitted when some integrator shares are sold
    /// @param pSharesSold amount of pool shares sold
    /// @param id Id of the pool
    /// @param amountSold ETH value of pool shares sold
    event CommissionSharesSold(uint256 pSharesSold, uint256 id, uint256 amountSold);

    /// @notice Emitted when new split is set.
    /// @param split Array of value in basis points to route to each pool
    event SetPoolPercentages(uint256[] split);

    /// @notice Emmited when sanctions are activated or deactivated
    /// @param active true if sanction should be checked, false otherwise
    event SanctionsActivationChanged(bool active);

    /// @notice Error emitted when the given address is on the sanction list.
    /// @param user The address that is on the sanction list.
    error AddressSanctioned(address user);

    /// @notice Thrown when a transfer is attempted but the sender does not have enough balance.
    /// @param amount The token amount.
    /// @param balance The balance of user.
    error InsufficientBalance(uint256 amount, uint256 balance);

    /// @notice Thrown when a transferFrom is attempted but the spender does not have enough allowance.
    error InsufficientAllowance(uint256 amount, uint256 allowance);

    /// @notice Thrown when trying to set a pool percentage != 0 to a deactivated pool
    error NonZeroPercentageOnDeactivatedPool(uint256 id);

    /// @notice Set the percentage of new stakes to route to each pool
    /// @notice If a pool is disabled it needs to be set to 0 in the array
    /// @param split Array of values in basis points to route to each pool
    function setPoolPercentages(uint256[] calldata split) external;

    /// @notice Burns the sender's tokens and mints the exitQueue tickets to the caller.
    /// @param amount Amount of tokens to send to the exit queue
    function requestExit(uint256 amount) external;

    /// @notice Allows the integrator to set the sanctions activation.
    /// @param active Whether the sanctions list should be checked or not.
    function setSanctionsActivation(bool active) external;

    /// @notice Returns the share to ETH conversion rate
    /// @return ETH value of a share
    function rate() external returns (uint256);

    /// @notice Allows the integrator to prevent users from depositing to a vPool.
    /// @param poolId The id of the vPool.
    /// @param status Whether the users can deposit to the pool.
    /// @param newPoolPercentages Array of value in basis points to route to each pool after the change
    function setPoolActivation(uint256 poolId, bool status, uint256[] calldata newPoolPercentages) external;

    /// @notice Allows the integrator to prevent users from using the contract
    /// @dev If the user has any balance, it will be sent to the exit queue automatically
    /// @dev The user won't be allowed to stake, requestExit, or transfer anymore
    /// @param account The account to forbid
    function forbid(address account) external;

    /// @notice Returns true if the sanctions list is active, false otherwise
    /// @return Whether the sanctions list is active or not
    function isSanctionsListActive() external view returns (bool);
}

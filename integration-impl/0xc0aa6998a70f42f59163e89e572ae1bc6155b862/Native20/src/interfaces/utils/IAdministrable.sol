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

/// @title Administrable Interface
/// @author mortimr @ Kiln
/// @dev Unstructured Storage Friendly
/// @notice This contract provides all the utilities to handle the administration and its transfer.
interface IAdministrable {
    /// @notice The admin address has been changed.
    /// @param admin The new admin address
    event SetAdmin(address admin);

    /// @notice The pending admin address has been changed.
    /// @param pendingAdmin The pending admin has been changed
    event SetPendingAdmin(address pendingAdmin);

    /// @notice Propose a new admin.
    /// @dev Only callable by the admin
    /// @param _newAdmin The new admin to propose
    function transferAdmin(address _newAdmin) external;

    /// @notice Accept an admin transfer.
    /// @dev Only callable by the pending admin
    function acceptAdmin() external;

    /// @notice Retrieve the admin address.
    /// @return adminAddress The admin address
    function admin() external view returns (address adminAddress);

    /// @notice Retrieve the pending admin address.
    /// @return pendingAdminAddress The pending admin address
    function pendingAdmin() external view returns (address pendingAdminAddress);
}

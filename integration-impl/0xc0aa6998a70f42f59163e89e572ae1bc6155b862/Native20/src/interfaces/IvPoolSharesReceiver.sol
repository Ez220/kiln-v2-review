// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2023 Kiln <contact@kiln.fi>
//
// ██╗  ██╗██╗██╗     ███╗   ██╗
// ██║ ██╔╝██║██║     ████╗  ██║
// █████╔╝ ██║██║     ██╔██╗ ██║
// ██╔═██╗ ██║██║     ██║╚██╗██║
// ██║  ██╗██║███████╗██║ ╚████║
// ╚═╝  ╚═╝╚═╝╚══════╝╚═╝  ╚═══╝
//
pragma solidity 0.8.20;

/// @title Pool Shares Receiver Interface
/// @author mortimr @ Kiln
/// @notice Interface that needs to be implemented for a contract to be able to receive shares
interface IvPoolSharesReceiver {
    /// @notice Callback used by the vPool to notify contracts of shares being transfered
    /// @param operator The address of the operator of the transfer
    /// @param from The address sending the funds
    /// @param amount The amount of shares received
    /// @param data The attached data
    /// @return selector Should return its own selector if everything went well
    function onvPoolSharesReceived(address operator, address from, uint256 amount, bytes memory data) external returns (bytes4 selector);
}

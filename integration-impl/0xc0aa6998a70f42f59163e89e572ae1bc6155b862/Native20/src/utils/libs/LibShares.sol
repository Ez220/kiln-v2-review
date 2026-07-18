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

import {LibUint256} from "@src/utils/libs/LibUint256.sol";

library LibShares {
    /// @dev Computes the amount of shares to mint for a specific deposit amount in the underlying supply
    /// @param depositAmount The amount of the underlying asset to deposit
    /// @param totalSupply The total supply of shares
    /// @param totalUnderlyingSupply The total supply of the underlying asset
    /// @return The amount of shares to mint
    function previewDeposit(uint256 depositAmount, uint256 totalSupply, uint256 totalUnderlyingSupply) internal pure returns (uint256) {
        return LibUint256.mulDivFloor(depositAmount, totalSupply, totalUnderlyingSupply);
    }

    /// @dev Computes the amount of underlying asset to provide to mint a specific amount of shares
    /// @param mintAmount The amount of shares to mint
    /// @param totalSupply The total supply of shares
    /// @param totalUnderlyingSupply The total supply of the underlying asset
    /// @return The amount of the underlying asset to provide
    function previewMint(uint256 mintAmount, uint256 totalSupply, uint256 totalUnderlyingSupply) internal pure returns (uint256) {
        return LibUint256.mulDivCeil(mintAmount, totalUnderlyingSupply, totalSupply);
    }

    /// @dev Computes the amount of underlying asset to give when providing a specific amount of shares back to the system
    /// @param redeemAmount The amount of shares to redeem
    /// @param totalSupply The total supply of shares
    /// @param totalUnderlyingSupply The total supply of the underlying asset
    /// @return The amount of the underlying asset to give to the user
    function previewRedeem(uint256 redeemAmount, uint256 totalSupply, uint256 totalUnderlyingSupply) internal pure returns (uint256) {
        return LibUint256.mulDivFloor(redeemAmount, totalUnderlyingSupply, totalSupply);
    }

    /// @dev Computes the amount of shares that needs to be provided for a specific amount of the underlying asset to be withdrawn
    /// @param withdrawAmount The amount of the underlying asset to withdraw
    /// @param totalSupply The total supply of shares
    /// @param totalUnderlyingSupply The total supply of the underlying asset
    /// @return The amount of shares the user needs to provide
    function previewWithdraw(uint256 withdrawAmount, uint256 totalSupply, uint256 totalUnderlyingSupply) internal pure returns (uint256) {
        return LibUint256.mulDivCeil(withdrawAmount, totalSupply, totalUnderlyingSupply);
    }

    /// @dev Computes the conversion rate of the shares
    /// @param totalSupply The total supply of shares
    /// @param totalUnderlyingSupply The total supply of the underlying asset
    /// @return The conversion rate
    function rate(uint256 totalSupply, uint256 totalUnderlyingSupply) internal pure returns (uint256) {
        if (totalSupply == 0) {
            return 1e18;
        }
        return LibUint256.mulDivFloor(totalUnderlyingSupply, 1e18, totalSupply);
    }
}

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

import {LibSanitize} from "@src/utils/libs/LibSanitize.sol";
import {LibConstant} from "@src/utils/libs/LibConstant.sol";
import {LibErrors} from "@src/utils/libs/LibErrors.sol";
import {LibUint256} from "@src/utils/libs/LibUint256.sol";

library LibBasisPoints {
    /// @dev Computes an amount based on a basis points value.
    /// @param amount The amount to compute.
    /// @param basisPoints The basis points to apply to the amount.
    /// @return The computed amount.
    function compute(uint256 amount, uint256 basisPoints) internal pure returns (uint256) {
        return LibUint256.mulDivFloor(amount, basisPoints, LibConstant.BASIS_POINTS_MAX);
    }

    /// @dev Checks if the basis points value is valid.
    /// @dev Reverts if the basis points value is invalid.
    /// @param basisPoints The basis points value to check.
    function check(uint256 basisPoints) internal pure {
        LibSanitize.notInvalidBps(basisPoints);
    }

    /// @dev Checks if the basis points sum is valid.
    /// @dev Reverts if the basis points sum is not equal to the maximum basis points value.
    /// @param basisPointsSum The basis points sum to check.
    function checkTotal(uint256 basisPointsSum) internal pure {
        if (basisPointsSum != LibConstant.BASIS_POINTS_MAX) {
            revert LibErrors.InvalidBPSSum(basisPointsSum, LibConstant.BASIS_POINTS_MAX);
        }
    }

    /// @dev Checks if the basis points value is valid with a custom maximum.
    /// @dev Reverts if the basis points value is invalid.
    /// @param basisPoints The basis points value to check.
    /// @param maximum The maximum basis points value.
    function checkWithMaximum(uint256 basisPoints, uint256 maximum) internal pure {
        LibSanitize.notInvalidBpsWithMaximum(basisPoints, maximum);
    }
}

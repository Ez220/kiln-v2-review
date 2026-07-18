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

import {LibErrors} from "@src/utils/libs/LibErrors.sol";
import {LibConstant} from "@src/utils/libs/LibConstant.sol";

/// @title Lib Sanitize
/// @dev This library helps sanitizing inputs.
library LibSanitize {
    /// @dev Internal utility to sanitize an address and ensure its value is not 0.
    /// @param addressValue The address to verify
    // slither-disable-next-line dead-code
    function notZeroAddress(address addressValue) internal pure {
        if (addressValue == address(0)) {
            revert LibErrors.InvalidZeroAddress();
        }
    }

    /// @dev Internal utility to sanitize an uint256 value and ensure its value is not 0.
    /// @param value The value to verify
    // slither-disable-next-line dead-code
    function notNullValue(uint256 value) internal pure {
        if (value == 0) {
            revert LibErrors.InvalidNullValue();
        }
    }

    /// @dev Internal utility to verify that the length of an array is not 0.
    /// @param value The length to verify
    // slither-disable-next-line dead-code
    function notEmptyArray(uint256 value) internal pure {
        if (value == 0) {
            revert LibErrors.InvalidEmptyArray();
        }
    }

    /// @dev Internal utility to sanitize a bps value and ensure it's <= 100%.
    /// @param value The bps value to verify
    // slither-disable-next-line dead-code
    function notInvalidBps(uint256 value) internal pure {
        notInvalidBpsWithMaximum(value, LibConstant.BASIS_POINTS_MAX);
    }

    /// @dev Internal utility to sanitize a bps value and ensure it's <= 100%.
    /// @param value The bps value to verify
    // slither-disable-next-line dead-code
    function notInvalidBpsWithMaximum(uint256 value, uint256 maximum) internal pure {
        if (value > maximum) {
            revert LibErrors.InvalidBPSValue(value, maximum);
        }
    }

    /// @dev Internal utility to sanitize a string value and ensure it's not empty.
    /// @param stringValue The string value to verify
    // slither-disable-next-line dead-code
    function notEmptyString(string memory stringValue) internal pure {
        if (bytes(stringValue).length == 0) {
            revert LibErrors.InvalidEmptyString();
        }
    }
}

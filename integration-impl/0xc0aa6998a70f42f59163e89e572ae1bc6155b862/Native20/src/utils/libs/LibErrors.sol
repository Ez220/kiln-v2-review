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

library LibErrors {
    error Unauthorized(address account, address expected);
    error InvalidZeroAddress();
    error InvalidNullValue();
    error InvalidMessageValue();
    error InvalidBPSValue(uint256 value, uint256 maximum);
    error InvalidBPSSum(uint256 sumValue, uint256 expectedSum);
    error InvalidEmptyString();
    error InvalidEmptyArray();
    error TransferFailed(address recipient, uint256 amount);
}

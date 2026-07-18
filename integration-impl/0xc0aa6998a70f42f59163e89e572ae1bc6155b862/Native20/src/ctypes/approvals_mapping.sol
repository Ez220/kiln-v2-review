// SPDX-License-Identifier: BUSL-1.1
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

import "./ctypes.sol";

/// @title Approval Mapping Custom Type
library LApprovalsMapping {
    function get(ctypes.ApprovalsMapping position) internal pure returns (mapping(address => mapping(address => uint256)) storage data) {
        // slither-disable-next-line assembly
        assembly {
            data.slot := position
        }
    }
}

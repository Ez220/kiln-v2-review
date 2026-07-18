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

import {Math} from "@dependency/openzeppelin-contracts/utils/math/Math.sol";

library LibUint256 {
    // slither-disable-next-line dead-code
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        // slither-disable-next-line assembly
        assembly {
            z := xor(x, mul(xor(x, y), lt(y, x)))
        }
    }

    /// @custom:author Vectorized/solady#58681e79de23082fd3881a76022e0842f5c08db8
    // slither-disable-next-line dead-code
    function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        // slither-disable-next-line assembly
        assembly {
            z := xor(x, mul(xor(x, y), gt(y, x)))
        }
    }

    // slither-disable-next-line dead-code
    function mulDivFloor(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        return Math.mulDiv(a, b, c, Math.Rounding.Trunc);
    }

    /// @dev Backward-compatible alias for mulDivFloor
    // slither-disable-next-line dead-code
    function mulDiv(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        return mulDivFloor(a, b, c);
    }

    // slither-disable-next-line dead-code
    function mulDivCeil(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        return Math.mulDiv(a, b, c, Math.Rounding.Expand);
    }

    // slither-disable-next-line dead-code
    function ceil(uint256 num, uint256 den) internal pure returns (uint256) {
        return (num / den) + (num % den > 0 ? 1 : 0);
    }
}

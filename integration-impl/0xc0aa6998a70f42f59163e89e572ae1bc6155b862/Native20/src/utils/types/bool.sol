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
// solhint-disable one-contract-per-file
//
pragma solidity 0.8.20;

import {types} from "@src/utils/types/types.sol";

library LBool {
    // slither-disable-next-line dead-code
    function set(types.Bool position, bool data) internal {
        // slither-disable-next-line assembly
        assembly {
            sstore(position, data)
        }
    }

    // slither-disable-next-line dead-code
    function del(types.Bool position) internal {
        // slither-disable-next-line assembly
        assembly {
            sstore(position, 0)
        }
    }

    // slither-disable-next-line dead-code
    function get(types.Bool position) internal view returns (bool data) {
        // slither-disable-next-line assembly
        assembly {
            data := sload(position)
        }
    }
}

library CBool {
    // slither-disable-next-line dead-code
    function toBytes32(bool val) internal pure returns (bytes32) {
        return bytes32(toUint256(val));
    }

    // slither-disable-next-line dead-code
    function toAddress(bool val) internal pure returns (address) {
        return address(uint160(toUint256(val)));
    }

    // slither-disable-next-line dead-code
    function toUint256(bool val) internal pure returns (uint256 converted) {
        // slither-disable-next-line assembly
        assembly {
            converted := iszero(iszero(val))
        }
    }

    /// @dev This method should be used to convert a bool to a uint256 when used as a key in a mapping.
    // slither-disable-next-line dead-code
    function k(bool val) internal pure returns (uint256) {
        return toUint256(val);
    }

    /// @dev This method should be used to convert a bool to a uint256 when used as a value in a mapping.
    // slither-disable-next-line dead-code
    function v(bool val) internal pure returns (uint256) {
        return toUint256(val);
    }
}

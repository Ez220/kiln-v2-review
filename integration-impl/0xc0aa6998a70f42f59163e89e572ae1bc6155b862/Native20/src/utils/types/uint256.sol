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

library LUint256 {
    // slither-disable-next-line dead-code
    function set(types.Uint256 position, uint256 data) internal {
        // slither-disable-next-line assembly
        assembly {
            sstore(position, data)
        }
    }

    // slither-disable-next-line dead-code
    function del(types.Uint256 position) internal {
        // slither-disable-next-line assembly
        assembly {
            sstore(position, 0)
        }
    }

    // slither-disable-next-line dead-code
    function get(types.Uint256 position) internal view returns (uint256 data) {
        // slither-disable-next-line assembly
        assembly {
            data := sload(position)
        }
    }
}

library CUint256 {
    // slither-disable-next-line dead-code
    function toBytes32(uint256 val) internal pure returns (bytes32) {
        return bytes32(val);
    }

    // slither-disable-next-line dead-code
    function toAddress(uint256 val) internal pure returns (address) {
        return address(uint160(val));
    }

    // slither-disable-next-line dead-code
    function toBool(uint256 val) internal pure returns (bool) {
        return (val & 1) == 1;
    }
}

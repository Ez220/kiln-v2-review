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

import {types} from "@src/utils/types/types.sol";

library LArray {
    // slither-disable-next-line dead-code
    function del(types.Array position) internal {
        // slither-disable-next-line assembly
        assembly {
            let len := sload(position)

            if len {
                // clear the length slot
                sstore(position, 0)

                // calculate the starting slot of the array elements in storage
                // Stores position at 0x60 which we set back to 0 at the end of the function, avoids allocating free memory
                // cf. https://docs.soliditylang.org/en/v0.8.20/assembly.html#memory-management
                mstore(0x60, position)
                let startPtr := keccak256(0x60, 0x20)

                for {} len {} {
                    len := sub(len, 1)
                    sstore(add(startPtr, len), 0)
                }

                // Clean up the scratch space
                mstore(0x60, 0)
            }
        }
    }

    /// @dev This delete can be used if and only if we only want to clear the length of the array.
    ///         Doing so will create an array that behaves like an empty array in solidity.
    ///         It can have advantages if we often rewrite to the same slots of the array.
    ///         Prefer using `del` if you don't know what you're doing.
    // slither-disable-next-line dead-code
    function dangerousDirtyDel(types.Array position) internal {
        // slither-disable-next-line assembly
        assembly {
            sstore(position, 0)
        }
    }

    // slither-disable-next-line dead-code
    function toUintA(types.Array position) internal pure returns (uint256[] storage data) {
        // slither-disable-next-line assembly
        assembly {
            data.slot := position
        }
    }

    // slither-disable-next-line dead-code
    function toAddressA(types.Array position) internal pure returns (address[] storage data) {
        // slither-disable-next-line assembly
        assembly {
            data.slot := position
        }
    }

    // slither-disable-next-line dead-code
    function toBoolA(types.Array position) internal pure returns (bool[] storage data) {
        // slither-disable-next-line assembly
        assembly {
            data.slot := position
        }
    }

    // slither-disable-next-line dead-code
    function toBytes32A(types.Array position) internal pure returns (bytes32[] storage data) {
        // slither-disable-next-line assembly
        assembly {
            data.slot := position
        }
    }
}

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

library LString {
    struct StringStorage {
        string value;
    }

    // slither-disable-next-line dead-code
    function set(types.String position, string memory value) internal {
        StringStorage storage ss;

        // slither-disable-next-line assembly
        assembly {
            ss.slot := position
        }

        ss.value = value;
    }

    // slither-disable-next-line dead-code
    function get(types.String position) internal view returns (string memory) {
        StringStorage storage ss;

        // slither-disable-next-line assembly
        assembly {
            ss.slot := position
        }

        return ss.value;
    }
}

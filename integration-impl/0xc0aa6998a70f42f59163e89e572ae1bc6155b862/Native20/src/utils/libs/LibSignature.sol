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

library LibSignature {
    struct Signature {
        bytes32 a;
        bytes32 b;
        bytes32 c;
    }

    // slither-disable-next-line unused-state
    uint256 internal constant SIGNATURE_LENGTH = 96;

    // slither-disable-next-line dead-code
    function toBytes(Signature memory signature) internal pure returns (bytes memory) {
        return abi.encodePacked(signature.a, signature.b, signature.c);
    }

    // slither-disable-next-line dead-code
    function fromBytes(bytes memory signature) internal pure returns (Signature memory ret) {
        (ret) = abi.decode(signature, (Signature));
    }
}

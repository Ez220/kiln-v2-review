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

library LibPublicKey {
    struct PublicKey {
        bytes32 a;
        bytes16 b;
    }

    // slither-disable-next-line unused-state
    uint256 internal constant PUBLIC_KEY_LENGTH = 48;

    // slither-disable-next-line unused-state
    bytes internal constant PADDING = hex"00000000000000000000000000000000";

    // slither-disable-next-line dead-code
    function toBytes(PublicKey memory publicKey) internal pure returns (bytes memory) {
        return abi.encodePacked(publicKey.a, publicKey.b);
    }

    // slither-disable-next-line dead-code
    function fromBytes(bytes memory publicKey) internal pure returns (PublicKey memory ret) {
        publicKey = bytes.concat(publicKey, PADDING);
        (bytes32 a, bytes32 bPrime) = abi.decode(publicKey, (bytes32, bytes32));
        bytes16 b = bytes16(uint128(uint256(bPrime) >> 128));
        ret.a = a;
        ret.b = b;
    }
}

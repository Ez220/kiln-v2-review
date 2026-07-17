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
pragma solidity 0.8.17;

import "utils.sol/Hatcher.sol";
import "utils.sol/libs/LibSanitize.sol";

import "../src/interfaces/IPluggableHatcher.sol";

/// @title Pluggable Hatcher
/// @author mortimr @ Kiln
/// @notice The PluggableHatcher extends the Hatcher and allows the nexus to spawn cubs
contract PluggableHatcher is Hatcher, IPluggableHatcher {
    using LAddress for types.Address;

    using CAddress for address;

    /// @dev The nexus instance.
    /// @dev Slot: keccak256(bytes("pluggableHatcher.1.nexus")) - 1
    types.Address internal constant $nexus = types.Address.wrap(0xf9a2bbc6604b460dea2b9e85ead19324d4c2b79c6ba1c0a5443b33d1c7d26559);

    /// @notice Prevents unauthorized calls
    modifier onlyNexus() {
        if (msg.sender != $nexus.get()) {
            revert LibErrors.Unauthorized(msg.sender, $nexus.get());
        }
        _;
    }

    /// @param _implementation Address of the common implementation
    /// @param _admin Address administrating this contract
    /// @param _nexus Address of the nexus allowed to use plug
    constructor(address _implementation, address _admin, address _nexus) {
        LibSanitize.notZeroAddress(_nexus);
        _setImplementation(_implementation);
        _setAdmin(_admin);
        $nexus.set(_nexus);
        emit SetNexus(_nexus);
    }

    /// @inheritdoc IPluggableHatcher
    function nexus() external view returns (address) {
        return $nexus.get();
    }

    /// @inheritdoc IPluggableHatcher
    function plug(bytes calldata cdata) external onlyNexus returns (address) {
        return _hatch(cdata);
    }
}

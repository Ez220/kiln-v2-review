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
import {Administrable} from "@src/utils/Administrable.sol";
import {LMapping} from "@src/utils/types/mapping.sol";
import {LUint256, CUint256} from "@src/utils/types/uint256.sol";
import {LBool, CBool} from "@src/utils/types/bool.sol";
import {LAddress, CAddress} from "@src/utils/types/address.sol";
import {LArray} from "@src/utils/types/array.sol";
import {LAddress} from "@src/utils/types/address.sol";

import {LibSanitize} from "@src/utils/libs/LibSanitize.sol";
import {LibErrors} from "@src/utils/libs/LibErrors.sol";
import {LibShares} from "@src/utils/libs/LibShares.sol";
import {LibBasisPoints} from "@src/utils/libs/LibBasisPoints.sol";

import {Administrable} from "@src/utils/Administrable.sol";

import {IvPoolSharesReceiver} from "@src/interfaces/IvPoolSharesReceiver.sol";
import {IvPool} from "@src/interfaces/IvPool.sol";
import {IMultiPool} from "@src/interfaces/integrations/IMultiPool.sol";

import {FeeDispatcher} from "@src/integrations/FeeDispatcher.sol";
import {AccountList} from "@src/integrations/AccountList.sol";

uint256 constant MIN_COMMISSION = 1e9; // If there is less than a gwei of commission to sell, we don't sell it

/// @dev Struct to cache pool infos, rate does not change during the function execution
/// @param id The pool id
/// @param totalUnderlyingSupply The total underlying supply
/// @param totalSupply The total supply
/// @param poolAddress The pool address
struct PoolInfo {
    uint256 id;
    uint256 totalUnderlyingSupply;
    uint256 totalSupply;
    address poolAddress;
}

/// @title MultiPool (v1)
/// @author 0xvv @ Kiln
/// @notice This contract contains the common functions to all integration contracts
/// @notice Contains the functions to add pools, activate/deactivate a pool, change the fee of a pool and change the commission distribution
abstract contract MultiPool is IMultiPool, FeeDispatcher, Administrable, AccountList {
    using LArray for types.Array;
    using LMapping for types.Mapping;
    using LUint256 for types.Uint256;
    using LBool for types.Bool;
    using LAddress for types.Address;

    using CAddress for address;
    using CBool for bool;
    using CUint256 for uint256;

    /// @dev The mapping of pool addresses
    /// @dev Type: mapping(uint256 => address)
    /// @dev Slot: keccak256(bytes("multiPool.1.poolMap")) - 1
    types.Mapping internal constant $poolMap = types.Mapping.wrap(0xbbbff6eb43d00812703825948233d51219dc930ada33999d17cf576c509bebe5);

    /// @dev The mapping of fee amounts in basis point to be applied on rewards from different pools
    /// @dev Type: mapping(uint256 => uint256)
    /// @dev Slot: keccak256(bytes("multiPool.1.fees")) - 1
    types.Mapping internal constant $fees = types.Mapping.wrap(0x725bc5812d869f51ca713008babaeead3e54db7feab7d4cb185136396950f0e3);

    /// @dev The mapping of commission paid for different pools
    /// @dev Type: mapping(uint256 => uint256)
    /// @dev Slot: keccak256(bytes("multiPool.1.commissionPaid")) - 1
    types.Mapping internal constant $commissionPaid = types.Mapping.wrap(0x6c8f9259db4f6802ea7a1e0a01ddb54668b622f1e8d6b610ad7ba4d95f59da29);

    /// @dev The mapping of injected Eth for different pools
    /// @dev Type: mapping(uint256 => uint256)
    /// @dev Slot: keccak256(bytes("multiPool.1.injectedEth")) - 1
    types.Mapping internal constant $injectedEth = types.Mapping.wrap(0x03abd4c14227eca60c6fecceef3797455c352f43ab35128096ea0ac0d9b2170a);

    /// @dev The mapping of exited Eth for different pools
    /// @dev Type: mapping(uint256 => uint256)
    /// @dev Slot: keccak256(bytes("multiPool.1.exitedEth")) - 1
    types.Mapping internal constant $exitedEth = types.Mapping.wrap(0x76a0ecda094c6ccf2a55f6f1ef41b98d3c1f2dfcb9c1970701fe842ce778ff9b);

    /// @dev The mapping storing whether users can deposit or not to each pool
    /// @dev Type: mapping(uint256 => bool)
    /// @dev Slot: keccak256(bytes("multiPool.1.poolActivation")) - 1
    types.Mapping internal constant $poolActivation = types.Mapping.wrap(0x17b1774c0811229612ec3762023ccd209d6a131e52cdd22f3427eaa8005bcb2f);

    /// @dev The mapping of pool shares owned for each pools
    /// @dev Type: mapping(uint256 => uint256)
    /// @dev Slot: keccak256(bytes("multiPool.1.poolShares")) - 1
    types.Mapping internal constant $poolShares = types.Mapping.wrap(0x357e26a850dc4edaa8b82b6511eec141075372c9c551d3ddb37c35a301f00018);

    /// @dev The number of pools.
    /// @dev Slot: keccak256(bytes("multiPool.1.poolCount")) - 1
    types.Uint256 internal constant $poolCount = types.Uint256.wrap(0xce6dbdcc28927f6ed428550e539c70c9145bd20fc6e3d7611bd20e170e9b1840);

    /// @dev True if deposits are paused
    /// @dev Slot: keccak256(bytes("multiPool.1.depositsPaused")) - 1
    types.Bool internal constant $depositPaused = types.Bool.wrap(0xa030c45ae387079bc9a34aa1365121b47b8ef2d06c04682ce63b90b7c06843e7);

    /// @dev The maximum commission that can be set for a pool, in basis points, to be set at initialization
    /// @dev Slot: keccak256(bytes("multiPool.1.maxCommission")) - 1
    types.Uint256 internal constant $maxCommission = types.Uint256.wrap(0x70be78e680b682a5a3c38e305d79e28594fd0c62048cca29ef1bd1d746ca8785);

    /// @dev The address allowed to authorize users
    /// @dev Slot: keccak256(bytes("multiPool.1.authorizer")) - 1
    types.Address internal constant $authorizer = types.Address.wrap(0xed53d700db565a3dca22c26af424ad65ceb595f7ae6c3e1e4d4c9b873d312581);

    uint256 internal constant NO_RIGHTS = 0;
    uint256 internal constant RIGHTS__FORBIDDEN = 0x1;
    uint256 internal constant RIGHTS__STAKE = RIGHTS__FORBIDDEN << 1;
    uint256 internal constant RIGHTS__TRANSFER = RIGHTS__STAKE << 1;
    uint256 internal constant RIGHTS__REQUEST_EXIT = RIGHTS__TRANSFER << 1;

    /// @notice This modifier reverts if the deposit is paused
    modifier notPaused() {
        if ($depositPaused.get()) {
            revert DepositsPaused();
        }
        _;
    }

    modifier onlyAdminOrAuthorizer() {
        if (msg.sender != $authorizer.get() && msg.sender != $admin.get()) {
            revert LibErrors.Unauthorized(msg.sender, address(0));
        }
        _;
    }

    /// @inheritdoc IMultiPool
    function pauseDeposits(bool isPaused) external onlyAdmin {
        emit SetDepositsPaused(isPaused);
        $depositPaused.set(isPaused);
    }

    /// @inheritdoc IMultiPool
    // slither-disable-next-line reentrancy-events
    function changeFee(uint256 poolId, uint256 newFeeBps) external onlyAdmin {
        PoolInfo memory pool = _getPoolInfo(poolId);
        uint256 earnedBeforeFeeUpdate = _integratorCommissionEarned(pool);
        _setFee(newFeeBps, poolId);
        uint256 earnedAfterFeeUpdate = _integratorCommissionEarned(pool);

        uint256 paid = $commissionPaid.get()[poolId];
        uint256 paidAndEarnedAfter = paid + earnedAfterFeeUpdate;
        if (paidAndEarnedAfter < earnedBeforeFeeUpdate) {
            revert CommissionPaidUnderflow();
        }
        $commissionPaid.get()[poolId] = paidAndEarnedAfter - earnedBeforeFeeUpdate;
    }

    /// @inheritdoc IMultiPool
    function changeSplit(address[] calldata recipients, uint256[] calldata splits) external onlyAdmin {
        // Make sure the commission is withdrawn before changing the split
        if (address(this).balance > 0) withdrawCommission();

        PoolInfo[] memory poolInfos = _getPoolInfos();
        for (uint256 i = 0; i < poolInfos.length;) {
            // If only dust is left, we don't exit the share, it would only waste gas
            if (_integratorCommissionOwed(poolInfos[i]) > MIN_COMMISSION) {
                _exitCommissionShares(poolInfos[i]);
            }
            unchecked {
                i++;
            }
        }

        _setFeeSplit(recipients, splits);
    }

    /// @inheritdoc IMultiPool
    function addPool(address pool, uint256 feeBps) external onlyAdmin {
        _addPool(pool, feeBps);
    }

    /// @inheritdoc IMultiPool
    function exitCommissionShares(uint256 poolId) external onlyAdmin {
        _exitCommissionShares(_getPoolInfo(poolId));
    }

    /// @inheritdoc IMultiPool
    function setDefaultRights(uint248 rights) external onlyAdmin {
        _setDefaultRights(rights);
    }

    /// @inheritdoc IMultiPool
    function setAuthorizer(address _authorizer) external onlyAdmin {
        _setAuthorizer(_authorizer);
    }

    /// @inheritdoc IMultiPool
    function authorize(uint248 rights, address account) external onlyAdminOrAuthorizer {
        _applyRights(rights, account, msg.sender);
    }

    /// @inheritdoc IMultiPool
    function authorize(uint248 rights, address account, uint256 expiration, uint256 nonce, uint8 v, bytes32 r, bytes32 s) external {
        _checkAndApplyAuthorization(rights, account, expiration, nonce, v, r, s);
    }

    /// @inheritdoc IMultiPool
    function clearAuthorizations(address account) external onlyAdminOrAuthorizer {
        _clearRights(account, msg.sender);
    }

    /// @inheritdoc IMultiPool
    function incrementNonce(address account) external onlyAdminOrAuthorizer {
        _incrementNonce(account);
    }

    /// @inheritdoc IvPoolSharesReceiver
    function onvPoolSharesReceived(address operator, address from, uint256 amount, bytes memory) external returns (bytes4) {
        uint256 poolId = _findPoolIdOrRevert(msg.sender);
        if (!$poolActivation.get()[poolId].toBool()) revert PoolDisabled(poolId);
        // Check this callback is from minting, we can only receive shares from the pool when depositing
        if ($poolMap.get()[poolId].toAddress() != operator || from != address(0)) {
            revert CallbackNotFromMinting();
        }
        $poolShares.get()[poolId] += amount;
        emit VPoolSharesReceived(msg.sender, poolId, amount);
        return IvPoolSharesReceiver.onvPoolSharesReceived.selector;
    }

    /// @inheritdoc IMultiPool
    function depositsPaused() external view returns (bool) {
        return $depositPaused.get();
    }

    /// @inheritdoc IMultiPool
    function getFee(uint256 poolId) external view returns (uint256) {
        return $fees.get()[poolId];
    }

    /// @inheritdoc IMultiPool
    function getPoolActivation(uint256 poolId) external view returns (bool) {
        return $poolActivation.get()[poolId].toBool();
    }

    /// @inheritdoc IMultiPool
    function stakedEthValue(uint256 poolId) external view returns (uint256) {
        return _stakedEthValue(_getPoolInfo(poolId));
    }

    /// @inheritdoc IMultiPool
    function ethAfterCommission(uint256 poolId) external view returns (uint256) {
        return _ethAfterCommission(_getPoolInfo(poolId));
    }

    /// @inheritdoc IMultiPool
    function integratorCommissionEarned(uint256 poolId) external view returns (uint256) {
        return _integratorCommissionEarned(_getPoolInfo(poolId));
    }

    /// @inheritdoc IMultiPool
    function getCommissionPaid(uint256 poolId) external view returns (uint256) {
        return $commissionPaid.get()[poolId];
    }

    /// @inheritdoc IMultiPool
    function integratorCommissionOwed(uint256 poolId) external view returns (uint256) {
        return _integratorCommissionOwed(_getPoolInfo(poolId));
    }

    /// @inheritdoc IMultiPool
    function getInjectedEth(uint256 poolId) external view returns (uint256) {
        return $injectedEth.get()[poolId];
    }

    /// @inheritdoc IMultiPool
    function getExitedEth(uint256 poolId) external view returns (uint256) {
        return $exitedEth.get()[poolId];
    }

    /// @inheritdoc IMultiPool
    function getPoolShares(uint256 poolId) external view returns (uint256) {
        return $poolShares.get()[poolId];
    }

    /// @inheritdoc IMultiPool
    function defaultRights() external view returns (uint248) {
        return uint248($defaultRights.get());
    }

    /// @inheritdoc IMultiPool
    function authorizer() external view returns (address) {
        return $authorizer.get();
    }

    /// @inheritdoc IMultiPool
    function pools() public view returns (address[] memory) {
        address[] memory poolAddresses = new address[]($poolCount.get());
        for (uint256 i = 0; i < poolAddresses.length;) {
            poolAddresses[i] = $poolMap.get()[i].toAddress();
            unchecked {
                i++;
            }
        }
        return poolAddresses;
    }

    ////////////////////////////////////////////////////////
    /// PRIVATE METHODS
    ////////////////////////////////////////////////////////

    /// @dev Internal utility to exit commission shares
    /// @param pInfo The poolInfo struct containing the pool id and supplies
    // slither-disable-next-line reentrancy-events
    function _exitCommissionShares(PoolInfo memory pInfo) internal {
        if (pInfo.id >= $poolCount.get()) revert InvalidPoolId(pInfo.id);
        uint256 shares = _poolSharesOfIntegrator(pInfo);
        if (shares == 0) revert NoSharesToExit(pInfo.id);

        address[] memory recipients = $feeRecipients.toAddressA();
        uint256[] memory weights = $feeSplits.toUintA();
        for (uint256 i = 0; i < recipients.length;) {
            uint256 share = LibBasisPoints.compute(shares, weights[i]);
            if (share > 0) {
                _sendSharesToExitQueue(pInfo.id, share, IvPool(pInfo.poolAddress), recipients[i]);
            }
            unchecked {
                ++i;
            }
        }

        $exitedEth.get()[pInfo.id] += LibShares.previewRedeem(shares, pInfo.totalSupply, pInfo.totalUnderlyingSupply);
        $commissionPaid.get()[pInfo.id] = _integratorCommissionEarned(pInfo);
        emit ExitedCommissionShares(pInfo.id, shares, weights, recipients);
    }

    /// @dev Internal utility to send pool shares to the exit queue
    // slither-disable-next-line calls-loop
    function _sendSharesToExitQueue(uint256 poolId, uint256 shares, IvPool pool, address ticketOwner) internal {
        $poolShares.get()[poolId] -= shares;
        // Pass the ticketOwner as data for the transfer to the exitQueue so the ticket is minted to the right address
        bool result = pool.transferShares(pool.exitQueue(), shares, abi.encodePacked(ticketOwner));
        if (!result) {
            revert PoolTransferFailed(poolId);
        }
    }

    /// @dev Internal utility to set the integrator fee value
    /// @param integratorFeeBps The new integrator fee in bps
    /// @param poolId The vPool id
    function _setFee(uint256 integratorFeeBps, uint256 poolId) internal {
        if (integratorFeeBps > $maxCommission.get()) {
            revert FeeOverMax($maxCommission.get());
        }
        $fees.get()[poolId] = integratorFeeBps;
        emit SetFee(poolId, integratorFeeBps);
    }

    /// @dev Add a pool to the list.
    /// @param newPool new pool address.
    /// @param fee fees in basis points of ETH.
    // slither-disable-next-line dead-code
    function _addPool(address newPool, uint256 fee) internal {
        LibSanitize.notZeroAddress(newPool);

        uint256 poolId = $poolCount.get();
        for (uint256 i = 0; i < poolId;) {
            if (newPool == $poolMap.get()[i].toAddress()) {
                revert PoolAlreadyRegistered(newPool);
            }
            unchecked {
                i++;
            }
        }

        $poolMap.get()[poolId] = newPool.v();
        $poolActivation.get()[poolId] = true.v();
        $poolCount.set(poolId + 1);

        _setFee(fee, poolId);
        emit PoolAdded(newPool, poolId);
    }

    /// @dev Internal utility to set the max commission value
    /// @param maxCommission The new max commission in bps
    // slither-disable-next-line dead-code
    function _setMaxCommission(uint256 maxCommission) internal {
        LibBasisPoints.check(maxCommission);
        $maxCommission.set(maxCommission);
        emit SetMaxCommission(maxCommission);
    }

    /// @dev Internal utility to set the authorizer
    /// @param _authorizer The new authorizer
    function _setAuthorizer(address _authorizer) internal {
        $authorizer.set(_authorizer);
        emit SetAuthorizer(_authorizer);
    }

    /// @dev Internal utility to verify a signed authorization has been performed by the admin or the authorizer and apply the rights
    /// @param rights The rights to apply
    /// @param account The account to apply the rights to
    /// @param expiration The expiration of the authorization
    /// @param nonce The nonce of the authorization
    /// @param v The recovery id of the signature
    /// @param r The r component of the signature
    /// @param s The s component of the signature
    function _checkAndApplyAuthorization(uint248 rights, address account, uint256 expiration, uint256 nonce, uint8 v, bytes32 r, bytes32 s)
        internal
    {
        address retrievedSigner = _verifyApplyRightsAuthorization(rights, account, expiration, nonce, v, r, s);
        if (retrievedSigner != $authorizer.get() && retrievedSigner != $admin.get()) {
            revert InvalidSignedAuthorization(rights, account, expiration, nonce, v, r, s);
        }
        _applyRights(rights, account, retrievedSigner);
    }

    /// @dev Internal utility to populate PoolInfo struct
    /// @param poolId The vPool id
    /// @return PoolInfo struct
    function _getPoolInfo(uint256 poolId) internal view returns (PoolInfo memory) {
        address poolAddress = $poolMap.get()[poolId].toAddress();
        IvPool pool = IvPool(poolAddress);
        return PoolInfo({
            id: poolId, totalUnderlyingSupply: pool.totalUnderlyingSupply(), totalSupply: pool.totalSupply(), poolAddress: poolAddress
        });
    }

    /// @dev Internal utility to get all pool infos
    /// @return poolInfos array of PoolInfo structs
    function _getPoolInfos() internal view returns (PoolInfo[] memory) {
        PoolInfo[] memory poolInfos = new PoolInfo[]($poolCount.get());
        for (uint256 i = 0; i < poolInfos.length;) {
            poolInfos[i] = _getPoolInfo(i);
            unchecked {
                i++;
            }
        }
        return poolInfos;
    }

    /// @notice Internal utility to find the id of a pool using its address
    /// @dev Reverts if the address is not found
    /// @param poolAddress address of the pool to look up
    function _findPoolIdOrRevert(address poolAddress) internal view returns (uint256) {
        for (uint256 id = 0; id < $poolCount.get();) {
            if (poolAddress == $poolMap.get()[id].toAddress()) {
                return id;
            }
            unchecked {
                id++;
            }
        }
        revert NotARegisteredPool(poolAddress);
    }

    /// @dev Internal utility to get get the pool address
    /// @param poolId The index of the pool
    /// @return The pool
    // slither-disable-next-line naming-convention
    function _getPool(uint256 poolId) internal view returns (IvPool) {
        if (poolId >= $poolCount.get()) {
            revert InvalidPoolId(poolId);
        }
        return IvPool($poolMap.get()[poolId].toAddress());
    }

    /// @dev Returns the ETH value of the vPool shares in the contract.
    /// @return amount of ETH.
    // slither-disable-next-line calls-loop
    function _stakedEthValue(PoolInfo memory pool) internal view returns (uint256) {
        if (pool.totalSupply == 0) {
            return 0;
        }
        return LibShares.previewRedeem($poolShares.get()[pool.id], pool.totalSupply, pool.totalUnderlyingSupply);
    }

    /// @dev Returns the amount of ETH earned by the integrator.
    /// @return amount of ETH.
    function _integratorCommissionEarned(PoolInfo memory pool) internal view returns (uint256) {
        uint256 stakedPlusExited = _stakedEthValue(pool) + $exitedEth.get()[pool.id];
        uint256 injected = $injectedEth.get()[pool.id];
        if (injected >= stakedPlusExited) {
            // Can happen right after staking due to rounding
            return 0;
        }
        uint256 rewardsEarned = stakedPlusExited - injected;
        return LibBasisPoints.compute(rewardsEarned, $fees.get()[pool.id]);
    }

    /// @dev Returns the amount of ETH owed to the integrator.
    /// @return amount of ETH.
    // slither-disable-next-line dead-code
    function _integratorCommissionOwed(PoolInfo memory pool) internal view returns (uint256) {
        uint256 earned = _integratorCommissionEarned(pool);
        uint256 paid = $commissionPaid.get()[pool.id];
        if (earned > paid) {
            return earned - paid;
        } else {
            return 0;
        }
    }

    /// @dev Returns the ETH value of the vPool shares after subtracting commission.
    /// @return amount of ETH.
    // slither-disable-next-line dead-code
    function _ethAfterCommission(PoolInfo memory pool) internal view returns (uint256) {
        return _stakedEthValue(pool) - _integratorCommissionOwed(pool);
    }

    /// @dev Returns the number of vPool shares owed as commission.
    /// @return amount of shares.
    // slither-disable-next-line calls-loop,dead-code
    function _poolSharesOfIntegrator(PoolInfo memory pool) internal view returns (uint256) {
        uint256 poolTotalUnderlying = pool.totalUnderlyingSupply;
        return
            poolTotalUnderlying == 0 ? 0 : LibShares.previewDeposit(_integratorCommissionOwed(pool), pool.totalSupply, poolTotalUnderlying);
    }
}

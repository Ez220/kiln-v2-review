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

import {SafeCast} from "@dependency/openzeppelin-contracts/utils/math/SafeCast.sol";

import {types} from "@src/utils/types/types.sol";
import {ctypes} from "@src/ctypes/ctypes.sol";
import {LMapping} from "@src/utils/types/mapping.sol";
import {LArray} from "@src/utils/types/array.sol";
import {LAddress} from "@src/utils/types/address.sol";
import {LUint256, CUint256} from "@src/utils/types/uint256.sol";
import {LBool, CBool} from "@src/utils/types/bool.sol";
import {LApprovalsMapping} from "@src/ctypes/approvals_mapping.sol";
import {LSimpleBalanceMapping} from "@src/ctypes/simple_balance_mapping.sol";

import {LibUint256} from "@src/utils/libs/LibUint256.sol";
import {LibShares} from "@src/utils/libs/LibShares.sol";
import {LibBasisPoints} from "@src/utils/libs/LibBasisPoints.sol";
import {LibSanitize} from "@src/utils/libs/LibSanitize.sol";

import {IMultiPool20} from "@src/interfaces/integrations/IMultiPool20.sol";
import {IvPool} from "@src/interfaces/IvPool.sol";
import {ISanctionsList} from "@src/interfaces/ISanctionsList.sol";

import {MultiPool, MIN_COMMISSION, PoolInfo} from "@src/integrations/MultiPool.sol";
import {PoolExitDetails, PoolStakeDetails} from "@src/interfaces/integrations/IMultiPool.sol";

uint256 constant MIN_SUPPLY = 1e14; // If there is only dust in the pool, we mint 1:1
uint256 constant COMMISSION_MAX = 10; // 0.1% / 10 bps ~= 12 days of accrued commission at 3% GRR

/// @title MultiPool-20 (v1)
/// @author 0xvv @ Kiln
/// @notice This contract contains the internal logic for an ERC-20 token based on one or multiple pools.
abstract contract MultiPool20 is MultiPool, IMultiPool20 {
    using LAddress for types.Address;
    using LArray for types.Array;
    using LBool for types.Bool;
    using LMapping for types.Mapping;
    using LUint256 for types.Uint256;
    using LSimpleBalanceMapping for ctypes.SimpleBalanceMapping;
    using LApprovalsMapping for ctypes.ApprovalsMapping;
    using CUint256 for uint256;

    using CBool for bool;

    using SafeCast for uint256;
    using SafeCast for int256;

    ISanctionsList public immutable SANCTIONS_ORACLE;

    /// @dev The total supply of ERC 20.
    /// @dev Slot: keccak256(bytes("multiPool20.1.totalSupply")) - 1
    types.Uint256 internal constant $totalSupply = types.Uint256.wrap(0xb24a0f21470b6927dcbaaf5b1f54865bd687f4a2ce4c43edf1e20339a4c05bae);

    /// @dev The list containing the percentages of ETH to route to each pool, in basis points, must add up to 10 000.
    /// @dev Slot: keccak256(bytes("multiPool20.1.poolRoutingList")) - 1
    types.Array internal constant $poolRoutingList = types.Array.wrap(0x3803482dd7707d12238e38a3b1b5e55fa6e13d81c36ce29ec5c267cc02c53fe3);

    /// @dev Stores the balances : mapping(address => uint256).
    /// @dev Slot: keccak256(bytes("multiPool20.1.balances")) - 1
    ctypes.SimpleBalanceMapping internal constant $balances =
        ctypes.SimpleBalanceMapping.wrap(0x4f74125ce1aafb5d1699fc2e5e8f96929ff1a99170dc9bda82c8944acc5c7286);

    /// @dev Stores the approvals
    /// @dev Type: mapping(address => mapping(address => bool).
    /// @dev Slot: keccak256(bytes("multiPool20.1.approvals")) - 1
    ctypes.ApprovalsMapping internal constant $approvals =
        ctypes.ApprovalsMapping.wrap(0xebc1e0a04bae59eb2e2b17f55cd491aec28c349ae4f6b6fe9be28a72f9c6b202);

    /// @dev The threshold below which we try to issue only one exit ticket
    /// @dev Slot: keccak256(bytes("multiPool20.1.monoTicketThreshold")) - 1
    types.Uint256 internal constant $monoTicketThreshold =
        types.Uint256.wrap(0x900053b761278bb5de4eeaea5ed9000b89943edad45dcf64a9dab96d0ce29c2e);

    /// @dev The activation status of the sanctions list
    /// @dev Slot: keccak256(bytes("multiPool20.1.sanctionsActive")) - 1
    types.Bool internal constant $sanctionsActive = types.Bool.wrap(0x665a64eda6493c95e68ec3ff355c727f0384c5f190e8cbfc94849d3d7bd1822d);

    constructor(address sanctionsOracle) {
        LibSanitize.notZeroAddress(sanctionsOracle);
        SANCTIONS_ORACLE = ISanctionsList(sanctionsOracle);
    }

    /// @inheritdoc IMultiPool20
    function setPoolPercentages(uint256[] calldata split) external onlyAdmin {
        _setPoolPercentages(split);
    }

    /// @inheritdoc IMultiPool20
    function setPoolActivation(uint256 poolId, bool status, uint256[] calldata newPoolPercentages) external onlyAdmin {
        if (poolId >= $poolCount.get()) revert InvalidPoolId(poolId);
        $poolActivation.get()[poolId] = status.v();
        _setPoolPercentages(newPoolPercentages);
    }

    /// @inheritdoc IMultiPool20
    function setSanctionsActivation(bool active) external onlyAdmin {
        $sanctionsActive.set(active);
        emit SanctionsActivationChanged(active);
    }

    /// @notice Sets the threshold below which we try to issue only one exit ticket
    /// @param minTicketEthValue The threshold
    function setMonoTicketThreshold(uint256 minTicketEthValue) external onlyAdmin {
        _setMonoTicketThreshold(minTicketEthValue);
    }

    /// @inheritdoc IMultiPool20
    function requestExit(uint256 amount) external virtual {
        revertIfSanctioned(msg.sender);
        _requestExit(amount, _getPoolInfos());
    }

    /// @inheritdoc IMultiPool20
    function forbid(address account) external onlyAdmin {
        _applyRights(uint248(MultiPool.RIGHTS__FORBIDDEN), account, msg.sender);
        uint256 balance = $balances.get()[account];
        if (balance > 0 && ($sanctionsActive.get() && !SANCTIONS_ORACLE.isSanctioned(account))) {
            _performRequestExit(account, balance, _getPoolInfos());
        }
    }

    /// @inheritdoc IMultiPool20
    function rate() external view returns (uint256) {
        return LibShares.rate(_totalSupply(), _totalUnderlyingSupply(_getPoolInfos()));
    }

    /// @inheritdoc IMultiPool20
    function isSanctionsListActive() external view returns (bool) {
        return $sanctionsActive.get();
    }

    /// Private functions

    /// @dev Internal function to request exit for the msg.sender
    /// @param amount The amount of tokens to exit
    /// @param poolInfos The poolInfos struct
    function _requestExit(uint256 amount, PoolInfo[] memory poolInfos) internal {
        _checkNotForbiddenAndAuthorizations(MultiPool.RIGHTS__FORBIDDEN, MultiPool.RIGHTS__REQUEST_EXIT, msg.sender);
        _performRequestExit(msg.sender, amount, poolInfos);
    }

    /// @dev Internal function to requestExit
    /// @param account The account to exit from
    /// @param amount The amount of tokens to exit
    /// @param poolInfos The poolInfos struct
    // slither-disable-next-line reentrancy-events
    function _performRequestExit(address account, uint256 amount, PoolInfo[] memory poolInfos) internal {
        uint256 totalUnderlyingSupply = _totalUnderlyingSupply(poolInfos);
        uint256 currentTotalSupply = $totalSupply.get();

        _burn(account, amount);

        uint256 ethValue = LibShares.previewRedeem(amount, currentTotalSupply, totalUnderlyingSupply);

        // Early return in case of mono pool operation
        uint256 poolCount = poolInfos.length;
        if (poolCount == 1) {
            PoolExitDetails[] memory detail = new PoolExitDetails[](1);
            _sendToExitQueue(poolInfos[0], ethValue, detail[0], account);
            _checkCommissionRatio(poolInfos[0]);
            emit Exit(account, amount.toUint128(), detail);
            return;
        }

        uint256[] memory splits = $poolRoutingList.toUintA();

        // If the amount is below the set threshold we exit via the most imabalanced pool to print only 1 ticket
        if (ethValue < $monoTicketThreshold.get()) {
            int256 maxImbalance = 0;
            uint256 exitPoolId = 0;

            // We iterate over the pools to find the one the most above it's expected value
            for (uint256 id = 0; id < poolCount;) {
                uint256 expectedValue = LibBasisPoints.compute(totalUnderlyingSupply, splits[id]);
                uint256 poolValue = _ethAfterCommission(poolInfos[id]);
                int256 imbalance = poolValue.toInt256() - expectedValue.toInt256();

                // If the pool has enough value to cover the exit and is the most imbalanced yet we select it
                if (poolValue >= ethValue && imbalance > maxImbalance) {
                    maxImbalance = imbalance;
                    exitPoolId = id;
                }
                unchecked {
                    id++;
                }
            }

            // We exit the tokens through the selected pool
            if (maxImbalance > 0) {
                PoolExitDetails[] memory detail = new PoolExitDetails[](1);
                _sendToExitQueue(poolInfos[exitPoolId], ethValue, detail[0], account);
                _checkCommissionRatio(poolInfos[exitPoolId]);
                emit Exit(account, amount.toUint128(), detail);
                return;
            }
        }

        // If the the amount is over the threshold or no pool has enough value to cover the exit
        // we exit proportionally to maintain the balance
        PoolExitDetails[] memory details = new PoolExitDetails[](poolCount);
        for (uint256 id = 0; id < poolCount;) {
            uint256 ethForPool = LibBasisPoints.compute(ethValue, splits[id]);
            if (ethForPool > 0) _sendToExitQueue(poolInfos[id], ethForPool, details[id], account);
            _checkCommissionRatio(poolInfos[id]);
            unchecked {
                id++;
            }
        }
        emit Exit(account, amount.toUint128(), details);
    }

    /// @dev Internal function to exit the commission pool shares if needed
    /// @param pInfo The PoolInfo struct
    function _checkCommissionRatio(PoolInfo memory pInfo) internal {
        // If the commission shares / all shares ratio go over the limit we exit them
        if (_poolSharesOfIntegrator(pInfo) > LibBasisPoints.compute($poolShares.get()[pInfo.id], COMMISSION_MAX)) {
            _exitCommissionShares(pInfo);
        }
    }

    /// @dev Utility function to send a given ETH amount of shares to the exit queue of a pool
    // slither-disable-next-line calls-loop
    function _sendToExitQueue(PoolInfo memory poolInfo, uint256 ethAmount, PoolExitDetails memory details, address exiter) internal {
        uint256 poolShares = LibShares.previewDeposit(ethAmount, poolInfo.totalSupply, poolInfo.totalUnderlyingSupply);
        uint256 stakedValueBefore = _stakedEthValue(poolInfo);
        details.exitedPoolShares = poolShares.toUint128();
        details.poolId = poolInfo.id.toUint128();
        _sendSharesToExitQueue(poolInfo.id, poolShares, IvPool(poolInfo.poolAddress), exiter);
        $exitedEth.get()[poolInfo.id] += stakedValueBefore - _stakedEthValue(poolInfo);
    }

    /// @dev Internal function to stake in one or more pools with arbitrary amounts to each one
    /// @param totalAmount The amount of ETH to stake
    /// @param recipient The recipient of the tokens
    // slither-disable-next-line reentrancy-events,unused-return,dead-code
    // solhint-disable-next-line code-complexity
    function _stake(uint256 totalAmount, address recipient) internal notPaused returns (bool) {
        {
            if (recipient != msg.sender) {
                _checkNotForbiddenAndAuthorizations(
                    MultiPool.RIGHTS__FORBIDDEN, MultiPool.RIGHTS__STAKE | MultiPool.RIGHTS__TRANSFER, msg.sender
                );
                _checkNotForbiddenAndAuthorizations(MultiPool.RIGHTS__FORBIDDEN, MultiPool.RIGHTS__TRANSFER, recipient);
            } else {
                _checkNotForbiddenAndAuthorizations(MultiPool.RIGHTS__FORBIDDEN, MultiPool.RIGHTS__STAKE, msg.sender);
            }
        }
        //  We start by loading the routing weights and initializing the stake details and total to emit at the end
        //  We then iterate over the pools to stake the desired value in each one
        uint256[] memory splits = $poolRoutingList.toUintA();
        // Cache the pool infos, we will keep it updated when depositing in the pools
        PoolInfo[] memory poolInfos = _getPoolInfos();
        PoolStakeDetails[] memory stakeDetails = new PoolStakeDetails[](splits.length);
        uint256 tokensBoughtTotal = 0;
        for (uint256 id = 0; id < poolInfos.length;) {
            // If the pool is enabled and the split is non zero we stake in it
            if (splits[id] > 0) {
                stakeDetails[id].poolId = id.toUint128();
                uint256 remainingEth = LibBasisPoints.compute(totalAmount, splits[id]);
                uint256 totalSupply = _totalSupply(); // we can use these values because the ratio of tokens to underlying is constant in this function
                uint256 totalUnderlyingSupply = _totalUnderlyingSupply(poolInfos);

                IvPool pool = IvPool(poolInfos[id].poolAddress);
                // If the total supply is below 1e14 we mint 1:1
                if (totalSupply < MIN_SUPPLY) {
                    $injectedEth.get()[id] += remainingEth;
                    uint256 tokensAcquired = pool.deposit{value: remainingEth}();
                    poolInfos[id].totalUnderlyingSupply += remainingEth;
                    poolInfos[id].totalSupply += tokensAcquired;
                    tokensBoughtTotal += tokensAcquired;
                    _mint(recipient, tokensAcquired);
                    stakeDetails[id].ethToPool = remainingEth.toUint128();
                    stakeDetails[id].pSharesFromPool = tokensAcquired.toUint128();
                } else {
                    uint256 comOwed = _integratorCommissionOwed(poolInfos[id]);
                    uint256 tokensBoughtPool = 0;

                    // Step 1 : if there is enough commission we sell the commission pool shares to the users
                    // The ETH is then stored on the contract for withdrawal by the integrator
                    // Once sold the commission is not subject to rewards or losses of the staked ETH
                    // If a slashing occurs no commission is earned until the rewards are back to the level before slashing
                    // The MIN threshold prevent wasting gas to sell infinitesimal amounts of commission + a potential DoS vector
                    if (comOwed > MIN_COMMISSION) {
                        uint256 ethForCommission = LibUint256.min(comOwed, remainingEth);
                        remainingEth -= ethForCommission;
                        uint256 pSharesBought = LibShares.previewDeposit(
                            ethForCommission,
                            $poolShares.get()[id] - _poolSharesOfIntegrator(poolInfos[id]),
                            _ethAfterCommission(poolInfos[id])
                        );
                        $commissionPaid.get()[id] += ethForCommission;

                        stakeDetails[id].ethToIntegrator = ethForCommission.toUint128();
                        stakeDetails[id].pSharesFromIntegrator = pSharesBought.toUint128();
                        emit CommissionSharesSold(pSharesBought, id, ethForCommission);

                        uint256 tokensAcquired = LibShares.previewDeposit(ethForCommission, totalSupply, totalUnderlyingSupply);
                        if (tokensAcquired == 0) revert ZeroTokenMint();
                        tokensBoughtPool += tokensAcquired;
                    }

                    // Step 2 : if there is remaining ETH after paying the commission we stake it to the pool
                    if (remainingEth > 0) {
                        $injectedEth.get()[id] += remainingEth;
                        uint256 pShares = pool.deposit{value: remainingEth}();
                        poolInfos[id].totalUnderlyingSupply += remainingEth;
                        poolInfos[id].totalSupply += pShares;

                        uint256 tokensAcquired = LibShares.previewDeposit(remainingEth, totalSupply, totalUnderlyingSupply);
                        if (tokensAcquired == 0) revert ZeroTokenMint();

                        stakeDetails[id].ethToPool += remainingEth.toUint128();
                        stakeDetails[id].pSharesFromPool += pShares.toUint128();
                        tokensBoughtPool += tokensAcquired;
                    }

                    // Minting the tokens acquired in step 1 and 2
                    _mint(recipient, tokensBoughtPool);
                    tokensBoughtTotal += tokensBoughtPool;
                }
            }
            unchecked {
                id++;
            }
        }
        emit Stake(msg.sender, recipient, totalAmount.toUint128(), tokensBoughtTotal.toUint128(), stakeDetails);
        return true;
    }

    /// @dev Internal function to set the pool percentages
    /// @param percentages The new percentages
    function _setPoolPercentages(uint256[] calldata percentages) internal {
        if (percentages.length != $poolCount.get()) {
            revert UnequalLengths(percentages.length, $poolCount.get());
        }

        // delete the old weights and get pointer to the empty list
        $poolRoutingList.del();
        uint256[] storage percentagesList = $poolRoutingList.toUintA();

        uint256 total = 0;
        for (uint256 i = 0; i < percentages.length;) {
            bool enabled = $poolActivation.get()[i].toBool();
            uint256 percentage = percentages[i];

            // If the pool is disabled the weight needs to be equal to 0
            if (!enabled && percentage != 0) {
                revert NonZeroPercentageOnDeactivatedPool(i);
            } else {
                total += percentages[i];
                percentagesList.push(percentages[i]);
            }

            unchecked {
                i++;
            }
        }
        LibBasisPoints.checkTotal(total);

        emit SetPoolPercentages(percentages);
    }

    /// @dev Internal function to transfer tokens from one account to another
    /// @param from The account to transfer from
    /// @param to The account to transfer to
    /// @param amount The amount to transfer
    // slither-disable-next-line dead-code
    function _transfer(address from, address to, uint256 amount) internal virtual {
        _checkNotForbiddenAndAuthorizations(MultiPool.RIGHTS__FORBIDDEN, MultiPool.RIGHTS__TRANSFER, from);
        _checkNotForbiddenAndAuthorizations(MultiPool.RIGHTS__FORBIDDEN, MultiPool.RIGHTS__TRANSFER, to);
        uint256 fromBalance = $balances.get()[from];
        if (amount > fromBalance) {
            revert InsufficientBalance(amount, fromBalance);
        }
        unchecked {
            $balances.get()[from] = fromBalance - amount;
        }
        $balances.get()[to] += amount;

        emit Transfer(from, to, amount);
    }

    /// @dev Internal function to approve a spender
    /// @param owner The owner of the allowance
    /// @param spender The spender of the allowance
    /// @param amount The amount to approve
    // slither-disable-next-line dead-code
    function _approve(address owner, address spender, uint256 amount) internal {
        $approvals.get()[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /// @dev Internal function to transfer tokens from one account to another
    /// @param spender The spender of the allowance
    /// @param from The account to transfer from
    /// @param to The account to transfer to
    /// @param amount The amount to transfer
    // slither-disable-next-line dead-code
    function _transferFrom(address spender, address from, address to, uint256 amount) internal virtual {
        _checkNotForbiddenAndAuthorizations(MultiPool.RIGHTS__FORBIDDEN, 0, msg.sender);
        uint256 approval = $approvals.get()[from][spender];
        if (approval != type(uint256).max) {
            if (amount > approval) {
                revert InsufficientAllowance(amount, approval);
            }
            unchecked {
                approval -= amount;
            }
            $approvals.get()[from][spender] = approval;
            emit Approval(from, spender, approval);
        }
        _transfer(from, to, amount);
    }

    /// @dev Internal function for minting
    /// @param account The address to mint to
    /// @param amount The amount to mint
    // slither-disable-next-line dead-code
    function _mint(address account, uint256 amount) internal {
        $totalSupply.set($totalSupply.get() + amount);
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, checked above
            $balances.get()[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    /// @dev Internal function to burn tokens
    /// @param account The account to burn from
    /// @param amount The amount to burn
    // slither-disable-next-line dead-code
    function _burn(address account, uint256 amount) internal {
        uint256 accountBalance = $balances.get()[account];
        if (amount > accountBalance) {
            revert InsufficientBalance(amount, accountBalance);
        }
        $totalSupply.set($totalSupply.get() - amount);
        unchecked {
            $balances.get()[account] = accountBalance - amount;
        }
        emit Transfer(account, address(0), amount);
    }

    /// @dev Internal function to set the mono ticket threshold
    /// @param minTicketEthValue The minimum ticket value
    function _setMonoTicketThreshold(uint256 minTicketEthValue) internal {
        $monoTicketThreshold.set(minTicketEthValue);
    }

    /// @dev Internal function to retrieve the allowance of a given spender
    /// @param owner The owner of the allowance
    /// @param spender The spender of the allowance
    // slither-disable-next-line dead-code
    function _allowance(address owner, address spender) internal view returns (uint256) {
        return $approvals.get()[owner][spender];
    }

    /// @dev Internal function to retrieve the balance of a given account
    /// @param account The account to retrieve the balance of
    // slither-disable-next-line dead-code
    function _balanceOf(address account) internal view returns (uint256) {
        return $balances.get()[account];
    }

    /// @dev Internal function to retrieve the total supply
    // slither-disable-next-line naming-convention
    function _totalSupply() internal view returns (uint256) {
        return $totalSupply.get();
    }

    /// @dev Internal function to retrieve the balance of a given account in underlying
    /// @param account The account to retrieve the balance of in underlying
    /// @param poolInfos List of poolInfos struct containing the supplies
    // slither-disable-next-line dead-code
    function _balanceOfUnderlying(address account, PoolInfo[] memory poolInfos) internal view returns (uint256) {
        uint256 tSupply = _totalSupply();
        if (tSupply == 0) {
            return 0;
        }
        return LibShares.previewRedeem($balances.get()[account], tSupply, _totalUnderlyingSupply(poolInfos));
    }

    /// @dev Internal function retrieve the total underlying supply
    // slither-disable-next-line naming-convention
    function _totalUnderlyingSupply(PoolInfo[] memory poolInfos) internal view returns (uint256) {
        uint256 ethValue = 0;
        for (uint256 i = 0; i < poolInfos.length;) {
            unchecked {
                ethValue += _ethAfterCommission(poolInfos[i]);
                i++;
            }
        }
        return ethValue;
    }

    /// @dev Throws if the address is sanctioned by the sanction list.
    ///      Only reverts if the sanctions checks are active.
    function revertIfSanctioned(address user) internal view {
        if ($sanctionsActive.get()) {
            if (SANCTIONS_ORACLE.isSanctioned(user)) {
                revert AddressSanctioned(user);
            }
        }
    }

    /// @dev Throws if one of the two addresses is sanctioned by the sanction list.
    ///      Only reverts if the sanctions checks are active.
    function revertIfOneIsSanctioned(address user1, address user2) internal view {
        if ($sanctionsActive.get()) {
            if (SANCTIONS_ORACLE.isSanctioned(user1)) {
                revert AddressSanctioned(user1);
            }
            if (SANCTIONS_ORACLE.isSanctioned(user2)) {
                revert AddressSanctioned(user2);
            }
        }
    }
}

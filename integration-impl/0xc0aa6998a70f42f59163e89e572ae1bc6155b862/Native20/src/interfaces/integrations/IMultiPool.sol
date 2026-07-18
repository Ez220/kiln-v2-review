// SPDX-License-Identifier: MIT
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

import {IFeeDispatcher} from "@src/interfaces/integrations/IFeeDispatcher.sol";
import {IvPoolSharesReceiver} from "@src/interfaces/IvPoolSharesReceiver.sol";

/// @notice PoolStakeDetails contains the details of a stake
/// @param poolId Id of the pool
/// @param ethToPool ETH amount sent to the pool
/// @param ethToIntegrator ETH amount going to the integrator
/// @param pSharesFromPool Amount of pool shares received from the pool
/// @param pSharesFromIntegrator Amount of pool shares received from the integrator
struct PoolStakeDetails {
    uint128 poolId;
    uint128 ethToPool;
    uint128 ethToIntegrator;
    uint128 pSharesFromPool;
    uint128 pSharesFromIntegrator;
}

/// @notice PoolExitDetails contains the details of an exit
/// @param poolId Id of the pool
/// @param exitedPoolShares Amount of pool shares exited
struct PoolExitDetails {
    uint128 poolId;
    uint128 exitedPoolShares;
}

/// @title MultiPool (V1) Interface
/// @author 0xvv @ Kiln
/// @notice This contract contains the common functions to all integration contracts.
///         Contains the functions to add pools, activate/deactivate a pool, change the fee of a pool and change the commission distribution.
interface IMultiPool is IFeeDispatcher, IvPoolSharesReceiver {
    /// @notice Emitted when vPool shares are received
    /// @param vPool Address of the vPool sending the shares
    /// @param poolId Id of the pool in the integrations contract
    /// @param amount The amount of vPool shares received
    event VPoolSharesReceived(address vPool, uint256 poolId, uint256 amount);

    /// @notice Emitted when a vPool in enabled or disabled
    /// @param poolAddress The new pool address
    /// @param id Id of the pool
    /// @param isActive whether the pool can be staked to or not
    event PoolActivation(address poolAddress, uint256 id, bool isActive);

    /// @notice Emitted when a vPool address is added to vPools
    /// @param poolAddress The new pool address
    /// @param id Id of the pool
    event PoolAdded(address poolAddress, uint256 id);

    /// @notice Emitted when the integrator fee is changed
    /// @param poolId Id of the pool
    /// @param operatorFeeBps The new fee in basis points
    event SetFee(uint256 poolId, uint256 operatorFeeBps);

    /// @notice Emitted when the display name is changed
    /// @param name The new name
    event SetName(string name);

    /// @notice Emitted when the display symbol is changed
    /// @param symbol The new display symbol
    event SetSymbol(string symbol);

    /// @notice Emitted when the max commission is set
    /// @param maxCommission The new max commission
    event SetMaxCommission(uint256 maxCommission);

    /// @notice Emitted when the deposits are paused or unpaused
    /// @param isPaused Whether the deposits are paused or not
    event SetDepositsPaused(bool isPaused);

    /// @notice Emitted when staking occurs, contains the details for all the pools
    /// @param staker The address providing the funds
    /// @param recipient The address receiving the tokens
    /// @param depositedEth The amount of ETH staked
    /// @param mintedTokens The amount of tokens minted
    /// @param stakeDetails Array of details for each pool, contains the pool id, the amount of ETH sent to the pool,
    ///                     the amount of ETH for the integrator, the amount of pool shares received from the pool and
    ///                     the amount of pools shares bought from the integrator
    event Stake(
        address indexed staker, address indexed recipient, uint128 depositedEth, uint128 mintedTokens, PoolStakeDetails[] stakeDetails
    );

    /// @notice Emitted when an exit occurs, contains the details for all the pools
    /// @param staker The address exiting
    /// @param exitedTokens The amount of tokens exited
    /// @param exitDetails Array of details for each pool, contains the pool id and the amount of pool shares exited
    event Exit(address indexed staker, uint128 exitedTokens, PoolExitDetails[] exitDetails);

    /// @notice Emitted when the commission is distributed via a manual call
    /// @param poolId Id of the pool
    /// @param shares Amount of pool shares exited
    /// @param weights Array of weights for each recipient
    /// @param recipients Array of recipients
    event ExitedCommissionShares(uint256 indexed poolId, uint256 shares, uint256[] weights, address[] recipients);

    /// @notice Emitted when the authorizer is changed
    /// @param authorizer The new authorizer
    event SetAuthorizer(address authorizer);

    /// @notice Thrown on stake if deposits are paused
    error DepositsPaused();

    /// @notice Thrown when trying to stake but the sum of amounts is not equal to the msg.value
    /// @param sum Sum of amounts in the list
    /// @param msgValue Amount of ETH sent
    error InvalidAmounts(uint256 sum, uint256 msgValue);

    /// @notice Thrown when trying to init the contract without providing a pool address
    error EmptyPoolList();

    /// @notice Thrown when trying to change the fee but there are integrator pool shares left to sell
    /// @param ethLeft The ETH value of pool shares left to sell
    /// @param id Id of the pool
    error OutstandingCommission(uint256 ethLeft, uint256 id);

    /// @notice Thrown when trying to add a Pool that is already registered in the contract
    /// @param newPool The pool address
    error PoolAlreadyRegistered(address newPool);

    /// @notice Thrown when trying to deposit to a disabled pool
    /// @param poolId Id of the pool
    error PoolDisabled(uint256 poolId);

    /// @notice Thrown when trying the pool shares callback is called by an address that is not registered
    /// @param poolAddress The pool address
    error NotARegisteredPool(address poolAddress);

    /// @notice Emitted when a pool transfer does not return true.
    /// @param id The id of the pool.
    error PoolTransferFailed(uint256 id);

    /// @notice Thrown when passing an invalid poolId
    /// @param poolId Invalid pool id
    error InvalidPoolId(uint256 poolId);

    /// @notice Thrown when the commission underflow when lowering the fee
    /// @notice To avoid this, the integrator can call exitCommissionShares before lowering the fee or wait for the integrator shares to be sold
    error CommissionPaidUnderflow();

    /// @notice Thrown when minting a null amount of token
    error ZeroTokenMint();

    /// @notice Thrown when trying to see a fee over the max fee set at initialization
    error FeeOverMax(uint256 maxFeeBps);

    /// @notice Thrown when trying to call the callback outside of the minting process
    error CallbackNotFromMinting();

    /// @notice Thrown when trying to exit the commission pool shares but there are no shares to exit
    error NoSharesToExit(uint256 poolId);

    /// @notice Thrown when the signed authorization is invalid
    /// @param rights The rights that were being applied
    /// @param account The account that was being updated
    /// @param expiration The expiration of the authorization
    /// @param nonce The nonce of the authorization
    /// @param v The recovery id of the signature
    /// @param r The r component of the signature
    /// @param s The s component of the signature
    error InvalidSignedAuthorization(uint248 rights, address account, uint256 expiration, uint256 nonce, uint8 v, bytes32 r, bytes32 s);

    /// @notice Allows the integrator to change the fee.
    /// @dev Reverts if there are unsold integrator pool shares.
    /// @param poolId vPool id
    /// @param newFeeBps The new fee in basis points.
    function changeFee(uint256 poolId, uint256 newFeeBps) external;

    /// @notice Allows the admin to change the fee sharing upon withdrawal.
    /// @param recipients The list of fee recipients.
    /// @param splits List of each recipient share in basis points.
    function changeSplit(address[] calldata recipients, uint256[] calldata splits) external;

    /// @notice Allows the integrator to add a vPool.
    /// @dev Reverts if the pool is already in the pools list.
    /// @param newPool The address of the new vPool.
    /// @param fee The fee to be applied to rewards from this vPool, in basis points.
    function addPool(address newPool, uint256 fee) external;

    /// @notice Allows the integrator to exit the integrator pool shares of a vPool.
    /// @param poolId The id of the vPool.
    function exitCommissionShares(uint256 poolId) external;

    /// @notice Allows the integrator to pause and unpause deposits only.
    /// @param isPaused Whether the deposits are paused or not.
    function pauseDeposits(bool isPaused) external;

    /// @notice Sets the default rights for all the accounts
    /// @param rights The new default rights
    function setDefaultRights(uint248 rights) external;

    /// @notice Sets the authorizer
    /// @param _authorizer The new authorizer
    function setAuthorizer(address _authorizer) external;

    /// @notice Authorizes an account
    /// @dev Only the authorizer and the admin can call this function
    /// @param rights The rights to apply
    function authorize(uint248 rights, address account) external;

    /// @notice Authorizes an account with an EIP712 signature
    /// @dev Anyone can call this function
    /// @param rights The rights to apply
    /// @param account The account to apply the rights to
    /// @param expiration The expiration of the authorization
    /// @param nonce The nonce of the authorization
    /// @param v The recovery id of the signature
    /// @param r The r component of the signature
    /// @param s The s component of the signature
    function authorize(uint248 rights, address account, uint256 expiration, uint256 nonce, uint8 v, bytes32 r, bytes32 s) external;

    /// @notice Clears the rights of an account
    /// @param account The account whose rights to clear
    function clearAuthorizations(address account) external;

    /// @notice Increments the nonce of an account
    /// @param account The account whose nonce to increase
    function incrementNonce(address account) external;

    /// @notice Returns the list of vPools.
    /// @return vPools The addresses of the pool contract.
    function pools() external view returns (address[] memory vPools);

    /// @notice Returns the current fee in basis points for the given pool.
    /// @return feeBps The current fee in basis points.
    /// @param id Id of the pool
    function getFee(uint256 id) external view returns (uint256 feeBps);

    /// @notice Returns true if the pool is active, false otherwise
    /// @param poolId The id of the vPool.
    function getPoolActivation(uint256 poolId) external view returns (bool);

    /// @notice Returns the ETH value of pool shares for a given pool.
    /// @param poolId The id of the vPool.
    /// @return The ETH value of pool shares for a given pool.
    function stakedEthValue(uint256 poolId) external view returns (uint256);

    /// @notice Returns the ETH value for a pool, fees deducted.
    /// @param poolId The id of the vPool.
    /// @return The ETH value for a pool, fees deducted.
    function ethAfterCommission(uint256 poolId) external view returns (uint256);

    /// @notice Returns the ETH value of integrator pool shares earned overall.
    /// @param poolId The id of the vPool.
    /// @return The ETH value of integrator pool shares earned overall.
    function integratorCommissionEarned(uint256 poolId) external view returns (uint256);

    /// @notice Returns the commissionPaid value for a given pool.
    /// @param poolId The id of the vPool.
    /// @return The commissionPaid value for a given pool.
    function getCommissionPaid(uint256 poolId) external view returns (uint256);

    /// @notice Returns the ETH value of integrator pool shares left to sell.
    /// @param poolId The id of the vPool.
    /// @return The ETH value of unsold integrator pool shares.
    function integratorCommissionOwed(uint256 poolId) external view returns (uint256);

    /// @notice Returns the injectedEth value for a given pool.
    /// @param poolId The id of the vPool.
    /// @return The injectedEth value for a given pool.
    function getInjectedEth(uint256 poolId) external view returns (uint256);

    /// @notice Returns the exitedEth value for a given pool.
    /// @param poolId The id of the vPool.
    /// @return The exitedEth value for a given pool.
    function getExitedEth(uint256 poolId) external view returns (uint256);

    /// @notice Returns the number of pool shares for a given pool.
    /// @param poolId The id of the vPool.
    /// @return The number of pool shares for a given pool.
    function getPoolShares(uint256 poolId) external view returns (uint256);

    /// @notice Returns true if deposits are paused, false otherwise
    /// @return Whether deposits are paused or not
    function depositsPaused() external view returns (bool);

    /// @notice Returns the default rights
    /// @return The default rights
    function defaultRights() external view returns (uint248);

    /// @notice Returns the authorizer
    /// @return The authorizer
    function authorizer() external view returns (address);
}

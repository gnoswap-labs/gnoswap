package staker

import (
	"std"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/halt"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	en "gno.land/r/gnoswap/v1/emission"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/referral"
)

const ZERO_ADDRESS = std.Address("")

var (
	stakerAddr        = getRoleAddress(prbac.ROLE_STAKER)
	devOpsAddr        = getRoleAddress(prbac.ROLE_DEVOPS)
	communityPoolAddr = getRoleAddress(prbac.ROLE_COMMUNITY_POOL)
	govStakerAddr     = getRoleAddress(prbac.ROLE_GOV_STAKER)
	protocolFeeAddr   = getRoleAddress(prbac.ROLE_PROTOCOL_FEE)
	adminAddr         = getRoleAddress(prbac.ROLE_ADMIN)
	positionAddr      = getRoleAddress(prbac.ROLE_POSITION)
)

// list of staked positions
type Deposits struct {
	tree *avl.Tree
}

func NewDeposits() *Deposits {
	return &Deposits{
		tree: avl.NewTree(), // positionId -> *Deposit
	}
}

func (self *Deposits) Has(positionId uint64) bool {
	return self.tree.Has(EncodeUint(positionId))
}

func (self *Deposits) Iterate(start uint64, end uint64, fn func(positionId uint64, deposit *Deposit) bool) {
	self.tree.Iterate(EncodeUint(start), EncodeUint(end), func(positionId string, depositI any) bool {
		return fn(DecodeUint(positionId), depositI.(*Deposit))
	})
}

func (self *Deposits) Size() int {
	return self.tree.Size()
}

func (self *Deposits) get(positionId uint64) *Deposit {
	depositI, ok := self.tree.Get(EncodeUint(positionId))
	if !ok {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("positionId(%d) not found", positionId),
		))
	}
	deposit := depositI.(*Deposit)
	return deposit
}

func (self *Deposits) set(positionId uint64, deposit *Deposit) {
	self.tree.Set(EncodeUint(positionId), deposit)
}

func (self *Deposits) remove(positionId uint64) {
	self.tree.Remove(EncodeUint(positionId))
}

type ExternalIncentives struct {
	tree *avl.Tree
}

func NewExternalIncentives() *ExternalIncentives {
	return &ExternalIncentives{
		tree: avl.NewTree(),
	}
}

func (self *ExternalIncentives) Has(incentiveId string) bool {
	return self.tree.Has(incentiveId)
}

func (self *ExternalIncentives) Size() int {
	return self.tree.Size()
}

func (self *ExternalIncentives) get(incentiveId string) *ExternalIncentive {
	incentiveI, ok := self.tree.Get(incentiveId)
	if !ok {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("incentiveId(%s) not found", incentiveId),
		))
	}

	incentive := incentiveI.(*ExternalIncentive)
	return incentive
}

func (self *ExternalIncentives) set(incentiveId string, incentive *ExternalIncentive) {
	self.tree.Set(incentiveId, incentive)
}

func (self *ExternalIncentives) remove(incentiveId string) {
	self.tree.Remove(incentiveId)
}

type Stakers struct {
	tree *avl.Tree // address -> depositId -> *Deposit
}

func NewStakers() *Stakers {
	return &Stakers{
		tree: avl.NewTree(),
	}
}

func (self *Stakers) IterateAll(address std.Address, fn func(depositId uint64, deposit *Deposit) bool) {
	depositTreeI, ok := self.tree.Get(address.String())
	if !ok {
		return
	}
	depositTree := depositTreeI.(*avl.Tree)
	depositTree.Iterate("", "", func(depositId string, depositI any) bool {
		deposit := depositI.(*Deposit)
		return fn(DecodeUint(depositId), deposit)
	})
}

func (self *Stakers) addDeposit(address std.Address, depositId uint64, deposit *Deposit) {
	depositTreeI, ok := self.tree.Get(address.String())
	if !ok {
		depositTree := avl.NewTree()
		self.tree.Set(address.String(), depositTree)
		depositTreeI = depositTree
	}
	depositTree := depositTreeI.(*avl.Tree)
	depositTree.Set(EncodeUint(depositId), deposit)
}

func (self *Stakers) removeDeposit(address std.Address, depositId uint64) {
	depositTreeI, ok := self.tree.Get(address.String())
	if !ok {
		return
	}
	depositTree := depositTreeI.(*avl.Tree)
	depositTree.Remove(EncodeUint(depositId))
}

var (
	// deposits stores deposit information for each positionId
	deposits *Deposits = NewDeposits()

	// externalIncentives stores external incentive information for each incentiveId
	externalIncentives *ExternalIncentives = NewExternalIncentives()

	// stakers stores staker information for each address
	stakers *Stakers = NewStakers()

	// poolTier stores pool tier information
	poolTier *PoolTier

	// totalEmissionSent is the total amount of GNS emission sent from staker to user(and community pool if penalty exists)
	// which includes following
	// 1. reward sent to user (which also includes protocol_fee)
	// 2. penalty sent to community pool
	// 3. unclaimable reward
	totalEmissionSent int64
)

const (
	TIMESTAMP_90DAYS  = int64(7776000)
	TIMESTAMP_180DAYS = int64(15552000)
	TIMESTAMP_365DAYS = int64(31536000)

	MAX_UNIX_EPOCH_TIME = 253402300799 // 9999-12-31 23:59:59

	MUST_EXISTS_IN_TIER_1 = "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000"

	INTERNAL = true
	EXTERNAL = false
)

func init() {
	// init pool tier
	// tier 1
	// ONLY GNOT:GNS 0.3%

	pools.GetOrCreate(MUST_EXISTS_IN_TIER_1)
	poolTier = NewPoolTier(pools, std.ChainHeight(), MUST_EXISTS_IN_TIER_1, en.GetEmission, en.GetHalvingBlocksInRange)
	registerstakerEmissionChangeCallback()
}

func registerstakerEmissionChangeCallback() {
	en.SetGnsStakerEmissionChangeCallback(cross, func(emission int64) {
		func(cur realm) {
			stakerEmissionChangeCallback(emission)
		}(cross)
	})
}

// StakeToken stakes an LP token into the staker contract. It transfer the LP token
// ownership to the staker contract.
//
// State Transition:
//  1. Token ownership transfers from user -> staker contract
//  2. Position operator changes to caller
//  3. Deposit record is created and stored
//  4. Internal warm up amount is set to 0
//
// Requirements:
//  1. Token must have non-zero liquidity
//  2. Pool must have either internal or external incentives
//  3. Caller must be token owner or approved operator
//
// Parameters:
//   - positionId (uint64): The ID of the LP token to stake
//
// Returns:
//   - poolPath (string): The path of the pool to which the LP token is staked
//   - token0Amount (string): The amount of token0 in the LP token
//   - token1Amount (string): The amount of token1 in the LP token
//
// ref: https://docs.gnoswap.io/contracts/staker/staker.gno#staketoken
func StakeToken(cur realm, positionId uint64, referrer string) (string, string, string) {
	halt.AssertIsNotHaltedStaker()

	assertIsNotStaked(positionId)

	en.MintAndDistributeGns(cross)

	previousRealm := std.PreviousRealm()
	caller := previousRealm.Address()
	currentHeight := std.ChainHeight()
	owner := gnft.MustOwnerOf(positionIdFrom(positionId))

	success := referral.TryRegister(cross, caller, referrer)
	actualReferrer := referrer
	if !success {
		actualReferrer = referral.GetReferral(caller.String())
	}

	token0Amount, token1Amount, err := getPositionStakeTokenAmount(positionId, owner, caller)
	if err != nil {
		panic(err.Error())
	}

	// check pool path from positionId
	poolPath := pn.PositionGetPositionPoolKey(positionId)
	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(makeErrorWithDetails(
			errNonIncentivizedPool,
			ufmt.Sprintf("can not stake position to non existing pool(%s)", poolPath),
		))
	}
	liquidity := getLiquidity(positionId)

	tickLower, tickUpper := getTickOf(positionId)

	// staked status
	deposit := &Deposit{
		owner:             caller,
		stakeTimestamp:    time.Now().Unix(),
		stakeHeight:       currentHeight,
		targetPoolPath:    poolPath,
		tickLower:         tickLower,
		tickUpper:         tickUpper,
		liquidity:         liquidity,
		lastCollectHeight: currentHeight,
		warmups:           instantiateWarmup(currentHeight),
	}

	currentTick := pl.PoolGetSlot0Tick(poolPath)

	deposits.set(positionId, deposit)
	stakers.addDeposit(caller, positionId, deposit)

	// transfer NFT ownership to staker contract
	if err := transferDeposit(positionId, owner, caller, stakerAddr); err != nil {
		panic(err.Error())
	}

	// after transfer, set caller(user) as position operator (to collect fee and reward)
	pn.SetPositionOperator(cross, positionId, caller)

	signedLiquidity := i256.FromUint256(liquidity)
	isInRange := false
	poolTier.cacheReward(currentHeight, pools)

	if pn.PositionIsInRange(positionId) {
		isInRange = true
		pool.modifyDeposit(signedLiquidity, currentHeight, currentTick)
	}
	// historical tick must be set regardless of the deposit's range
	pool.historicalTick.set(currentHeight, currentTick)

	// this could happen because of how position stores the ticks.
	// ticks are negated if the token1 < token0
	upperTick := pool.ticks.Get(tickUpper)
	lowerTick := pool.ticks.Get(tickLower)

	upperTick.modifyDepositUpper(currentHeight, currentTick, signedLiquidity)
	lowerTick.modifyDepositLower(currentHeight, currentTick, signedLiquidity)

	std.Emit(
		"StakeToken",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"positionId", formatUint(positionId),
		"poolPath", poolPath,
		"amount0", token0Amount,
		"amount1", token1Amount,
		"liquidity", liquidity.ToString(),
		"positionUpperTick", formatInt(int64(tickUpper)),
		"positionLowerTick", formatInt(int64(tickLower)),
		"currentTick", formatInt(int64(currentTick)),
		"isInRange", formatBool(isInRange),
		"referrer", actualReferrer,
	)

	return poolPath, token0Amount, token1Amount
}

// calculateStakeData validates staking requirements and prepares staking data.
//
// It checks if the token is already staked, verifies ownership, and ensures the pool has incentives.
// If successful, it returns the staking data; otherwise, it returns an error.
//
// Parameters:
//   - positionId: The ID of the LP token to stake
//   - owner: The owner of the LP token
//   - caller: The caller of the staking operation
//
// Returns:
//   - *stakeResult: The staking data if successful
//   - error: An error if any validation fails
func getPositionStakeTokenAmount(positionId uint64, owner, caller std.Address) (string, string, error) {
	exist := deposits.Has(positionId)
	if exist {
		return "", "", errAlreadyStaked
	}

	if err := hasTokenOwnership(owner, caller); err != nil {
		return "", "", err
	}

	if err := tokenHasLiquidity(positionId); err != nil {
		return "", "", err
	}

	poolPath := pn.PositionGetPositionPoolKey(positionId)
	if err := poolHasIncentives(poolPath); err != nil {
		return "", "", err
	}

	token0Amount, token1Amount := getTokenPairBalanceFromPosition(poolPath, positionId)

	return token0Amount, token1Amount, nil
}

// transferDeposit transfers the ownership of a deposit token (NFT) to a new owner.
//
// This function ensures that the caller is not the same as the recipient (`to`).
// If the caller is not the owner or the recipient, it attempts to transfer the NFT
// ownership from the current owner to the recipient.
//
// Parameters:
// - positionId (uint64): The unique identifier of the token (NFT) to transfer.
// - owner (std.Address): The current owner of the token.
// - caller (std.Address): The address attempting to initiate the transfer.
// - to (std.Address): The address to which the token will be transferred.
//
// Returns:
//   - error: Returns an error if the caller is the same as the recipient (`to`).
//     Otherwise, it delegates the transfer to `gnft.TransferFrom` and returns any error
//     that may occur during the transfer.
func transferDeposit(positionId uint64, owner, caller, to std.Address) error {
	// if owner is the same as to, when mint and stake, it will be the same address
	if owner == to {
		return nil
	}

	if caller == to {
		return ufmt.Errorf(
			"%v: only owner(%s) can transfer positionId(%d), called from %s",
			errNoPermission, owner, positionId, caller,
		)
	}

	// transfer NFT ownership
	return gnft.TransferFrom(cross, owner, to, positionIdFrom(positionId))
}

////////////////////////////////////////////////////////////

// CollectReward harvests accumulated rewards for a staked position. This includes both
// internal GNS emission and external incentive rewards.
//
// State Transition:
//  1. Warm-up amounts are clears for both internal and external rewards
//  2. Reward tokens are transferred to the owner
//  3. Penalty fees are transferred to protocol/community addresses
//  4. GNS balance is recalculated
//
// Requirements:
//   - Contract must not be halted
//   - Caller must be the position owner
//   - Position must be staked (have a deposit record)
//
// Parameters:
//   - positionId (uint64): The ID of the LP token to collect rewards from
//   - unwrapResult (bool): Whether to unwrap WUGNOT to GNOT
//
// Returns:
//   - poolPath (string): The path of the pool to which the LP token is staked
//
// ref: https://docs.gnoswap.io/contracts/staker/staker.gno#collectreward
func CollectReward(cur realm, positionId uint64, unwrapResult bool) (string, string, map[string]int64, map[string]int64) {
	caller := std.PreviousRealm().Address()
	halt.AssertIsNotHaltedStaker()
	halt.AssertIsNotHaltedWithdraw()

	assertIsDepositor(caller, positionId)

	deposit := deposits.get(positionId)

	en.MintAndDistributeGns(cross)

	currentHeight := std.ChainHeight()
	previousRealm := std.PreviousRealm()
	// get all internal and external rewards
	reward := calcPositionReward(currentHeight, positionId)

	// update lastCollectHeight to current height
	deposit.lastCollectHeight = currentHeight

	// transfer external rewards to user
	externalReward := reward.External
	toUserExternalReward := make(map[string]int64)
	toUserExternalPenalty := make(map[string]int64)
	for incentiveId, rewardAmount := range externalReward {
		incentive := externalIncentives.get(incentiveId).Clone()
		if !incentive.IsStarted(currentHeight) {
			continue
		}

		if incentive.rewardAmount < rewardAmount {
			// Emit event for insufficient reward and skip this incentive
			std.Emit(
				"InsufficientExternalReward",
				"prevAddr", previousRealm.Address().String(),
				"prevRealm", previousRealm.PkgPath(),
				"positionId", formatUint(positionId),
				"incentiveId", incentiveId,
				"requiredAmount", formatInt(rewardAmount),
				"availableAmount", formatInt(incentive.rewardAmount),
				"blockHeight", formatInt(currentHeight),
			)
			continue
		}

		// process external reward to user
		incentive.rewardAmount = safeSubInt64(incentive.rewardAmount, rewardAmount)
		rewardToken := incentive.rewardToken
		toUserExternalReward[rewardToken] = safeAddInt64(toUserExternalReward[rewardToken], rewardAmount)
		toUser, feeAmount, err := handleUnStakingFee(rewardToken, int64(rewardAmount), false, positionId, incentive.targetPoolPath)
		if err != nil {
			panic(err.Error())
		}

		std.Emit(
			"ProtocolFeeExternalReward",
			"prevAddr", previousRealm.Address().String(),
			"prevRealm", previousRealm.PkgPath(),
			"fromPositionId", formatUint(positionId),
			"fromPoolPath", incentive.targetPoolPath,
			"feeTokenPath", rewardToken,
			"feeAmount", formatInt(feeAmount),
		)
		if toUser > 0 {
			common.Transfer(cross, rewardToken, deposit.owner, toUser)
		}

		// process external penalty
		externalPenalty := reward.ExternalPenalty[incentiveId]
		incentive.rewardAmount = safeSubInt64(incentive.rewardAmount, externalPenalty)
		incentive.rewardLeft = safeAddInt64(incentive.rewardLeft, externalPenalty)
		toUserExternalPenalty[rewardToken] = safeAddInt64(toUserExternalPenalty[rewardToken], externalPenalty)

		// update
		externalIncentives.set(incentiveId, incentive)

		// unwrap if necessary
		if unwrapResult && rewardToken == WUGNOT_PATH {
			unwrap(toUser)
		}
		std.Emit(
			"CollectReward",
			"prevAddr", previousRealm.Address().String(),
			"prevRealm", previousRealm.PkgPath(),
			"positionId", formatUint(positionId),
			"poolPath", deposit.targetPoolPath,
			"recipient", deposit.owner.String(),
			"incentiveId", incentiveId,
			"rewardToken", rewardToken,
			"rewardAmount", formatInt(rewardAmount),
			"rewardToUser", formatInt(toUser),
			"rewardToFee", formatInt(int64(rewardAmount)-toUser),
			"rewardPenalty", formatInt(externalPenalty),
			"isRequestUnwrap", formatBool(unwrapResult),
		)
	}

	communityPoolAddr := getRoleAddress(prbac.ROLE_COMMUNITY_POOL)

	// internal reward to user
	toUser, feeAmount, err := handleUnStakingFee(GNS_PATH, int64(reward.Internal), true, positionId, deposit.targetPoolPath)
	if err != nil {
		panic(err.Error())
	}

	std.Emit(
		"ProtocolFeeInternalReward",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"fromPositionId", formatUint(positionId),
		"fromPoolPath", deposit.targetPoolPath,
		"feeTokenPath", GNS_PATH,
		"feeAmount", formatInt(feeAmount),
	)

	if toUser > 0 {
		// internal reward to user
		totalEmissionSent = safeAddInt64(totalEmissionSent, toUser)
		gns.Transfer(cross, deposit.owner, toUser)

		// internal penalty to community pool
		totalEmissionSent = safeAddInt64(totalEmissionSent, reward.InternalPenalty)
		gns.Transfer(cross, communityPoolAddr, int64(reward.InternalPenalty))
	}

	unClaimableInternal := processUnClaimableReward(deposit.targetPoolPath, currentHeight)
	if unClaimableInternal > 0 {
		// internal unClaimable to community pool
		totalEmissionSent = safeAddInt64(totalEmissionSent, unClaimableInternal)
		gns.Transfer(cross, communityPoolAddr, int64(unClaimableInternal))
	}

	std.Emit(
		"CollectReward",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"positionId", formatUint(positionId),
		"poolPath", deposit.targetPoolPath,
		"recipient", deposit.owner.String(),
		"rewardToken", GNS_PATH,
		"rewardAmount", formatInt(reward.Internal),
		"rewardToUser", formatInt(toUser),
		"rewardToFee", formatInt(int64(reward.Internal)-toUser),
		"rewardPenalty", formatInt(reward.InternalPenalty),
		"rewardUnClaimableAmount", formatInt(unClaimableInternal),
	)

	return formatInt(toUser), formatInt(reward.InternalPenalty), toUserExternalReward, toUserExternalPenalty
}

// UnStakeToken withdraws an LP token from staking, collecting all pending rewards
// and returning the token to its original owner.
//
// State transitions:
//  1. All pending rewards are collected (calls CollectReward)
//  2. Token ownership transfers back to original owner
//  3. Position operator is cleared
//  4. All staking state is cleaned up:
//     - Deposit record removed
//     - Position GNS balances cleared
//     - Warm-up amounts cleared
//     - Position removed from reward tracking
//
// Requirements:
// - Contract must not be halted
// - Position must be staked (have deposit record)
// - Rewards are automatically collected before unStaking
//
// Params:
// - positionId (uint64): ID of the staked LP token
// - unwrapResult (bool): If true, unwraps any WUGNOT rewards to GNOT
//
// Returns:
// - poolPath (string): The pool path associated with the unstaked position
// - token0Amount (string): Final amount of token0 in the position
// - token1Amount (string): Final amount of token1 in the position
//
// ref: https://docs.gnoswap.io/contracts/staker/staker.gno#unstaketoken
func UnStakeToken(cur realm, positionId uint64, unwrapResult bool) (string, string, string) { // poolPath, token0Amount, token1Amount
	caller := std.PreviousRealm().Address()
	halt.AssertIsNotHaltedStaker()
	halt.AssertIsNotHaltedWithdraw()
	assertIsDepositor(caller, positionId)

	deposit := deposits.get(positionId)

	// unStaked status
	poolPath := deposit.targetPoolPath

	// claim All Rewards
	CollectReward(cur, positionId, unwrapResult)
	token0Amount, token1Amount := getTokenPairBalanceFromPosition(poolPath, positionId)

	if err := applyUnStake(positionId); err != nil {
		panic(err)
	}

	// transfer NFT ownership to origin owner
	gnft.TransferFrom(cross, stakerAddr, deposit.owner, positionIdFrom(positionId))
	pn.SetPositionOperator(cross, positionId, ZERO_ADDRESS)

	previousRealm := std.PreviousRealm()
	std.Emit(
		"UnStakeToken",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"positionId", formatUint(positionId),
		"poolPath", poolPath,
		"isRequestUnwrap", formatBool(unwrapResult),
		"from", stakerAddr.String(),
		"to", deposit.owner.String(),
		"amount0", token0Amount,
		"amount1", token1Amount,
	)

	return poolPath, token0Amount, token1Amount
}

func applyUnStake(positionId uint64) error {
	deposit := deposits.get(positionId)
	pool, ok := pools.Get(deposit.targetPoolPath)
	if !ok {
		return ufmt.Errorf(
			"%v: pool(%s) does not exist",
			errDataNotFound, deposit.targetPoolPath,
		)
	}

	currentHeight := std.ChainHeight()
	currentTick := pl.PoolGetSlot0Tick(deposit.targetPoolPath)
	signedLiquidity := i256.FromUint256(deposit.liquidity)
	signedLiquidity = signedLiquidity.Neg(signedLiquidity)
	if pn.PositionIsInRange(positionId) {
		pool.modifyDeposit(signedLiquidity, currentHeight, currentTick)
	}

	upperTick := pool.ticks.Get(deposit.tickUpper)
	lowerTick := pool.ticks.Get(deposit.tickLower)
	upperTick.modifyDepositUpper(currentHeight, currentTick, signedLiquidity)
	lowerTick.modifyDepositLower(currentHeight, currentTick, signedLiquidity)

	deposits.remove(positionId)
	stakers.removeDeposit(deposit.owner, positionId)

	owner := gnft.MustOwnerOf(positionIdFrom(positionId))
	caller := std.PreviousRealm().Address()

	_, _, err := getPositionStakeTokenAmount(positionId, owner, caller)
	if err != nil {
		return err
	}

	return nil
}

// hasTokenOwnership validates that the caller has permission to operate the token.
func hasTokenOwnership(owner, caller std.Address) error {
	isCallerOwner := owner == caller
	isStakerOwner := owner == stakerAddr

	if !isCallerOwner && !isStakerOwner {
		return errNoPermission
	}

	return nil
}

// poolHasIncentives checks if the pool has any active incentives (internal or external).
func poolHasIncentives(poolPath string) error {
	pool, ok := pools.Get(poolPath)
	if !ok {
		return ufmt.Errorf(
			"%v: can not stake position to non existent pool(%s)",
			errNonIncentivizedPool, poolPath,
		)
	}
	hasInternal := poolTier.IsInternallyIncentivizedPool(poolPath)
	hasExternal := pool.IsExternallyIncentivizedPool()
	if hasInternal == false && hasExternal == false {
		return ufmt.Errorf(
			"%v: can not stake position to non incentivized pool(%s)",
			errNonIncentivizedPool, poolPath,
		)
	}
	return nil
}

// tokenHasLiquidity checks if the target positionId has non-zero liquidity
func tokenHasLiquidity(positionId uint64) error {
	liquidity := getLiquidity(positionId)

	if liquidity.Lte(u256.Zero()) {
		return ufmt.Errorf(
			"%v: positionId(%d) has no liquidity",
			errZeroLiquidity, positionId,
		)
	}
	return nil
}

func getLiquidity(positionId uint64) *u256.Uint {
	liq := pn.PositionGetPositionLiquidityStr(positionId)
	return u256.MustFromDecimal(liq)
}

func getTokenPairBalanceFromPosition(poolPath string, positionId uint64) (string, string) {
	position := pn.MustGetPosition(positionId)
	
	return position.Token0Balance().ToString(), position.Token1Balance().ToString()
}

func getTickOf(positionId uint64) (int32, int32) {
	tickLower := pn.PositionGetPositionTickLower(positionId)
	tickUpper := pn.PositionGetPositionTickUpper(positionId)
	if tickUpper < tickLower {
		panic(ufmt.Sprintf("tickUpper(%d) is less than tickLower(%d)", tickUpper, tickLower))
	}
	return tickLower, tickUpper
}

package staker

import (
	"std"
	"time"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/v1/gnft"

	en "gno.land/r/gnoswap/emission"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/referral"
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

// Deposits manages all staked positions.
type Deposits struct {
	tree *avl.Tree
}

// NewDeposits creates a new Deposits instance.
func NewDeposits() *Deposits {
	return &Deposits{
		tree: avl.NewTree(), // positionId -> *Deposit
	}
}

// Has checks if a position ID exists in deposits.
func (self *Deposits) Has(positionId uint64) bool {
	return self.tree.Has(EncodeUint(positionId))
}

// Iterate traverses deposits within the specified range.
func (self *Deposits) Iterate(start uint64, end uint64, fn func(positionId uint64, deposit *Deposit) bool) {
	self.tree.Iterate(EncodeUint(start), EncodeUint(end), func(positionId string, depositI any) bool {
		dpst := retrieveDeposit(depositI)
		return fn(DecodeUint(positionId), dpst)
	})
}

// Size returns the number of deposits.
func (self *Deposits) Size() int {
	return self.tree.Size()
}

// get retrieves a deposit by position ID.
func (self *Deposits) get(positionId uint64) *Deposit {
	depositI, ok := self.tree.Get(EncodeUint(positionId))
	if !ok {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("positionId(%d) not found", positionId),
		))
	}
	return retrieveDeposit(depositI)
}

// retrieveDeposit safely casts data to Deposit type.
func retrieveDeposit(data any) *Deposit {
	deposit, ok := data.(*Deposit)
	if !ok {
		panic("failed to cast value to *Deposit")
	}
	return deposit
}

// set stores a deposit for a position ID.
func (self *Deposits) set(positionId uint64, deposit *Deposit) {
	self.tree.Set(EncodeUint(positionId), deposit)
}

// remove deletes a deposit by position ID.
func (self *Deposits) remove(positionId uint64) {
	self.tree.Remove(EncodeUint(positionId))
}

// ExternalIncentives manages external incentive programs.
type ExternalIncentives struct {
	tree *avl.Tree
}

// NewExternalIncentives creates a new ExternalIncentives instance.
func NewExternalIncentives() *ExternalIncentives {
	return &ExternalIncentives{
		tree: avl.NewTree(),
	}
}

// Has checks if an incentive ID exists.
func (self *ExternalIncentives) Has(incentiveId string) bool { return self.tree.Has(incentiveId) }

// Size returns the number of external incentives.
func (self *ExternalIncentives) Size() int { return self.tree.Size() }

// get retrieves an external incentive by ID.
func (self *ExternalIncentives) get(incentiveId string) *ExternalIncentive {
	incentiveI, ok := self.tree.Get(incentiveId)
	if !ok {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("incentiveId(%s) not found", incentiveId),
		))
	}

	incentive, ok := incentiveI.(*ExternalIncentive)
	if !ok {
		panic("failed to cast value to *ExternalIncentive")
	}
	return incentive
}

// set stores an external incentive.
func (self *ExternalIncentives) set(incentiveId string, incentive *ExternalIncentive) {
	self.tree.Set(incentiveId, incentive)
}

// remove deletes an external incentive by ID.
func (self *ExternalIncentives) remove(incentiveId string) {
	self.tree.Remove(incentiveId)
}

// Stakers manages deposits by staker address.
type Stakers struct {
	tree *avl.Tree // address -> depositId -> *Deposit
}

// NewStakers creates a new Stakers instance.
func NewStakers() *Stakers {
	return &Stakers{
		tree: avl.NewTree(),
	}
}

// IterateAll traverses all deposits for a specific address.
func (self *Stakers) IterateAll(address std.Address, fn func(depositId uint64, deposit *Deposit) bool) {
	depositTreeI, ok := self.tree.Get(address.String())
	if !ok {
		return
	}
	depositTree := retrieveDepositTree(depositTreeI)
	depositTree.Iterate("", "", func(depositId string, depositI any) bool {
		deposit, ok := depositI.(*Deposit)
		if !ok {
			panic("failed to cast value to *Deposit")
		}
		return fn(DecodeUint(depositId), deposit)
	})
}

// addDeposit adds a deposit for a staker address.
func (self *Stakers) addDeposit(address std.Address, depositId uint64, deposit *Deposit) {
	depositTreeI, ok := self.tree.Get(address.String())
	if !ok {
		depositTree := avl.NewTree()
		self.tree.Set(address.String(), depositTree)
		depositTreeI = depositTree
	}

	depositTree := retrieveDepositTree(depositTreeI)
	depositTree.Set(EncodeUint(depositId), deposit)
}

// removeDeposit removes a deposit for a staker address.
func (self *Stakers) removeDeposit(address std.Address, depositId uint64) {
	depositTreeI, ok := self.tree.Get(address.String())
	if !ok {
		return
	}

	depositTree := retrieveDepositTree(depositTreeI)
	depositTree.Remove(EncodeUint(depositId))
}

// retrieveDepositTree safely casts data to AVL tree type.
func retrieveDepositTree(data any) *avl.Tree {
	depositTree, ok := data.(*avl.Tree)
	if !ok {
		panic("failed to cast depositTree to *avl.Tree")
	}
	return depositTree
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

	MUST_EXISTS_IN_TIER_1 = "gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000"

	INTERNAL = true
	EXTERNAL = false
)

// init initializes the staker contract with tier 1 pool.
func init() {
	// Initialize tier 1 with GNOT:GNS 0.3% pool

	pools.GetOrCreate(MUST_EXISTS_IN_TIER_1)

	poolTier = NewPoolTier(
		pools,
		std.ChainHeight(),
		time.Now().Unix(),
		MUST_EXISTS_IN_TIER_1,
		en.GetStakerEmissionAmountPerSecond,
		en.GetStakerEmissionAmountPerSecondInRange,
	)
}

// StakeToken stakes an LP position NFT to earn rewards.
//
// Transfers position NFT to staker and begins reward accumulation.
// Eligible for internal incentives (GNS emission) and external rewards.
// Position must have liquidity and be in eligible pool tier.
//
// Parameters:
//   - positionId: LP position NFT token ID to stake
//   - referrer: Optional referral address for tracking
//
// Returns:
//   - poolPath: Pool identifier (token0:token1:fee)
//   - token0Amount: Current token0 balance in position
//   - token1Amount: Current token1 balance in position
//
// Requirements:
//   - Caller must own the position NFT
//   - Position must have active liquidity
//   - Pool must be in tier 1, 2, or 3
//   - Position not already staked
//
// Note: Out-of-range positions earn no rewards but can be staked.
func StakeToken(cur realm, positionId uint64, referrer string) (string, string, string) {
	halt.AssertIsNotHaltedStaker()

	assertIsNotStaked(positionId)

	en.MintAndDistributeGns(cross)

	previousRealm := std.PreviousRealm()
	caller := previousRealm.Address()
	owner := gnft.MustOwnerOf(positionIdFrom(positionId))
	currentTime := time.Now().Unix()

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
		owner:           caller,
		stakeTimestamp:  currentTime,
		stakeTime:       currentTime,
		targetPoolPath:  poolPath,
		tickLower:       tickLower,
		tickUpper:       tickUpper,
		liquidity:       liquidity,
		lastCollectTime: currentTime,
		warmups:         instantiateWarmup(currentTime),
	}

	currentTick := pl.GetSlot0Tick(poolPath)

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
	poolTier.cacheReward(currentTime, currentTime, pools)

	if pn.PositionIsInRange(positionId) {
		isInRange = true
		pool.modifyDeposit(signedLiquidity, currentTime, currentTick)
	}
	// historical tick must be set regardless of the deposit's range
	pool.historicalTick.set(currentTime, currentTick)

	// This could happen because of how position stores the ticks.
	// Ticks are negated if the token1 < token0.
	upperTick := pool.ticks.Get(tickUpper)
	lowerTick := pool.ticks.Get(tickLower)

	upperTick.modifyDepositUpper(currentTime, signedLiquidity)
	lowerTick.modifyDepositLower(currentTime, signedLiquidity)

	std.Emit(
		"StakeToken",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"positionId", formatUint(positionId),
		"poolPath", poolPath,
		"amount0", token0Amount,
		"amount1", token1Amount,
		"liquidity", liquidity.ToString(),
		"positionUpperTick", formatAnyInt(tickUpper),
		"positionLowerTick", formatAnyInt(tickLower),
		"currentTick", formatAnyInt(currentTick),
		"isInRange", formatBool(isInRange),
		"referrer", actualReferrer,
	)

	return poolPath, token0Amount, token1Amount
}

// getPositionStakeTokenAmount validates staking requirements and returns token amounts.
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

// transferDeposit transfers deposit ownership to a new address.
//
// Manages NFT custody during staking operations.
// Transfers ownership to staker contract for reward eligibility.
// Handles special cases for mint-and-stake operations.
//
// Parameters:
//   - positionId: The ID of the position NFT to transfer
//   - owner: The current owner of the position
//   - caller: The entity initiating the transfer
//   - to: The recipient address (usually staker contract)
//
// Security Features:
//   - Prevents self-transfer exploits
//   - Validates ownership before transfer
//   - Atomic operation with staking
//   - No transfer if owner == to (mint & stake case)
//
// Returns:
//   - nil: If owner and recipient are same (mint-and-stake)
//   - error: If caller unauthorized or transfer fails
//
// NFT remains locked in staker until unstaking.
// Otherwise delegates the transfer to `gnft.TransferFrom`.
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
// CollectReward claims accumulated rewards without unstaking.
//
// Parameters:
//   - positionId: LP position NFT token ID
//   - unwrapResult: if true, unwraps WUGNOT to GNOT
//
// Returns poolPath, gnsAmount, externalRewards map, externalPenalties map.
func CollectReward(cur realm, positionId uint64, unwrapResult bool) (string, string, map[string]int64, map[string]int64) {
	caller := std.PreviousRealm().Address()
	halt.AssertIsNotHaltedStaker()
	halt.AssertIsNotHaltedWithdraw()

	assertIsDepositor(caller, positionId)

	deposit := deposits.get(positionId)

	en.MintAndDistributeGns(cross)

	currentTime := time.Now().Unix()
	blockHeight := std.ChainHeight()
	previousRealm := std.PreviousRealm()
	// get all internal and external rewards
	reward := calcPositionReward(blockHeight, currentTime, positionId)

	// update lastCollectTime to current time
	deposit.lastCollectTime = currentTime

	// transfer external rewards to user
	externalReward := reward.External
	toUserExternalReward := make(map[string]int64)
	toUserExternalPenalty := make(map[string]int64)
	for incentiveId, rewardAmount := range externalReward {
		incentive := externalIncentives.get(incentiveId).Clone()
		if !incentive.IsStarted(currentTime) {
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
				"currentTime", formatInt(currentTime),
				"currentHeight", formatInt(blockHeight),
			)
			continue
		}

		// process external reward to user
		incentive.rewardAmount = safeSubInt64(incentive.rewardAmount, rewardAmount)
		rewardToken := incentive.rewardToken
		toUserExternalReward[rewardToken] = safeAddInt64(toUserExternalReward[rewardToken], rewardAmount)
		toUser, feeAmount, err := handleUnStakingFee(rewardToken, rewardAmount, false, positionId, incentive.targetPoolPath)
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
			"currentTime", formatInt(currentTime),
			"currentHeight", formatInt(blockHeight),
		)
		if toUser > 0 {
			if unwrapResult {
				tErr := unwrapWithTransfer(deposit.owner, toUser)
				if tErr != nil {
					panic(tErr)
				}
			} else {
				common.Transfer(cross, rewardToken, deposit.owner, toUser)
			}
		}

		// process external penalty
		externalPenalty := reward.ExternalPenalty[incentiveId]
		incentive.rewardAmount = safeSubInt64(incentive.rewardAmount, externalPenalty)
		incentive.rewardLeft = safeAddInt64(incentive.rewardLeft, externalPenalty)
		toUserExternalPenalty[rewardToken] = safeAddInt64(toUserExternalPenalty[rewardToken], externalPenalty)

		// update
		externalIncentives.set(incentiveId, incentive)

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
			"rewardToFee", formatInt(rewardAmount-toUser),
			"rewardPenalty", formatInt(externalPenalty),
			"isRequestUnwrap", formatBool(unwrapResult),
			"currentTime", formatInt(currentTime),
			"currentHeight", formatInt(blockHeight),
		)
	}

	communityPoolAddr := getRoleAddress(prbac.ROLE_COMMUNITY_POOL)

	// internal reward to user
	toUser, feeAmount, err := handleUnStakingFee(GNS_PATH, reward.Internal, true, positionId, deposit.targetPoolPath)
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
		gns.Transfer(cross, communityPoolAddr, reward.InternalPenalty)
	}

	unClaimableInternal := processUnClaimableReward(deposit.targetPoolPath, currentTime)
	if unClaimableInternal > 0 {
		// internal unClaimable to community pool
		totalEmissionSent = safeAddInt64(totalEmissionSent, unClaimableInternal)
		gns.Transfer(cross, communityPoolAddr, unClaimableInternal)
	}

	rewardToUser := formatInt(toUser)
	rewardPenalty := formatInt(reward.InternalPenalty)

	std.Emit(
		"CollectReward",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"positionId", formatUint(positionId),
		"poolPath", deposit.targetPoolPath,
		"recipient", deposit.owner.String(),
		"rewardToken", GNS_PATH,
		"rewardAmount", formatInt(reward.Internal),
		"rewardToUser", rewardToUser,
		"rewardToFee", formatInt(reward.Internal-toUser),
		"rewardPenalty", rewardPenalty,
		"rewardUnClaimableAmount", formatInt(unClaimableInternal),
		"currentTime", formatInt(currentTime),
	)

	return rewardToUser, rewardPenalty, toUserExternalReward, toUserExternalPenalty
}

// UnStakeToken withdraws an LP token from staking, collecting all pending rewards
// and returning the token to its original owner.
//
// Parameters:
//   - positionId: LP position NFT token ID to unstake
//   - unwrapResult: Convert WUGNOT to GNOT if true
//
// Process:
//  1. Collects all pending rewards (GNS + external)
//  2. Transfers NFT ownership back to original owner
//  3. Clears position operator rights
//  4. Removes from reward tracking systems
//  5. Cleans up all staking metadata
//
// Returns:
//   - poolPath: Pool identifier where position was staked
//   - token0Amount: Current token0 balance in position
//   - token1Amount: Current token1 balance in position
//
// Requirements:
//   - Caller must be the depositor
//   - Position must be currently staked
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

	currentTime := time.Now().Unix()
	currentTick := pl.GetSlot0Tick(deposit.targetPoolPath)
	signedLiquidity := i256.Zero().Neg(i256.FromUint256(deposit.liquidity))
	if pn.PositionIsInRange(positionId) {
		pool.modifyDeposit(signedLiquidity, currentTime, currentTick)
	}

	upperTick := pool.ticks.Get(deposit.tickUpper)
	lowerTick := pool.ticks.Get(deposit.tickLower)
	upperTick.modifyDepositUpper(currentTime, signedLiquidity)
	lowerTick.modifyDepositLower(currentTime, signedLiquidity)

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

package staker

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	en "gno.land/r/gnoswap/v1/emission"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	pusers "gno.land/p/demo/users"
)

type Deposits struct {
	tree *avl.Tree
}

func NewDeposits() *Deposits {
	return &Deposits{
		tree: avl.NewTree(), // tokenId -> Deposit
	}
}

func (self *Deposits) Get(tokenId uint64) *Deposit {
	depositI, ok := self.tree.Get(EncodeUint(tokenId))
	if !ok {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("tokenId(%d) not found", tokenId),
		))
	}
	deposit := depositI.(*Deposit)
	return deposit
}

func (self *Deposits) Set(tokenId uint64, deposit *Deposit) {
	self.tree.Set(EncodeUint(tokenId), deposit)
}

func (self *Deposits) Has(tokenId uint64) bool {
	return self.tree.Has(EncodeUint(tokenId))
}

func (self *Deposits) Remove(tokenId uint64) {
	self.tree.Remove(EncodeUint(tokenId))
}

func (self *Deposits) Iterate(start uint64, end uint64, fn func(tokenId uint64, deposit *Deposit) bool) {
	self.tree.Iterate(EncodeUint(start), EncodeUint(end), func(tokenId string, depositI interface{}) bool {
		return fn(DecodeUint(tokenId), depositI.(*Deposit))
	})
}

func (self *Deposits) Size() int {
	return self.tree.Size()
}

type ExternalIncentives struct {
	tree *avl.Tree
}

func NewExternalIncentives() *ExternalIncentives {
	return &ExternalIncentives{
		tree: avl.NewTree(),
	}
}

func (self *ExternalIncentives) Get(incentiveId string) *ExternalIncentive {
	incentiveI, ok := self.tree.Get(incentiveId)
	if !ok {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("incentiveId(%s) not found", incentiveId),
		))
	}

	incentive := incentiveI.(*ExternalIncentive)
	return incentive
}

func (self *ExternalIncentives) Set(incentiveId string, incentive *ExternalIncentive) {
	self.tree.Set(incentiveId, incentive)
}

func (self *ExternalIncentives) Has(incentiveId string) bool {
	return self.tree.Has(incentiveId)
}

func (self *ExternalIncentives) Remove(incentiveId string) {
	self.tree.Remove(incentiveId)
}

func (self *ExternalIncentives) Size() int {
	return self.tree.Size()
}

var (
	// deposits stores deposit information for each tokenId
	deposits *Deposits = NewDeposits()

	// externalIncentives stores external incentive information for each incentiveId
	externalIncentives *ExternalIncentives = NewExternalIncentives()

	// poolTier stores pool tier information
	poolTier *PoolTier
)

const (
	TIMESTAMP_90DAYS  = 7776000
	TIMESTAMP_180DAYS = 15552000
	TIMESTAMP_365DAYS = 31536000

	MAX_UNIX_EPOCH_TIME = 253402300799 // 9999-12-31 23:59:59

	MUST_EXISTS_IN_TIER_1 = "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000"

	INTERNAL = true
	EXTERNAL = false
)

func init() {
	// init pool tiers
	// tier 1
	// ONLY GNOT:GNS 0.3%

	poolTier = NewPoolTier(pools, uint64(std.GetHeight()), MUST_EXISTS_IN_TIER_1, en.GetEmission, en.GetHalvingBlocksInRange)
	pools.GetOrCreate(MUST_EXISTS_IN_TIER_1, 0/*FIXME XXX: WE NEED TO GET THE TICK*/) // must update pools tree
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
//   - tokenId (uint64): The ID of the LP token to stake
//
// Returns:
//   - poolPath (string): The path of the pool to which the LP token is staked
//   - token0Amount (string): The amount of token0 in the LP token
//   - token1Amount (string): The amount of token1 in the LP token
//
// ref: https://docs.gnoswap.io/contracts/staker/staker.gno#staketoken
func StakeToken(tokenId uint64) (string, string, string) {

	println("================== Stake Token (", tokenId, ") ==================")
	assertOnlyNotHalted()
	assertOnlyNotStaked(tokenId)

	en.MintAndDistributeGns()

	owner := gnft.MustOwnerOf(tid(tokenId))
	caller := getPrevAddr()

	token0Amount, token1Amount, err := calculateStakeTokenAmount(tokenId, owner, caller)
	if err != nil {
		panic(err.Error())
	}

	// check pool path from tokenId
	poolPath := pn.PositionGetPositionPoolKey(tokenId)
	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(addDetailToError(
			errNonIncentivizedPool,
			ufmt.Sprintf("can not stake position to non existing pool(%s)", poolPath),
		))
	}
	currentHeight := std.GetHeight()
	liquidity := getLiquidity(tokenId)

	tickLower, tickUpper := getTickOf(tokenId)

	// staked status
	deposit := &Deposit{
		owner:             caller,
		stakeTimestamp:    time.Now().Unix(),
		stakeHeight:       currentHeight,
		targetPoolPath:    poolPath,
		tickLower:         tickLower,
		tickUpper:         tickUpper,
		liquidity:         liquidity,
		lastCollectHeight: uint64(currentHeight),
		warmups:           InstantiateWarmup(currentHeight),
	}

	currentTick := pl.PoolGetSlot0Tick(poolPath)

	deposits.Set(tokenId, deposit)

	if caller == owner { // if caller is owner, transfer NFT ownership to staker contract
		if err := transferDeposit(tokenId, owner, caller, consts.STAKER_ADDR); err != nil {
			panic(err.Error())
		}
	}

	// after transfer, set caller(user) as position operator (to collect fee and reward)
	pn.SetPositionOperator(tokenId, caller)

	signedLiquidity := i256.FromUint256(liquidity)

	isInRange := false
	println("[", currentHeight, "][", tokenId, "] currentTick: ", currentTick)

	// TODO: call cache functions at the every staker related state change
	poolTier.cacheReward(uint64(currentHeight), pools)
	pool.cacheExternalReward(uint64(currentHeight))

	if pn.PositionIsInRange(tokenId) {
		isInRange = true
		pool.modifyDeposit(tokenId, signedLiquidity, uint64(currentHeight))
	}

	// this could happen because of how position stores the ticks.
	// ticks are negated if the token1 < token0
	upperTick := pool.ticks.Get(tickUpper)
	lowerTick := pool.ticks.Get(tickLower)
	upperTick.modifyDepositUpper(uint64(currentHeight), currentTick, signedLiquidity)
	println("upperTick id : ", upperTick.id)
	println("upperTick stakedLiquidityGross: ", upperTick.stakedLiquidityGross.ToString())
	println("upperTick stakedLiquidityDelta: ", upperTick.stakedLiquidityDelta.ToString())
	//println("upperTick Size: ", upperTick.cross.tree.Size())
	lowerTick.modifyDepositLower(uint64(currentHeight), currentTick, signedLiquidity)
	println("lowerTick id: ", lowerTick.id)
	println("lowerTick stakedLiquidityGross: ", lowerTick.stakedLiquidityGross.ToString())
	println("lowerTick stakedLiquidityDelta: ", lowerTick.stakedLiquidityDelta.ToString())
	//println("lowerTick Size: ", lowerTick.cross.tree.Size())

	prevAddr, prevPkgPath := getPrev()

	std.Emit(
		"StakeToken",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"lpTokenId", strconv.FormatUint(tokenId, 10),
		"poolPath", poolPath,
		"amount0", token0Amount,
		"amount1", token1Amount,
		"liquidity", liquidity.ToString(),
		"currentTick", strconv.FormatInt(int64(currentTick), 10),
		"isInRange", strconv.FormatBool(isInRange),
	)

	// positionsInternalWarmUpAmount[tokenId] = warmUpAmount{}
	return poolPath, token0Amount, token1Amount
}

// calculateStakeData validates staking requirements and prepares staking data.
//
// It checks if the token is already staked, verifies ownership, and ensures the pool has incentives.
// If successful, it returns the staking data; otherwise, it returns an error.
//
// Parameters:
//   - tokenId: The ID of the LP token to stake
//   - owner: The owner of the LP token
//   - caller: The caller of the staking operation
//
// Returns:
//   - *stakeResult: The staking data if successful
//   - error: An error if any validation fails
func calculateStakeTokenAmount(tokenId uint64, owner, caller std.Address) (string, string, error) {
	exist := deposits.Has(tokenId)
	if exist {
		return "", "", errAlreadyStaked
	}

	if err := requireTokenOwnership(owner, caller); err != nil {
		return "", "", err
	}

	if err := tokenHasLiquidity(tokenId); err != nil {
		return "", "", err
	}

	poolPath := pn.PositionGetPositionPoolKey(tokenId)
	if err := poolHasIncentives(poolPath); err != nil {
		return "", "", err
	}

	token0Amount, token1Amount := getTokenPairBalanceFromPosition(poolPath, tokenId)

	return token0Amount, token1Amount, nil
}

// transferDeposit transfers the ownership of a deposit token (NFT) to a new owner.
//
// This function ensures that the caller is not the same as the recipient (`to`).
// If the caller is not the owner or the recipient, it attempts to transfer the NFT
// ownership from the current owner to the recipient.
//
// Parameters:
// - tokenId (uint64): The unique identifier of the token (NFT) to transfer.
// - owner (std.Address): The current owner of the token.
// - caller (std.Address): The address attempting to initiate the transfer.
// - to (std.Address): The address to which the token will be transferred.
//
// Returns:
//   - error: Returns an error if the caller is the same as the recipient (`to`).
//     Otherwise, it delegates the transfer to `gnft.TransferFrom` and returns any error
//     that may occur during the transfer.
func transferDeposit(tokenId uint64, owner, caller, to std.Address) error {
	if caller == to {
		return ufmt.Errorf(
			"%v: only owner(%s) can transfer tokenId(%d), called from %s",
			errNoPermission, owner, tokenId, caller,
		)
	}
	// transfer NFT ownership
	return gnft.TransferFrom(owner, to, tid(tokenId))
}

////////////////////////////////////////////////////////////

// CollectReward harvests accumulated rewards for a staked position. This includes both
// inernal GNS emission and external incentive rewards.
//
// State Transition:
//  1. Warm-up amounts are cleares for both internal and external rewards
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
//   - tokenId (uint64): The ID of the LP token to collect rewards from
//   - unwrapResult (bool): Whether to unwrap WUGNOT to GNOT
//
// Returns:
//   - poolPath (string): The path of the pool to which the LP token is staked
//
// ref: https://docs.gnoswap.io/contracts/staker/staker.gno#collectreward
func CollectReward(tokenId uint64, unwrapResult bool) (string, string) {

	println("")
	println("")
	println("")
	println("")
	println("================== CollectReward (", tokenId, ") ==================")

	assertOnlyNotHalted()

	en.MintAndDistributeGns()

	deposit := deposits.Get(tokenId)
	caller := getPrevAddr()
	if err := common.SatisfyCond(caller == deposit.owner); err != nil {
		panic(addDetailToError(errNoPermission, ufmt.Sprintf("caller is not owner of tokenId(%d)", tokenId)))
	}

	currentHeight := std.GetHeight()
	// get all internal and external rewards
	reward := calcPositionReward(uint64(currentHeight), tokenId)

	// update lastCollectHeight to current height
	deposit.lastCollectHeight = uint64(currentHeight)

	// transfer external rewards to user
	externalReward := reward.External
	for incentiveId, amount := range externalReward {
		incentive := externalIncentives.Get(incentiveId)
		rewardToken := incentive.rewardToken
		if incentive.rewardAmount < amount {
			panic(addDetailToError(
				errInsufficientReward,
				ufmt.Sprintf("incentiveId(%s) has insufficient reward(%d)", incentiveId, amount),
			))
		}
		incentive.rewardAmount -= amount
		incentive.rewardLeft = incentive.rewardAmount
		externalIncentives.Set(incentiveId, incentive)

		toUser := handleUnstakingFee(rewardToken, amount, false, tokenId, incentive.targetPoolPath)

		teller := common.GetTokenTeller(rewardToken)
		teller.Transfer(deposit.owner, toUser)
	}

	// do nothing for external penalty
	// it will be stored in staker, and when external ends will be refunded
	externalIncentivePenalty := reward.ExternalPenalty
	externalIncentiveReward := reward.External

	// TODO:
	// externalPenalty should be stored in staker
	// And update reward ledger

	// println("externalPenalty", externalPenalty)

	// internal reward to user
	toUser := handleUnstakingFee(consts.GNS_PATH, reward.Internal, true, tokenId, deposit.targetPoolPath)
	println("toUser", toUser)
	if toUser > 0 {
		println("gns balance (staker) : ", gns.BalanceOf(pusers.AddressOrName(consts.STAKER_ADDR)))

		println("sending reward", toUser, "to", deposit.owner, "// gns balance (staker) :", gns.BalanceOf(pusers.AddressOrName(consts.STAKER_ADDR)))
		gns.Transfer(a2u(deposit.owner), toUser)
		println("sending reward ok")
		println()

		// internal penalty to community pool
		println("sending penalty", reward.InternalPenalty, "to community pool // gns balance (staker) :", gns.BalanceOf(pusers.AddressOrName(consts.STAKER_ADDR)))
		gns.Transfer(a2u(consts.COMMUNITY_POOL_ADDR), reward.InternalPenalty)
		println("sending penalty ok")
		println()

		// TODO:
		// reward ledger update!!
	}

	// FIXME @mconcat
	// panic: slice index out of bounds: 0 (len=0)
	unClaimableInternal, unClaimableExternal := ProcessUnClaimableReward(deposit.targetPoolPath, uint64(currentHeight))
	println("unClaimableInternal : ", unClaimableInternal)
	if unClaimableInternal > 0 {
		// internal unclaimable to community pool
		println("sending unClaimableInternal", unClaimableInternal, " to community pool // gns balance (staker) :", gns.BalanceOf(pusers.AddressOrName(consts.STAKER_ADDR)))
		gns.Transfer(a2u(consts.COMMUNITY_POOL_ADDR), unClaimableInternal)
		println("sending unClaimableInternal ok")
		println()
	}

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"CollectReward",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"lpTokenId", strconv.FormatUint(tokenId, 10),
		"internal_poolPath", deposit.targetPoolPath,
		"internal_incentiveId", "INTERNAL",
		"internal_rewardToken", consts.GNS_PATH,
		"internal_recipient", deposit.owner.String(),
		"internal_reward", strconv.FormatUint(reward.Internal, 10),
		"internal_toUser", strconv.FormatUint(toUser, 10),
		"internal_toFee", strconv.FormatUint(reward.Internal-toUser, 10),
		"internal_toPenalty", strconv.FormatUint(reward.InternalPenalty, 10),
		"internal_unClaimable", strconv.FormatUint(unClaimableInternal, 10),
	)

	return strconv.FormatUint(toUser, 10), strconv.FormatUint(reward.InternalPenalty, 10)
}

/*
func applyCollectReward(
	result *collectResult,
	unwrap bool,
) ([]externalRewardResult, internalRewardResult) {
	rewardResults := make([]externalRewardResult, 0)

	// apply external rewards
	result.externalRewards.Iterate("", "", func(ictvId string, value interface{}) bool {
		reward := value.(externalRewardInfo)
		rewardResult := applyExternalReward(result.tokenId, reward, result.owner, unwrap)
		rewardResults = append(rewardResults, rewardResult)
		return false // continue to iterate
	})

	// apply internal rewards
	internalRewardResult := applyInternalReward(result.tokenId, result.internalRewards, result.owner)

	// update staker GNS balance
	lastCalculatedBalance = calculateGnsBalance()

	return rewardResults, internalRewardResult
}

func calculateGnsBalance() uint64 {
	return gnsBalance(consts.STAKER_ADDR) - externalGnsAmount() - externalDepositGnsAmount()
}
*/

////////////////////////////////////////////////////////////

// UnstakeToken withdraws an LP token from staking, collecting all pending rewards
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
// - Rewards are automatically collected before unstaking
//
// Params:
// - tokenId (uint64): ID of the staked LP token
// - unwrapResult (bool): If true, unwraps any WUGNOT rewards to GNOT
//
// Returns:
// - poolPath (string): The pool path associated with the unstaked position
// - token0Amount (string): Final amount of token0 in the position
// - token1Amount (string): Final amount of token1 in the position
//
// ref: https://docs.gnoswap.io/contracts/staker/staker.gno#unstaketoken
func UnstakeToken(tokenId uint64, unwrapResult bool) (string, string, string) { // poolPath, token0Amount, token1Amount
	assertOnlyNotHalted()

	// unstaked status
	deposit := deposits.Get(tokenId)
	poolPath := deposit.targetPoolPath

	// Claim All Rewards
	CollectReward(tokenId, unwrapResult)
	token0Amount, token1Amount := getTokenPairBalanceFromPosition(poolPath, tokenId)

	applyUnStake(tokenId)

	// transfer NFT ownership to origin owner
	gnft.TransferFrom(consts.STAKER_ADDR, deposit.owner, tid(tokenId))
	pn.SetPositionOperator(tokenId, consts.ZERO_ADDRESS)

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"UnstakeToken",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"lpTokenId", ufmt.Sprintf("%d", tokenId),
		"unwrapResult", ufmt.Sprintf("%t", unwrapResult),
		"internal_poolPath", poolPath,
		"internal_from", deposit.owner.String(),
		"internal_to", consts.STAKER_ADDR.String(),
		"internal_amount0", token0Amount,
		"internal_amount1", token1Amount,
	)

	return poolPath, token0Amount, token1Amount
}

func applyUnStake(tokenId uint64) {
	deposit := deposits.Get(tokenId)
	pool, ok := pools.Get(deposit.targetPoolPath)
	if !ok {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("pool(%s) does not exist", deposit.targetPoolPath),
		))
	}

	currentHeight := uint64(std.GetHeight())
	currentTick := pl.PoolGetSlot0Tick(deposit.targetPoolPath)
	signedLiquidity := i256.FromUint256(deposit.liquidity)
	signedLiquidity = signedLiquidity.Neg(signedLiquidity)
	if pn.PositionIsInRange(tokenId) {
		pool.modifyDeposit(tokenId, signedLiquidity, currentHeight)
	}

	upperTick := pool.ticks.Get(deposit.tickUpper)
	lowerTick := pool.ticks.Get(deposit.tickLower)
	upperTick.modifyDepositUpper(currentHeight, currentTick, signedLiquidity)
	lowerTick.modifyDepositLower(currentHeight, currentTick, signedLiquidity)

	deposits.Remove(tokenId)

	owner := gnft.MustOwnerOf(tid(tokenId))
	caller := getPrevAddr()

	token0Amount, token1Amount, err := calculateStakeTokenAmount(tokenId, owner, caller)
	if err != nil {
		panic(err.Error())
	}

	prevAddr, prevPkgPath := getPrev()
	std.Emit(
		"UnstakeToken",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"lpTokenId", strconv.FormatUint(tokenId, 10),
		"internal_poolPath", deposit.targetPoolPath,
		"internal_from", GetOrigPkgAddr().String(),
		"internal_to", deposit.owner.String(),
		"internal_amount0", token0Amount,
		"internal_amount1", token1Amount,
	)
}

// requireTokenOwnership validates that the caller has permission to operate the token.
func requireTokenOwnership(owner, caller std.Address) error {
	callerIsOwner := owner == caller
	stakerIsOwner := owner == consts.STAKER_ADDR

	if err := common.SatisfyCond(callerIsOwner || stakerIsOwner); err != nil {
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
	hasInternal := poolTier.IsInternallyIncentivizedPool(uint64(std.GetHeight()), poolPath)
	hasExternal := pool.IsExternallyIncentivizedPool(uint64(std.GetHeight()))
	if hasInternal == false && hasExternal == false {
		return ufmt.Errorf(
			"%v: can not stake position to non incentivized pool(%s)",
			errNonIncentivizedPool, poolPath,
		)
	}
	return nil
}

// tokenHasLiquidity checks if the target tokenId has non-zero liquidity
func tokenHasLiquidity(tokenId uint64) error {
	liquidity := getLiquidity(tokenId)

	if liquidity.Lte(u256.Zero()) {
		return ufmt.Errorf(
			"%v: tokenId(%d) has no liquidity",
			errZeroLiquidity, tokenId,
		)
	}
	return nil
}

func getLiquidity(tokenId uint64) *u256.Uint {
	liq := pn.PositionGetPositionLiquidityStr(tokenId)
	return u256.MustFromDecimal(liq)
}

func assertOnlyNotStaked(tokenId uint64) {
	if deposits.Has(tokenId) {
		panic(addDetailToError(
			errAlreadyStaked,
			ufmt.Sprintf("tokenId(%d) already staked", tokenId),
		))
	}
}

func getTokenPairBalanceFromPosition(poolPath string, tokenId uint64) (string, string) {
	pool := pl.GetPoolFromPoolPath(poolPath)

	currentX96 := pool.Slot0SqrtPriceX96()
	lowerX96 := common.TickMathGetSqrtRatioAtTick(pn.PositionGetPositionTickLower(tokenId))
	upperX96 := common.TickMathGetSqrtRatioAtTick(pn.PositionGetPositionTickUpper(tokenId))

	token0Balance, token1Balance := common.GetAmountsForLiquidity(
		currentX96,
		lowerX96,
		upperX96,
		u256.MustFromDecimal(pn.PositionGetPositionLiquidityStr(tokenId)),
	)

	if token0Balance == "" {
		token0Balance = "0"
	}
	if token1Balance == "" {
		token1Balance = "0"
	}
	println("[", tokenId, "]=== token0Balance: ", token0Balance, ", token1Balance: ", token1Balance)
	return token0Balance, token1Balance
}

func getTickOf(tokenId uint64) (int32, int32) {
	tickLower := pn.PositionGetPositionTickLower(tokenId)
	tickUpper := pn.PositionGetPositionTickUpper(tokenId)
	if tickUpper < tickLower {
		panic(ufmt.Sprintf("tickUpper(%d) is less than tickLower(%d)", tickUpper, tickLower))
	}
	return tickLower, tickUpper
}

// TODO:
// SetTier
// RemoveTier
// ChangeTier

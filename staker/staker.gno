package staker

import (
	"std"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	en "gno.land/r/gnoswap/v1/emission"
	pn "gno.land/r/gnoswap/v1/position"

	u256 "gno.land/p/gnoswap/uint256"
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
	poolTiers.Set(MUST_EXISTS_IN_TIER_1, InternalTier{
		tier:           1,
		startTimestamp: time.Now().Unix(),
	})
}

// stakeResult holds the data needed to process a staking operation.
type stakeResult struct {
	tokenId      uint64
	owner        std.Address
	caller       std.Address
	poolPath     string
	token0Amount string
	token1Amount string
	deposit      Deposit
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
	common.IsHalted()

	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

	owner := gnft.OwnerOf(tid(tokenId))
	caller := std.PrevRealm().Addr()

	result, err := calculateStakeData(tokenId, owner, caller)
	if err != nil {
		panic(err)
	}

	if err := applyStake(result); err != nil {
		panic(err)
	}

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"StakeToken",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"lpTokenId", ufmt.Sprintf("%d", tokenId),
		"internal_poolPath", result.poolPath,
		"internal_amount0", result.token0Amount,
		"internal_amount1", result.token1Amount,
	)

	positionsInternalWarmUpAmount[tokenId] = warmUpAmount{}
	return result.poolPath, result.token0Amount, result.token1Amount
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
func calculateStakeData(tokenId uint64, owner, caller std.Address) (*stakeResult, error) {
	deposit, exist := deposits.Get(tokenId)
	if !exist {
		return nil, errAlreadyStaked
	}

	if err := requireTokenOwnership(owner, caller); err != nil {
		return nil, err
	}

	poolPath := pn.PositionGetPositionPoolKey(tokenId)
	if err := poolHasIncentives(poolPath); err != nil {
		return nil, err
	}

	if err := tokenHasLiquidity(tokenId); err != nil {
		return nil, err
	}

	newDeposit := newDeposit(
		owner,
		deposit.NumberOfStakes()+1,
		time.Now().Unix(),
		std.GetHeight(),
		poolPath,
	)

	token0Amount, token1Amount := getTokenPairBalanceFromPosition(poolPath, tokenId)

	return &stakeResult{
		tokenId:      tokenId,
		owner:        owner,
		caller:       caller,
		poolPath:     poolPath,
		token0Amount: token0Amount,
		token1Amount: token1Amount,
		deposit:      newDeposit,
	}, nil
}

// applyStake performs the actual staking operation by updating contract state.
func applyStake(s *stakeResult) error {
	deposits.Set(s.tokenId, s.deposit)

	if s.owner == s.caller {
		if err := transferDeposit(s.tokenId, s.owner, s.caller, consts.STAKER_ADDR); err != nil {
			return err
		}
	}

	pn.SetPositionOperator(s.tokenId, s.caller)
	positionsInternalWarmUpAmount[s.tokenId] = warmUpAmount{}

	return nil
}

func transferDeposit(tokenId uint64, owner, caller, to std.Address) error {
	if caller == to {
		return ufmt.Errorf(
			"%v: only owner(%s) can transfer tokenId(%d), called from %s",
			errNoPermission, owner, tokenId, caller,
		)
	}

	// transfer NFT ownership
	gnft.TransferFrom(a2u(owner), a2u(to), tid(tokenId))

	return nil
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
func CollectReward(tokenId uint64, unwrapResult bool) string {
	common.IsHalted()

	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

	deposit := deposits.MustGet(tokenId)
	caller := std.PrevRealm().Addr()
	if err := common.SatisfyCond(caller == deposit.owner); err != nil {
		panic(ufmt.Sprintf("%v: caller is not owner of tokenId(%d)", errNoPermission, tokenId))
	}

	result, err := calculateCollectReward(tokenId, deposit)
	if err != nil {
		panic(err)
	}

	external, internal := applyCollectReaward(result, unwrapResult)

	prevAddr, prevPkgPath := getPrev()

	for _, reward := range external {
		std.Emit(
			"ProtocolFeeExternalPenalty",
			"prevAddr", prevAddr,
			"prevRealm", prevPkgPath,
			"lpTokenId", ufmt.Sprintf("%d", tokenId),
			"internal_poolPath", reward.poolPath,
			"internal_incentiveId", reward.ictvId,
			"internal_tokenPath", reward.tokenPath,
			"internal_amount", ufmt.Sprintf("%d", reward.left),
		)

		std.Emit(
			"CollectRewardExternal",
			"prevAddr", prevAddr,
			"prevRealm", prevPkgPath,
			"lpTokenId", ufmt.Sprintf("%d", tokenId),
			"internal_poolPath", reward.poolPath,
			"internal_incentiveId", reward.ictvId,
			"internal_rewardToken", reward.tokenPath,
			"internal_recipient", result.owner.String(),
			"internal_amount", ufmt.Sprintf("%d", reward.toUser),
			"internal_unwrapResult", ufmt.Sprintf("%t", unwrapResult),
		)
	}

	if internal.toGive > 0 {
		std.Emit(
			"CommunityPoolEmissionPenalty",
			"prevAddr", prevAddr,
			"prevRealm", prevPkgPath,
			"lpTokenId", ufmt.Sprintf("%d", tokenId),
			"internal_poolPath", result.poolPath,
			"internal_incentiveId", "INTERNAL",
			"internal_tokenPath", consts.GNS_PATH,
			"internal_amount", ufmt.Sprintf("%d", internal.left),
		)

		std.Emit(
			"CollectRewardEmission",
			"prevAddr", prevAddr,
			"prevRealm", prevPkgPath,
			"lpTokenId", ufmt.Sprintf("%d", tokenId),
			"internal_poolPath", result.poolPath,
			"internal_incentiveId", "INTERNAL",
			"internal_rewardToken", consts.GNS_PATH,
			"internal_recipient", result.owner.String(),
			"internal_fullAmount", ufmt.Sprintf("%d", internal.fullAmount),
			"internal_toGive", ufmt.Sprintf("%d", internal.toGive),
			"internal_amount", ufmt.Sprintf("%d", internal.toUser),
			"internal_unstakingFee", ufmt.Sprintf("%d", internal.toGive-internal.toUser),
			"internal_left", ufmt.Sprintf("%d", internal.left),
		)
	}

	return result.poolPath
}

// collectResult represents the result of a reward collection operation.
type collectResult struct {
	tokenId         uint64
	owner           std.Address
	poolPath        string
	internalRewards warmUpAmount
	externalRewards *avl.Tree
}

// newCollectResult contains all reward information for a position.
func newCollectResult(tokenId uint64, owner std.Address, poolPath string) *collectResult {
	return &collectResult{
		tokenId:         tokenId,
		owner:           owner,
		poolPath:        poolPath,
		internalRewards: warmUpAmount{},
		externalRewards: avl.NewTree(),
	}
}

// externalRewardInfo holds data for a single external reward calculation.
type externalRewardInfo struct {
	ictvId     string
	tokenPath  string
	fullAmount uint64
	toGive     uint64
}

// calculateCollectReward calculates both external and internal rewards for a given token ID.
//
// It processes the rewards based on the deposit information [`Deposit`] and current state of both reward types.
//
// Parameters:
//   - tokenId: The ID of the token for which to calculate rewards
//   - deposit: The deposit information for the token
//
// Returns:
//   - A `collectResult` containing all reward information and any error encountered during the calculation.
func calculateCollectReward(tokenId uint64, deposit Deposit) (*collectResult, error) {
	result := newCollectResult(tokenId, deposit.owner, deposit.TargetPoolPath())

	if err := calculateExternalRewards(tokenId, result); err != nil {
		return nil, err
	}

	result.internalRewards = positionsInternalWarmUpAmount[tokenId]

	return result, nil
}

// calculateExternalRewards pricesses all external rewards for a given token ID.
//
// It iterates through all external positions associated with the token and calculates
// their respective rewards, storing them in the provided `collectResult` instance.
//
// Parameters:
//   - tokenId: The ID of the token for which to calculate rewards
//   - result: The `collectResult` instance to store the calculated rewards.
//
// Returns:
//   - An error if any issues arise during the calculation process.
func calculateExternalRewards(tokenId uint64, result *collectResult) error {
	positions, exist := positionExternal[tokenId]
	if !exist {
		return nil
	}

	for ictvId, external := range positions {
		tokenPath := external.tokenPath
		reward, err := calculateSingleExternalReward(tokenId, tokenPath, ictvId)
		if err != nil {
			return err
		}
		if reward != nil {
			result.externalRewards.Set(ictvId, reward)
		}
	}

	return nil
}

// calculateSingleExternalReward calculates the reward for a single external incentive.
// It verifies the existence of the incentive and its warm-up amount, then calculates
// the reward based on the warm-up amount.
//
// Parameters:
//   - tokenId: The ID of the token for which to calculate rewards
//   - tokenPath: The path of the reward token
//   - ictvId: The ID of the incentive
//
// Returns:
//   - *externalRewardResult: Contains the calculated reward information if successful
//   - error: Returns errIncentiveNotFound if the incentive doesn't exist,
//     errWarmUpAmountNotFound if warm-up amount is missing, or nil if successful
//
// If there are no rewards to give (toGive = 0), it returns (nil, nil).
func calculateSingleExternalReward(tokenId uint64, tokenPath, ictvId string) (*externalRewardResult, error) {
	ictv, exists := incentives.Get(ictvId)
	if !exists {
		return nil, ufmt.Errorf("%v: incentive ID=%s", errIncentiveNotFound, ictvId)
	}

	// get warm up amount
	// TODO: change type
	warmUp, exists := positionsExternalWarmUpAmount[tokenId][ictvId]
	if !exists {
		return nil, ufmt.Errorf("%v: incentive ID=%s", errWarmUpAmountNotFound, ictvId)
	}

	fullAmount := warmUp.totalFull()
	toGive := warmUp.totalGive()

	// skip if there's nothing to give
	if toGive == 0 {
		return nil, nil
	}

	return &externalRewardResult{
		ictvId:     ictvId,
		tokenPath:  tokenPath,
		poolPath:   ictv.targetPoolPath,
		fullAmount: fullAmount,
		toGive:     toGive,
	}, nil
}

// externalRewardResult contains all the data needed to emit the event
type externalRewardResult struct {
	ictvId     string
	tokenPath  string
	poolPath   string
	fullAmount uint64
	toGive     uint64
	toUser     uint64
	left       uint64
}

func applyExternalReward(
	tokenId uint64,
	reward externalRewardInfo,
	owner std.Address,
	unwrapResult bool,
) externalRewardResult {
	ictv, exists := incentives.Get(reward.ictvId)
	if !exists {
		return externalRewardResult{}
	}

	external := positionExternal[tokenId][reward.ictvId]
	external.tokenAmountX96 = u256.Zero()
	external.tokenAmountFull += reward.fullAmount
	external.tokenAmountToGive += reward.toGive
	positionExternal[tokenId][reward.ictvId] = external

	toUser := handleUnstakingFee(reward.tokenPath, reward.toGive, EXTERNAL, tokenId, ictv.targetPoolPath)

	transferByRegisterCall(reward.tokenPath, owner, toUser)
	if reward.tokenPath == consts.WUGNOT_PATH && unwrapResult {
		unwrap(toUser)
	}

	// TODO: change type
	positionsExternalWarmUpAmount[tokenId][reward.ictvId] = warmUpAmount{}
	positionLastExternal[tokenId][reward.ictvId] = u256.Zero()

	remaining := reward.fullAmount - reward.toGive
	transferByRegisterCall(reward.tokenPath, consts.PROTOCOL_FEE_ADDR, remaining)

	ictv.rewardLeft = new(u256.Uint).Sub(ictv.rewardLeft, u256.NewUint(reward.fullAmount))
	incentives.Set(reward.ictvId, ictv)

	return externalRewardResult{
		ictvId:     reward.ictvId,
		tokenPath:  reward.tokenPath,
		poolPath:   ictv.targetPoolPath,
		fullAmount: reward.fullAmount,
		toGive:     reward.toGive,
		toUser:     toUser,
		left:       remaining,
	}
}

// internalRewardResult contains all the data needed to emit the event
type internalRewardResult struct {
	fullAmount uint64
	toGive     uint64
	toUser     uint64
	left       uint64
}

func applyInternalReward(
	tokenId uint64,
	internalRewards warmUpAmount,
	owner std.Address,
) internalRewardResult {
	fullAmount := internalRewards.totalFull()
	toGive := internalRewards.totalGive()
	if toGive == 0 {
		return internalRewardResult{}
	}

	poolPath := deposits.MustGet(tokenId).TargetPoolPath()
	toUser := handleUnstakingFee(consts.GNS_PATH, toGive, INTERNAL, tokenId, poolPath)
	gns.Transfer(a2u(owner), toUser)

	positionsInternalWarmUpAmount[tokenId] = warmUpAmount{} // just clear

	poolGns[poolPath] -= fullAmount

	left := fullAmount - toGive
	gns.Transfer(a2u(consts.COMMUNITY_POOL_ADDR), left)

	return internalRewardResult{
		fullAmount: fullAmount,
		toGive:     toGive,
		toUser:     toUser,
		left:       left,
	}
}

func applyCollectReaward(
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
	common.IsHalted()

	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		CalcPoolPositionRefactor()
	} else {
		CalcPoolPosition()
	}

	// unstaked status
	deposit, exist := deposits.Get(tokenId)
	if !exist {
		msg := ufmt.Sprintf("%v: tokenId(%d) not staked", errDataNotFound, tokenId)
		panic(msg)
	}

	// Claim All Rewards
	CollectReward(tokenId, unwrapResult)

	poolPath := pn.PositionGetPositionPoolKey(tokenId)
	token0Amount, token1Amount := getTokenPairBalanceFromPosition(poolPath, tokenId)

	input := newUnstakeInput(tokenId, unwrapResult, deposit)
	output := newUnstakeOutput(poolPath, token0Amount, token1Amount, input)

	cleanupStakeData(input.tokenId, positionGns, positionsInternalWarmUpAmount)

	manager := getRewardManager()
	applyUnstake(manager, input)

	// transfer NFT ownership to origin owner
	gnft.TransferFrom(a2u(consts.STAKER_ADDR), a2u(deposit.owner), tid(tokenId))
	pn.SetPositionOperator(tokenId, consts.ZERO_ADDRESS)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"UnstakeToken",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"lpTokenId", ufmt.Sprintf("%d", tokenId),
		"unwrapResult", ufmt.Sprintf("%t", unwrapResult),
		"internal_poolPath", output.poolPath,
		"internal_from", output.from.String(),
		"internal_to", output.to.String(),
		"internal_amount0", output.token0Amount,
		"internal_amount1", output.token1Amount,
	)

	return output.poolPath, output.token0Amount, output.token1Amount
}

// unstakeInput holds the necessary data for unstaking a position.
type unstakeInput struct {
	tokenId uint64
	unwrap  bool
	deposit Deposit
}

// newUnstakeInput creates a new `unstakeInput` instance with the given parameters.
func newUnstakeInput(
	tokenId uint64,
	unwrap bool,
	deposit Deposit,
) unstakeInput {
	return unstakeInput{
		tokenId: tokenId,
		unwrap:  unwrap,
		deposit: deposit,
	}
}

// unstakeOutput represents the output data generated during the unstaking process.
type unstakeOutput struct {
	tokenId      uint64
	owner        std.Address
	poolPath     string
	token0Amount string
	token1Amount string
	from         std.Address
	to           std.Address
}

// newUnstakeOutput creates a new `unstakeOutput` instance with the given parameters.
func newUnstakeOutput(
	poolPath string,
	token0Amount,
	token1Amount string,
	input unstakeInput,
) *unstakeOutput {
	return &unstakeOutput{
		tokenId:      input.tokenId,
		owner:        input.deposit.owner,
		poolPath:     poolPath,
		token0Amount: token0Amount,
		token1Amount: token1Amount,
		from:         consts.STAKER_ADDR,
		to:           input.deposit.owner,
	}
}

// Terminal state
// TODO: change type of positionInternalWarmUpAmount if needed.
func cleanupStakeData(
	tokenId uint64,
	positionGns map[uint64]uint64,
	positionsInternalWarmUpAmount map[uint64]warmUpAmount,
) {
	delete(positionGns, tokenId)
	delete(positionsInternalWarmUpAmount, tokenId)
	deposits.Remove(tokenId)
}

func applyUnstake(manager *RewardManager, input unstakeInput) *RewardManager {
	internalEmission := manager.GetInternalEmissionReward()
	internalEmission.RemoveInRangePosition(input.deposit.targetPoolPath, input.tokenId)
	manager.SetInternalEmissionReward(internalEmission)

	return manager
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
	hasInternal := poolHasInternal(poolPath)
	hasExternal := poolHasExternal(poolPath)
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
	liq := pn.PositionGetPositionLiquidityStr(tokenId)
	liquidity := u256.MustFromDecimal(liq)

	if liquidity.Lte(u256.Zero()) {
		return ufmt.Errorf(
			"%v: tokenId(%d) has no liquidity",
			errZeroLiquidity, tokenId,
		)
	}
	return nil
}

// poolHasInternal checks if te pool has internal GNS incentives
func poolHasInternal(poolPath string) bool {
	_, exist := poolTiers.Get(poolPath)
	return exist
}

// poolHasExternal checks if the pool has any external incentives
func poolHasExternal(poolPath string) bool {
	_, exist := poolIncentives.Get(poolPath)
	return exist
}

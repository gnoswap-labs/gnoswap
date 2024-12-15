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

type stakeResult struct {
	tokenId uint64
	owner std.Address
	caller std.Address
	poolPath string
	token0Amount string
	token1Amount string
	deposit Deposit
}

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
		deposit.NumberOfStakes() + 1,
		time.Now().Unix(),
		std.GetHeight(),
		poolPath,
	)

	token0Amount, token1Amount := getTokenPairBalanceFromPosition(tokenId)

	return &stakeResult{
		tokenId: tokenId,
		owner: owner,
		caller: caller,
		poolPath: poolPath,
		token0Amount: token0Amount,
		token1Amount: token1Amount,
		deposit: newDeposit,
	}, nil
}

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

// StakeToken stakes the LP token to the staker contract
// Returns poolPath, token0Amount, token1Amount
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

type collectResult struct {
	tokenId uint64
	owner std.Address
	poolPath string
	internalRewards warmUpAmount
	externalRewards *avl.Tree
}

type externalRewardInfo struct {
	ictvId string
	tokenPath string
	fullAmount uint64
	toGive uint64
}

func newCollectResult(tokenId uint64, owner std.Address, poolPath string) *collectResult {
	return &collectResult{
		tokenId: tokenId,
		owner: owner,
		poolPath: poolPath,
		internalRewards: warmUpAmount{},
		externalRewards: avl.NewTree(),
	}
}

func calculateCollectReward(tokenId uint64, deposit Deposit) (*collectResult, error) {
	result := newCollectResult(tokenId, deposit.owner, deposit.TargetPoolPath())

	// calculate external rewards
	if positions, exist := positionExternal[tokenId]; exist {
		for ictvId, external := range positions {
			_, exists := incentives.Get(ictvId)
			if !exists {
				continue
			}

			warmUpAmount, exists := positionsExternalWarmUpAmount[tokenId][ictvId]
			if !exists {
				continue
			}

			fullAmount := warmUpAmount.totalFull()
			toGive := warmUpAmount.totalGive()

			if toGive == 0 {
				continue
			}

			result.externalRewards.Set(ictvId, externalRewardInfo{
				ictvId: ictvId,
				tokenPath: external.tokenPath,
				fullAmount: fullAmount,
				toGive: toGive,
			})
		}
	}

	result.internalRewards = positionsInternalWarmUpAmount[tokenId]

	return result, nil
}

// externalRewardResult contains all the data needed to emit the event
type externalRewardResult struct {
	ictvId string
	tokenPath string
	poolPath string
	fullAmount uint64
	toGive uint64
	toUser uint64
	left uint64
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

	toUser := handleUnstakingFee(reward.tokenPath, reward.toGive, false, tokenId, ictv.targetPoolPath)

	transferByRegisterCall(reward.tokenPath, owner, toUser)
	if reward.tokenPath == consts.WUGNOT_PATH && unwrapResult {
		unwrap(toUser)
	}

	positionsExternalWarmUpAmount[tokenId][reward.ictvId] = warmUpAmount{} 
    positionLastExternal[tokenId][reward.ictvId] = u256.Zero()

	remaining := reward.fullAmount - reward.toGive
	transferByRegisterCall(reward.tokenPath, consts.PROTOCOL_FEE_ADDR, remaining)

	ictv.rewardLeft = new(u256.Uint).Sub(ictv.rewardLeft, u256.NewUint(reward.fullAmount))
	incentives.Set(reward.ictvId, ictv)

	return externalRewardResult{
		ictvId: reward.ictvId,
		tokenPath: reward.tokenPath,
		poolPath: ictv.targetPoolPath,
		fullAmount: reward.fullAmount,
		toGive: reward.toGive,
		toUser: toUser,
		left: remaining,
	}
}

// internalRewardResult contains all the data needed to emit the event
type internalRewardResult struct {
	fullAmount uint64
	toGive uint64
	toUser uint64
	left uint64
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
	toUser := handleUnstakingFee(consts.GNS_PATH, toGive, true, tokenId, poolPath)
	gns.Transfer(a2u(owner), toUser)

	positionsInternalWarmUpAmount[tokenId] = warmUpAmount{} // just clear

	poolGns[poolPath] -= fullAmount

	left := fullAmount - toGive
	gns.Transfer(a2u(consts.COMMUNITY_POOL_ADDR), left)

	return internalRewardResult{
		fullAmount: fullAmount,
		toGive: toGive,
		toUser: toUser,
		left: left,
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

// CollectReward collects staked rewards for the given tokenId
// Returns poolPath
// ref: https://docs.gnoswap.io/contracts/staker/staker.gno#collectreward
// func CollectReward(tokenId uint64, unwrapResult bool) string {
// 	common.IsHalted()

// 	en.MintAndDistributeGns()
// 	if consts.EMISSION_REFACTORED {
// 		CalcPoolPositionRefactor()
// 	} else {
// 		CalcPoolPosition()
// 	}

// 	deposit, exist := deposits.Get(tokenId)
// 	if !exist {
// 		panic(addDetailToError(
// 			errDataNotFound,
// 			ufmt.Sprintf("staker.gno__CollectReward() || tokenId(%d) not staked", tokenId),
// 		))
// 	}

// 	caller := std.PrevRealm().Addr()
// 	if err := common.SatisfyCond(caller == deposit.owner); err != nil {
// 		panic(ufmt.Sprintf("%v: caller is not owner of tokenId(%d)", errNoPermission, tokenId))
// 	}

// 	poolPath := deposit.TargetPoolPath()

// 	prevAddr, prevRealm := getPrev()

// 	_, exist = positionExternal[tokenId]
// 	if exist {
// 		for _, external := range positionExternal[tokenId] {
// 			incentive, exists := incentives.Get(external.incentiveId)
// 			if !exists {
// 				continue
// 			}
// 			incentiveId := external.incentiveId

// 			externalWarmUpAmount, exist := positionsExternalWarmUpAmount[tokenId][incentiveId]
// 			if !exist {
// 				continue
// 			}
// 			fullAmount := externalWarmUpAmount.full30 + externalWarmUpAmount.full50 + externalWarmUpAmount.full70 + externalWarmUpAmount.full100
// 			toGive := externalWarmUpAmount.give30 + externalWarmUpAmount.give50 + externalWarmUpAmount.give70 + externalWarmUpAmount.full100

// 			if toGive == 0 {
// 				continue
// 			}

// 			_this := positionExternal[tokenId][incentiveId]
// 			_this.tokenAmountX96 = u256.Zero()
// 			_this.tokenAmountFull += fullAmount
// 			_this.tokenAmountToGive += toGive
// 			positionExternal[tokenId][incentiveId] = _this

// 			toUser := handleUnstakingFee(external.tokenPath, toGive, false, tokenId, incentive.targetPoolPath)

// 			transferByRegisterCall(external.tokenPath, deposit.owner, toUser)
// 			if external.tokenPath == consts.WUGNOT_PATH && unwrapResult {
// 				unwrap(toUser)
// 			}

// 			positionsExternalWarmUpAmount[tokenId][incentiveId] = warmUpAmount{} // JUST CLEAR
// 			positionLastExternal[tokenId][incentiveId] = u256.Zero()             // JUST CLEAR

// 			left := fullAmount - toGive
// 			transferByRegisterCall(external.tokenPath, consts.PROTOCOL_FEE_ADDR, left)

// 			////////////////////////////////////////////////////////////

// 			std.Emit(
// 				"ProtocolFeeExternalPenalty",
// 				"prevAddr", prevAddr,
// 				"prevRealm", prevRealm,
// 				"lpTokenId", ufmt.Sprintf("%d", tokenId),
// 				"internal_poolPath", poolPath,
// 				"internal_incentiveId", incentiveId,
// 				"internal_tokenPath", external.tokenPath,
// 				"internal_amount", ufmt.Sprintf("%d", left),
// 			)

// 			incentive.rewardLeft = new(u256.Uint).Sub(incentive.rewardLeft, u256.NewUint(fullAmount))
// 			incentives.Set(incentiveId, incentive)

// 			if external.tokenPath == consts.GNS_PATH {
// 				externalGns[incentiveId] -= fullAmount
// 			}

// 			std.Emit(
// 				"CollectRewardExternal",
// 				"prevAddr", prevAddr,
// 				"prevRealm", prevRealm,
// 				"lpTokenId", ufmt.Sprintf("%d", tokenId),
// 				"internal_poolPath", poolPath,
// 				"internal_incentiveId", incentiveId,
// 				"internal_rewardToken", external.tokenPath,
// 				"internal_recipient", deposit.owner.String(),
// 				"internal_amount", ufmt.Sprintf("%d", toUser),
// 				"internal_unwrapResult", ufmt.Sprintf("%t", unwrapResult),
// 			)
// 		}
// 	}

// 	// INTERNAL gns emission
// 	internalWarmUpAmount, exist := positionsInternalWarmUpAmount[tokenId]
// 	if !exist {
// 		return poolPath
// 	}
// 	fullAmount := internalWarmUpAmount.full30 + internalWarmUpAmount.full50 + internalWarmUpAmount.full70 + internalWarmUpAmount.full100
// 	toGive := internalWarmUpAmount.give30 + internalWarmUpAmount.give50 + internalWarmUpAmount.give70 + internalWarmUpAmount.full100

// 	if toGive == 0 {
// 		return poolPath
// 	}
// 	toUser := handleUnstakingFee(consts.GNS_PATH, toGive, true, tokenId, poolPath)
// 	gns.Transfer(a2u(deposit.owner), toUser)

// 	// delete(positionsInternalWarmUpAmount, tokenId) // DO NOT DELETE
// 	positionsInternalWarmUpAmount[tokenId] = warmUpAmount{} // JUST CLEAR

// 	poolGns[poolPath] -= fullAmount

// 	left := fullAmount - toGive
// 	gns.Transfer(a2u(consts.COMMUNITY_POOL_ADDR), left)
// 	std.Emit(
// 		"CommunityPoolEmissionPenalty",
// 		"prevAddr", prevAddr,
// 		"prevRealm", prevRealm,
// 		"lpTokenId", ufmt.Sprintf("%d", tokenId),
// 		"internal_poolPath", poolPath,
// 		"internal_incentiveId", "INTERNAL",
// 		"internal_tokenPath", consts.GNS_PATH,
// 		"internal_amount", ufmt.Sprintf("%d", left),
// 	)

// 	std.Emit(
// 		"CollectRewardEmission",
// 		"prevAddr", prevAddr,
// 		"prevRealm", prevRealm,
// 		"lpTokenId", ufmt.Sprintf("%d", tokenId),
// 		"internal_poolPath", poolPath,
// 		"internal_incentiveId", "INTERNAL",
// 		"internal_rewardToken", consts.GNS_PATH,
// 		"internal_recipient", deposit.owner.String(),
// 		"internal_fullAmount", ufmt.Sprintf("%d", fullAmount),
// 		"internal_toGive", ufmt.Sprintf("%d", toGive),
// 		"internal_amount", ufmt.Sprintf("%d", toUser),
// 		"internal_unstakingFee", ufmt.Sprintf("%d", toGive-toUser),
// 		"internal_left", ufmt.Sprintf("%d", left),
// 	)

// 	// UPDATE stakerGns Balance for calculate_pool_position_reward
// 	lastCalculatedBalance = gnsBalance(consts.STAKER_ADDR) - externalGnsAmount() - externalDepositGnsAmount()

// 	return poolPath
// }

// UnstakeToken unstakes the LP token from the staker and collects all reward from tokenId
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
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("staker.gno__UnstakeToken() || tokenId(%d) not staked", tokenId),
		))
	}

	// Claim All Rewards
	CollectReward(tokenId, unwrapResult)

	delete(positionGns, tokenId)
	delete(positionsInternalWarmUpAmount, tokenId)
	deposits.Remove(tokenId)

	rewardManger := getRewardManager()
	internalEmission := rewardManger.GetInternalEmissionReward()
	internalEmission.RemoveInRangePosition(deposit.targetPoolPath, tokenId)
	rewardManger.SetInternalEmissionReward(internalEmission)

	// transfer NFT ownership to origin owner
	gnft.TransferFrom(a2u(consts.STAKER_ADDR), a2u(deposit.owner), tid(tokenId))
	pn.SetPositionOperator(tokenId, consts.ZERO_ADDRESS)

	poolPath := pn.PositionGetPositionPoolKey(tokenId)
	token0Amount, token1Amount := getTokenPairBalanceFromPosition(tokenId)

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"UnstakeToken",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"lpTokenId", ufmt.Sprintf("%d", tokenId),
		"unwrapResult", ufmt.Sprintf("%t", unwrapResult),
		"internal_poolPath", poolPath,
		"internal_from", GetOrigPkgAddr().String(),
		"internal_to", deposit.owner.String(),
		"internal_amount0", token0Amount,
		"internal_amount1", token1Amount,
	)

	return poolPath, token0Amount, token1Amount
}

// requireTokenOwnership checks if the caller has the token ownership
func requireTokenOwnership(owner, caller std.Address) error {
	callerIsOwner := owner == caller
	stakerIsOwner := owner == consts.STAKER_ADDR

	if err := common.SatisfyCond(callerIsOwner || stakerIsOwner); err != nil {
		return errNoPermission
	}

	return nil
}

// poolHasIncentives checks if the target pool has internal or external incentive
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

// tokenHasLiquidity checks if the target tokenId has liquidity
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

func poolHasInternal(poolPath string) bool {
	_, exist := poolTiers.Get(poolPath)
	return exist
}

func poolHasExternal(poolPath string) bool {
	_, exist := poolIncentives.Get(poolPath)
	return exist
}

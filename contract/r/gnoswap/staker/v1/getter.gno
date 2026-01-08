package v1

import (
	"chain/runtime"
	"time"

	"gno.land/p/nt/ufmt"
	"gno.land/p/onbloc/json"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/gns"
	sr "gno.land/r/gnoswap/staker"
)

// getPoolByPoolPath retrieves the pool by its path.
func (s *stakerV1) getPoolByPoolPath(poolPath string) *sr.Pool {
	result, ok := s.store.GetPools().Get(poolPath)
	if !ok {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath)),
		)
	}

	pool, ok := result.(*sr.Pool)
	if !ok {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath)),
		)
	}

	return pool
}

// GetPoolIncentiveIdList returns all incentive IDs for a pool.
func (s *stakerV1) GetPoolIncentiveIdList(poolPath string) []string {
	pool := s.getPoolByPoolPath(poolPath)

	incentives := pool.Incentives()

	ids := []string{}
	incentives.IncentiveTrees().Iterate("", "", func(key string, value any) bool {
		ids = append(ids, key)
		return false
	})

	return ids
}

// getIncentive retrieves an external incentive by ID.
func (s *stakerV1) getIncentive(poolPath string, incentiveId string) *sr.ExternalIncentive {
	pool := s.getPoolByPoolPath(poolPath)

	incentives := pool.Incentives()
	incentive, exist := incentives.IncentiveTrees().Get(incentiveId)
	if !exist {
		panic(ufmt.Sprintf("incentiveId(%s) incentive does not exist", incentiveId))
	}

	ictv, ok := incentive.(*sr.ExternalIncentive)
	if !ok {
		panic(ufmt.Sprintf("failed to cast incentive to *ExternalIncentive: %T", incentive))
	}
	return ictv
}

// GetIncentiveStartTimestamp returns the start timestamp of an incentive.
func (s *stakerV1) GetIncentiveStartTimestamp(poolPath string, incentiveId string) int64 {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.StartTimestamp()
}

// GetIncentiveEndTimestamp returns the end timestamp of an incentive.
func (s *stakerV1) GetIncentiveEndTimestamp(poolPath string, incentiveId string) int64 {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.EndTimestamp()
}

// GetTargetPoolPathByIncentiveId returns the target pool path of an incentive.
func (s *stakerV1) GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) string {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.TargetPoolPath()
}

// GetCreatedHeightOfIncentive returns the creation height of an incentive.
func (s *stakerV1) GetCreatedHeightOfIncentive(poolPath string, incentiveId string) int64 {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.CreatedHeight()
}

// GetIncentiveCreatedTimestamp returns the creation timestamp of an incentive.
func (s *stakerV1) GetIncentiveCreatedTimestamp(poolPath string, incentiveId string) int64 {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.CreatedTimestamp()
}

// GetIncentiveTotalRewardAmount returns the total reward amount of an incentive.
func (s *stakerV1) GetIncentiveTotalRewardAmount(poolPath string, incentiveId string) int64 {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.TotalRewardAmount()
}

// GetIncentiveDistributedRewardAmount returns the distributed reward amount of an incentive.
func (s *stakerV1) GetIncentiveDistributedRewardAmount(poolPath string, incentiveId string) int64 {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.DistributedRewardAmount()
}

// GetIncentiveRemainingRewardAmount returns the remaining reward amount of an incentive.
func (s *stakerV1) GetIncentiveRemainingRewardAmount(poolPath string, incentiveId string) int64 {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.RewardAmount()
}

// GetIncentiveDepositGnsAmount returns the deposit GNS amount of an incentive.
func (s *stakerV1) GetIncentiveDepositGnsAmount(poolPath string, incentiveId string) int64 {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.DepositGnsAmount()
}

// GetIncentiveRefunded returns whether an incentive has been refunded.
func (s *stakerV1) GetIncentiveRefunded(poolPath string, incentiveId string) bool {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.Refunded()
}

// IsIncentiveActive returns whether an incentive is currently active.
func (s *stakerV1) IsIncentiveActive(poolPath string, incentiveId string) bool {
	incentive := s.getIncentive(poolPath, incentiveId)
	currentTime := time.Now().Unix()

	resolver := NewExternalIncentiveResolver(incentive)
	return resolver.IsStarted(currentTime) && !resolver.IsEnded(currentTime) && !resolver.Refunded()
}

// GetIncentiveRewardToken returns the reward token of an incentive.
func (s *stakerV1) GetIncentiveRewardToken(poolPath string, incentiveId string) string {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.RewardToken()
}

// GetIncentiveRewardAmount returns the reward amount of an incentive.
func (s *stakerV1) GetIncentiveRewardAmount(poolPath string, incentiveId string) *u256.Uint {
	incentive := s.getIncentive(poolPath, incentiveId)

	return u256.NewUintFromInt64(incentive.RewardAmount())
}

// GetIncentiveRewardAmountAsString returns the reward amount of an incentive as string.
func (s *stakerV1) GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) string {
	rewardAmount := s.GetIncentiveRewardAmount(poolPath, incentiveId)

	return rewardAmount.ToString()
}

// GetIncentiveRewardPerSecond returns the reward per second of an incentive.
func (s *stakerV1) GetIncentiveRewardPerSecond(poolPath string, incentiveId string) int64 {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.RewardPerSecond()
}

// GetIncentiveRefundee returns the refundee address of an incentive.
func (s *stakerV1) GetIncentiveRefundee(poolPath string, incentiveId string) address {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.Refundee()
}

// getDeposit retrieves a deposit by LP token ID.
func (s *stakerV1) getDeposit(lpTokenId uint64) *sr.Deposit {
	deposit := s.getDeposits().get(lpTokenId)
	if deposit == nil {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("lpTokenId(%d) deposit does not exist", lpTokenId)),
		)
	}

	return deposit
}

// GetDepositOwner returns the owner of a deposit.
func (s *stakerV1) GetDepositOwner(lpTokenId uint64) address {
	deposit := s.getDeposit(lpTokenId)

	return deposit.Owner()
}

// GetDepositStakeTime returns the stake time of a deposit.
func (s *stakerV1) GetDepositStakeTime(lpTokenId uint64) int64 {
	deposit := s.getDeposit(lpTokenId)

	return deposit.StakeTime()
}

// GetDepositTargetPoolPath returns the target pool path of a deposit.
func (s *stakerV1) GetDepositTargetPoolPath(lpTokenId uint64) string {
	deposit := s.getDeposit(lpTokenId)

	return deposit.TargetPoolPath()
}

// GetDepositTickLower returns the lower tick of a deposit.
func (s *stakerV1) GetDepositTickLower(lpTokenId uint64) int32 {
	deposit := s.getDeposit(lpTokenId)

	return deposit.TickLower()
}

// GetDepositTickUpper returns the upper tick of a deposit.
func (s *stakerV1) GetDepositTickUpper(lpTokenId uint64) int32 {
	deposit := s.getDeposit(lpTokenId)

	return deposit.TickUpper()
}

// GetDepositLiquidity returns the liquidity of a deposit.
func (s *stakerV1) GetDepositLiquidity(lpTokenId uint64) *u256.Uint {
	deposit := s.getDeposit(lpTokenId)

	return deposit.Liquidity().Clone()
}

// GetDepositLiquidityAsString returns the liquidity of a deposit as string.
func (s *stakerV1) GetDepositLiquidityAsString(lpTokenId uint64) string {
	liquidity := s.GetDepositLiquidity(lpTokenId)

	return liquidity.ToString()
}

// GetDepositInternalRewardLastCollectTimestamp returns the last collect timestamp of a deposit.
func (s *stakerV1) GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) int64 {
	deposit := s.getDeposit(lpTokenId)

	return deposit.InternalRewardLastCollectTime()
}

// GetDepositStakeTimestamp returns the staking timestamp of a deposit.
func (s *stakerV1) GetDepositStakeTimestamp(lpTokenId uint64) int64 {
	deposit := s.getDeposit(lpTokenId)

	return deposit.StakeTime()
}

// GetDepositCollectedInternalReward returns the collected internal reward amount.
func (s *stakerV1) GetDepositCollectedInternalReward(lpTokenId uint64) int64 {
	deposit := s.getDeposit(lpTokenId)

	return deposit.CollectedInternalReward()
}

// GetDepositCollectedExternalReward returns the collected external reward amount for an incentive.
func (s *stakerV1) GetDepositCollectedExternalReward(lpTokenId uint64, incentiveId string) int64 {
	return s.getDepositResolver(lpTokenId).CollectedExternalReward(incentiveId)
}

// GetDepositExternalRewardLastCollectTimestamp returns the last collect timestamp of a deposit.
func (s *stakerV1) GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) int64 {
	return s.getDepositResolver(lpTokenId).ExternalRewardLastCollectTime(incentiveId)
}

// GetDepositWarmUp returns the warm-up records of a deposit.
func (s *stakerV1) GetDepositWarmUp(lpTokenId uint64) []sr.Warmup {
	deposit := s.getDeposit(lpTokenId)

	return deposit.Warmups()
}

// GetDepositExternalIncentiveIdList returns external incentive IDs for a deposit.
func (s *stakerV1) GetDepositExternalIncentiveIdList(lpTokenId uint64) []string {
	deposit := s.getDeposit(lpTokenId)

	return deposit.GetExternalIncentiveIdList()
}

// GetPoolTier returns the tier of a pool.
func (s *stakerV1) GetPoolTier(poolPath string) uint64 {
	return s.getPoolTier().CurrentTier(poolPath)
}

// GetPoolTierRatio returns the current reward ratio for a pool's tier.
func (s *stakerV1) GetPoolTierRatio(poolPath string) uint64 {
	tier := s.GetPoolTier(poolPath)
	ratio, err := s.getPoolTier().tierRatio.Get(tier)
	if err != nil {
		panic(makeErrorWithDetails(errInvalidPoolTier, err.Error()))
	}

	return ratio
}

// GetPoolTierCount returns the number of pools in a tier.
func (s *stakerV1) GetPoolTierCount(tier uint64) uint64 {
	if tier == 0 {
		return 0
	}
	return uint64(s.getPoolTier().CurrentCount(tier))
}

// GetPoolReward returns the current reward amount for a tier.
func (s *stakerV1) GetPoolReward(tier uint64) int64 {
	return s.getPoolTier().CurrentReward(tier)
}

// GetPoolStakedLiquidity returns the current total staked liquidity of a pool.
func (s *stakerV1) GetPoolStakedLiquidity(poolPath string) string {
	pool := s.getPoolByPoolPath(poolPath)
	liquidity := NewPoolResolver(pool).CurrentStakedLiquidity(time.Now().Unix())
	if liquidity == nil {
		return u256.Zero().ToString()
	}

	return liquidity.ToString()
}

// GetPoolsByTier returns the list of pools in a tier.
func (s *stakerV1) GetPoolsByTier(tier uint64) []string {
	if tier == 0 {
		return []string{}
	}

	pools := make([]string, 0)
	s.getPoolTier().membership.Iterate("", "", func(poolPath string, value any) bool {
		currentTier, ok := value.(uint64)
		if !ok {
			panic("failed to cast tier to uint64")
		}
		if currentTier == tier {
			pools = append(pools, poolPath)
		}
		return false
	})

	return pools
}

// GetTotalEmissionSent returns the total GNS emission sent.
func (s *stakerV1) GetTotalEmissionSent() int64 {
	return s.store.GetTotalEmissionSent()
}

// GetAllowedTokens returns the allowed external incentive token list.
func (s *stakerV1) GetAllowedTokens() []string {
	tokens := s.store.GetAllowedTokens()
	result := make([]string, len(tokens))
	copy(result, tokens)
	return result
}

// GetWarmupTemplate returns the current warmup template.
func (s *stakerV1) GetWarmupTemplate() []sr.Warmup {
	warmups := s.store.GetWarmupTemplate()
	result := make([]sr.Warmup, len(warmups))
	copy(result, warmups)
	return result
}

// GetTotalStakedPositionCount returns the total staked position count.
func (s *stakerV1) GetTotalStakedPositionCount() uint64 {
	total := uint64(0)
	s.getStakers().tree.Iterate("", "", func(_ string, value any) bool {
		depositTree := retrieveDepositTree(value)
		total += uint64(depositTree.Size())
		return false
	})
	return total
}

// GetStakedPositionsByOwner returns staked position IDs for an owner.
func (s *stakerV1) GetStakedPositionsByOwner(owner address) []uint64 {
	positions := make([]uint64, 0, depositTree.Size())

	depositTreeI, ok := s.getStakers().tree.Get(owner.String())
	if !ok {
		return positions
	}

	depositTree := retrieveDepositTree(depositTreeI)
	depositTree.Iterate("", "", func(depositId string, _ any) bool {
		positions = append(positions, sr.DecodeUint(depositId))
		return false
	})

	return positions
}

// GetExternalIncentiveByPoolPath returns all external incentives for a pool.
func (s *stakerV1) GetExternalIncentiveByPoolPath(poolPath string) []sr.ExternalIncentive {
	incentives := make([]sr.ExternalIncentive, 0)

	s.store.GetExternalIncentives().Iterate("", "", func(_ string, value any) bool {
		incentive, ok := value.(*sr.ExternalIncentive)
		if !ok {
			panic("failed to cast value to *ExternalIncentive")
		}
		if incentive.TargetPoolPath() == poolPath {
			incentives = append(incentives, *incentive)
		}
		return false
	})

	return incentives
}

// makeExternalPositionsNode creates JSON nodes for external position data.
func makeExternalPositionsNode(positions []ApiExternalDebugPosition) []*json.Node {
	externalPositions := make([]*json.Node, 0)
	currentTime := time.Now().Unix()

	for _, externalPosition := range positions {
		incentives := make([]*json.Node, 0)
		for _, incentive := range externalPosition.Incentive {
			stakedOrExternalDuration := currentTime - max(incentive.StartTimestamp, externalPosition.StakedTime)
			if stakedOrExternalDuration < 0 {
				stakedOrExternalDuration = 0
			}

			incentives = append(incentives, json.ObjectNode("", map[string]*json.Node{
				"poolPath":                 json.StringNode("poolPath", incentive.PoolPath),
				"rewardToken":              json.StringNode("rewardToken", incentive.RewardToken),
				"rewardAmount":             json.StringNode("rewardAmount", incentive.RewardAmount),
				"startTimestamp":           json.NumberNode("startTimestamp", float64(incentive.StartTimestamp)),
				"endTimestamp":             json.NumberNode("endTimestamp", float64(incentive.EndTimestamp)),
				"rewardPerSecond":          json.StringNode("rewardPerSecond", incentive.RewardPerSecond),
				"stakedOrExternalDuration": json.NumberNode("stakedOrExternalDuration", float64(stakedOrExternalDuration)),
				"tokenAmountFull":          json.NumberNode("tokenAmountFull", float64(incentive.TokenAmountFull)),
				"tokenAmountToGive":        json.NumberNode("tokenAmountToGive", float64(incentive.TokenAmountToGive)),
			}))
		}

		externalPositions = append(externalPositions, json.ObjectNode("", map[string]*json.Node{
			"lpTokenId":       json.NumberNode("lpTokenId", float64(externalPosition.PositionId)),
			"stakedTime":      json.NumberNode("stakedTime", float64(externalPosition.StakedTime)),
			"stakedTimestamp": json.NumberNode("stakedTimestamp", float64(externalPosition.StakedTimestamp)),
			"incentive":       json.ArrayNode("", incentives),
		}))
	}

	return externalPositions
}

type currentExternalInfo struct {
	height             int64
	time               int64
	externalIncentives []sr.ExternalIncentive
}

type ApiExternalDebugInfo struct {
	Height   int64                      `json:"height"`
	Time     int64                      `json:"time"`
	Position []ApiExternalDebugPosition `json:"pool"`
}

type ApiExternalDebugPosition struct {
	PositionId      uint64                      `json:"positionId"`
	StakedTime      int64                       `json:"stakedTime"`
	StakedTimestamp int64                       `json:"stakedTimestamp"`
	Incentive       []ApiExternalDebugIncentive `json:"incentive"`
}

type ApiExternalDebugIncentive struct {
	PoolPath           string  `json:"poolPath"`
	IncentiveId        string  `json:"incentiveId"`
	RewardToken        string  `json:"rewardToken"`
	RewardAmount       string  `json:"rewardAmount"`
	StartTimestamp     int64   `json:"startTimestamp"`
	EndTimestamp       int64   `json:"endTimestamp"`
	RewardPerSecondX96 string  `json:"rewardPerSecondX96"`
	RewardPerSecond    string  `json:"rewardPerSecond"`
	Refundee           address `json:"refundee"`
	StartHeight        int64   `json:"startHeight"`
	EndHeight          int64   `json:"endHeight"`
	// FROM positionExternal -> externalRewards
	TokenAmountX96    *u256.Uint `json:"tokenAmountX96"`
	TokenAmount       int64      `json:"tokenAmount"`
	TokenAmountFull   int64      `json:"tokenAmountFull"`
	TokenAmountToGive int64      `json:"tokenAmountToGive"`
	// FROM externalWarmUpAmount
	Full30  int64 `json:"full30"`
	Give30  int64 `json:"give30"`
	Full50  int64 `json:"full50"`
	Give50  int64 `json:"give50"`
	Full70  int64 `json:"full70"`
	Give70  int64 `json:"give70"`
	Full100 int64 `json:"full100"`
}

// DEBUG INTERNAL (GNS EMISSION)
type currentInfo struct {
	height           int64
	time             int64
	gnsStaker        int64
	gnsDevOps        int64
	gnsCommunityPool int64
	gnsGovStaker     int64
	gnsProtocolFee   int64
	gnsADMIN         int64
}

// getCurrentInfo returns current GNS balance information for system addresses.
func getCurrentInfo() currentInfo {
	return currentInfo{
		height:           runtime.ChainHeight(),
		time:             time.Now().Unix(),
		gnsStaker:        gns.BalanceOf(stakerAddr),
		gnsDevOps:        gns.BalanceOf(devOpsAddr),
		gnsCommunityPool: gns.BalanceOf(communityPoolAddr),
		gnsGovStaker:     gns.BalanceOf(govStakerAddr),
		gnsProtocolFee:   gns.BalanceOf(protocolFeeAddr),
		gnsADMIN:         gns.BalanceOf(adminAddr),
	}
}

package staker

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/onbloc/json"
	"gno.land/p/nt/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/gns"
)

// getPoolByPoolPath retrieves the pool by its path.
func getPoolByPoolPath(poolPath string) *Pool {
	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath)),
		)
	}

	return pool
}

// GetPoolIncentiveIdList returns all incentive IDs for a pool.
func GetPoolIncentiveIdList(poolPath string) []string {
	pool := getPoolByPoolPath(poolPath)

	ids := make([]string, 0)
	pool.incentives.incentives.Iterate("", "", func(key string, value any) bool {
		ids = append(ids, key)
		return true
	})

	return ids
}

// getIncentive retrieves an external incentive by ID.
func getIncentive(poolPath string, incentiveId string) *ExternalIncentive {
	pool := getPoolByPoolPath(poolPath)

	incentive, exist := pool.incentives.incentives.Get(incentiveId)
	if !exist {
		panic(ufmt.Sprintf("incentiveId(%s) incentive does not exist", incentiveId))
	}

	ictv, ok := incentive.(*ExternalIncentive)
	if !ok {
		panic(ufmt.Sprintf("failed to cast incentive to *ExternalIncentive: %T", incentive))
	}
	return ictv
}

// GetIncentiveStartTimestamp returns the start timestamp of an incentive.
func GetIncentiveStartTimestamp(poolPath string, incentiveId string) int64 {
return getIncentive(poolPath, incentiveId).startTimestamp }

// GetIncentiveEndTimestamp returns the end timestamp of an incentive.
func GetIncentiveEndTimestamp(poolPath string, incentiveId string) int64 {
	return getIncentive(poolPath, incentiveId).endTimestamp
}

// GetTargetPoolPathByIncentiveId returns the target pool path of an incentive.
func GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) string {
	return getIncentive(poolPath, incentiveId).targetPoolPath
}

// GetCreatedHeightOfIncentive returns the creation height of an incentive.
func GetCreatedHeightOfIncentive(poolPath string, incentiveId string) int64 {
	return getIncentive(poolPath, incentiveId).createdHeight
}

// GetIncentiveRewardToken returns the reward token of an incentive.
func GetIncentiveRewardToken(poolPath string, incentiveId string) string {
	return getIncentive(poolPath, incentiveId).rewardToken
}

// GetIncentiveRewardAmount returns the reward amount of an incentive.
func GetIncentiveRewardAmount(poolPath string, incentiveId string) *u256.Uint {
	amount := getIncentive(poolPath, incentiveId).rewardAmount
	return u256.NewUintFromInt64(amount)
}

// GetIncentiveRewardAmountAsString returns the reward amount of an incentive as string.
func GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) string {
	return GetIncentiveRewardAmount(poolPath, incentiveId).ToString()
}

// GetIncentiveRefundee returns the refundee address of an incentive.
func GetIncentiveRefundee(poolPath string, incentiveId string) std.Address {
	return getIncentive(poolPath, incentiveId).refundee
}

// getDeposit retrieves a deposit by LP token ID.
func getDeposit(lpTokenId uint64) *Deposit {
	deposit := deposits.get(lpTokenId)
	if deposit == nil {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("lpTokenId(%d) deposit does not exist", lpTokenId)),
		)
	}

	return deposit
}

// GetDepositOwner returns the owner of a deposit.
func GetDepositOwner(lpTokenId uint64) std.Address {
	return getDeposit(lpTokenId).owner
}

// GetDepositStakeTimestamp returns the stake timestamp of a deposit.
func GetDepositStakeTimestamp(lpTokenId uint64) int64 {
	return getDeposit(lpTokenId).stakeTime
}

// GetDepositTargetPoolPath returns the target pool path of a deposit.
func GetDepositTargetPoolPath(lpTokenId uint64) string {
	return getDeposit(lpTokenId).targetPoolPath
}

// GetDepositTickLower returns the lower tick of a deposit.
func GetDepositTickLower(lpTokenId uint64) int32 {
	return getDeposit(lpTokenId).tickLower
}

// GetDepositTickUpper returns the upper tick of a deposit.
func GetDepositTickUpper(lpTokenId uint64) int32 {
	return getDeposit(lpTokenId).tickUpper
}

// GetDepositLiquidity returns the liquidity of a deposit.
func GetDepositLiquidity(lpTokenId uint64) *u256.Uint {
	return getDeposit(lpTokenId).liquidity.Clone()
}

// GetDepositLiquidityAsString returns the liquidity of a deposit as string.
func GetDepositLiquidityAsString(lpTokenId uint64) string {
	return GetDepositLiquidity(lpTokenId).ToString()
}

// GetDepositLastCollectTimestamp returns the last collect timestamp of a deposit.
func GetDepositLastCollectTimestamp(lpTokenId uint64) int64 {
	return getDeposit(lpTokenId).lastCollectTime
}

// GetDepositWarmUp returns the warm-up records of a deposit.
func GetDepositWarmUp(lpTokenId uint64) []Warmup {
	return getDeposit(lpTokenId).warmups
}

// GetPoolTier returns the tier of a pool.
func GetPoolTier(poolPath string) uint64 {
	return poolTier.CurrentTier(poolPath)
}

// GetPoolTierRatio returns the current reward ratio for a pool's tier.
func GetPoolTierRatio(poolPath string) uint64 {
	tier := GetPoolTier(poolPath)
	return poolTier.tierRatio.Get(tier)
}

// GetPoolTierCount returns the number of pools in a tier.
func GetPoolTierCount(tier uint64) uint64 {
	if tier == 0 {
		return 0
	}
	return uint64(poolTier.CurrentCount(tier))
}

// GetPoolReward returns the current reward amount for a tier.
func GetPoolReward(tier uint64) int64 {
	return poolTier.CurrentReward(tier)
}

// GetExternalIncentiveByPoolPath returns all external incentives for a pool.
func GetExternalIncentiveByPoolPath(poolPath string) []ExternalIncentive {
	incentives := []ExternalIncentive{}
	externalIncentives.tree.Iterate("", "", func(key string, value any) bool {
		incentive, ok := value.(*ExternalIncentive)
		if !ok {
			panic("failed to cast value to *ExternalIncentive")
		}
		if incentive.targetPoolPath == poolPath {
			incentives = append(incentives, *incentive)
		}
		return false
	})

	return incentives
}

// GetPrintExternalInfo returns a JSON representation of external incentive debug information.
func GetPrintExternalInfo() string {
	externalDebug := ApiExternalDebugInfo{
		Height: std.ChainHeight(),
		Time:   time.Now().Unix(),
	}

	externalPositions := []ApiExternalDebugPosition{}
	deposits.Iterate(uint64(0), uint64(deposits.Size()), func(positionId uint64, deposit *Deposit) bool {
		externalPosition := ApiExternalDebugPosition{
			PositionId:      positionId,
			StakedTime:      deposit.stakeTime,
			StakedTimestamp: deposit.stakeTime,
		}

		externalIncentivesList := []ApiExternalDebugIncentive{}
		externalIncentives.tree.Iterate("", "", func(key string, value any) bool {
			incentive, ok := value.(*ExternalIncentive)
			if !ok {
				panic("failed to cast value to *ExternalIncentive")
			}
			if incentive.targetPoolPath == deposit.targetPoolPath {
				// Get pool to calculate actual rewards
				pool, exists := pools.Get(incentive.targetPoolPath)
				if !exists {
					return false
				}

				currentTime := time.Now().Unix()
				actualDistributed := pool.CalculateActualDistributedReward(
					incentive,
					incentive.startTimestamp,
					currentTime,
				)
				rewardLeft := incentive.rewardAmount - actualDistributed

				externalIncentive := ApiExternalDebugIncentive{
					PoolPath:          incentive.targetPoolPath,
					IncentiveId:       key,
					RewardToken:       incentive.rewardToken,
					RewardAmount:      strconv.FormatInt(incentive.rewardAmount, 10),
					RewardLeft:        strconv.FormatInt(rewardLeft, 10),
					StartTimestamp:    incentive.startTimestamp,
					EndTimestamp:      incentive.endTimestamp,
					Refundee:          incentive.refundee,
					TokenAmountFull:   incentive.depositGnsAmount,
					TokenAmountToGive: actualDistributed,
				}

				externalIncentivesList = append(externalIncentivesList, externalIncentive)
			}
			return false
		})

		externalPosition.Incentive = externalIncentivesList
		externalPositions = append(externalPositions, externalPosition)
		return false
	})

	externalDebug.Position = externalPositions

	// JSON Serialization
	node := json.ObjectNode("", map[string]*json.Node{
		"height":   json.NumberNode("", float64(externalDebug.Height)),
		"time":     json.NumberNode("", float64(externalDebug.Time)),
		"position": json.ArrayNode("", makeExternalPositionsNode(externalDebug.Position)),
	})

	b, err := json.Marshal(node)
	if err != nil {
		return "JSON MARSHAL ERROR"
	}

	return string(b)
}

// makeExternalPositionsNode creates JSON nodes for external position data.
func makeExternalPositionsNode(positions []ApiExternalDebugPosition) []*json.Node {
	externalPositions := make([]*json.Node, 0)

	for _, externalPosition := range positions {
		incentives := make([]*json.Node, 0)
		for _, incentive := range externalPosition.Incentive {
			stakedOrExternalDuration := std.ChainHeight() - max(incentive.StartHeight, externalPosition.StakedTime)

			incentives = append(incentives, json.ObjectNode("", map[string]*json.Node{
				"poolPath":                 json.StringNode("poolPath", incentive.PoolPath),
				"rewardToken":              json.StringNode("rewardToken", incentive.RewardToken),
				"rewardAmount":             json.StringNode("rewardAmount", incentive.RewardAmount),
				"rewardLeft":               json.StringNode("rewardLeft", incentive.RewardLeft),
				"startTimestamp":           json.NumberNode("startTimestamp", float64(incentive.StartTimestamp)),
				"endTimestamp":             json.NumberNode("endTimestamp", float64(incentive.EndTimestamp)),
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
	externalIncentives []ExternalIncentive
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
	PoolPath           string      `json:"poolPath"`
	IncentiveId        string      `json:"incentiveId"`
	RewardToken        string      `json:"rewardToken"`
	RewardAmount       string      `json:"rewardAmount"`
	RewardLeft         string      `json:"rewardLeft"`
	StartTimestamp     int64       `json:"startTimestamp"`
	EndTimestamp       int64       `json:"endTimestamp"`
	Refundee           std.Address `json:"refundee"`
	StartHeight        int64       `json:"startHeight"`
	EndHeight          int64       `json:"endHeight"`
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
		height:           std.ChainHeight(),
		time:             time.Now().Unix(),
		gnsStaker:        gns.BalanceOf(stakerAddr),
		gnsDevOps:        gns.BalanceOf(devOpsAddr),
		gnsCommunityPool: gns.BalanceOf(communityPoolAddr),
		gnsGovStaker:     gns.BalanceOf(govStakerAddr),
		gnsProtocolFee:   gns.BalanceOf(protocolFeeAddr),
		gnsADMIN:         gns.BalanceOf(adminAddr),
	}
}

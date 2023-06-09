package staker

import (
	"encoding/base64"
	"encoding/json"
	"std"
	"strings"

	"gno.land/p/demo/avl"
)

type ApiIncentivesInfo struct {
	Key       string
	StartTime bigint
	EndTime   bigint
	// Refundee std.Address
	// TotalRewardUnclaimed bigint
	// TotalSecondsClaimedX128 bigint
	NumberOfStakes bigint
}

type ApiDepositsInfo struct {
	TokenId        string
	Owner          std.Address
	NumberOfStakes bigint
	TickLower      bigint
	TickUpper      bigint
}

type ApiStakesInfo struct {
	TokenID                              string
	IncentiveID                          string
	StartTime                            bigint
	EndTime                              bigint
	Refundee                             std.Address
	SecondsPerLiquidityInsideInitialX128 bigint
	LiquidityNoOverflow                  bigint
	LiquidityIfOverflow                  bigint
}

type ApiRewardInfo struct {
	Address std.Address
	Reward  bigint
}

type ApiBasicInfo struct {
	Height    int64
	Timestamp int64
}

func ApiGetIncentivesInfo() string {
	abi := ApiBasicInfo{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	aii := getIncentivesList()

	r := struct {
		ApiBasicInfo
		IncentivesList []ApiIncentivesInfo
	}{
		abi,
		aii,
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(err)
	}

	return string(rr)
}

func ApiGetStakesInfo() string {
	abi := ApiBasicInfo{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	asi := getStakesList()

	r := struct {
		ApiBasicInfo
		StakesList []ApiStakesInfo
	}{
		abi,
		asi,
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(err)
	}

	return string(rr)
}

func ApiGetRewardInfo() string {
	abi := ApiBasicInfo{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	ari := getRewardList()

	r := struct {
		ApiBasicInfo
		RewardList []ApiRewardInfo
	}{
		abi,
		ari,
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(err)
	}

	return string(rr)
}

func getIncentivesList() []ApiIncentivesInfo {
	incentivesSize := incentives.Size()
	incentivesList := make([]ApiIncentivesInfo, incentivesSize)

	for i := 0; i < incentivesSize; i++ {
		key, value := incentives.GetByIndex(i)

		// decode key
		decoded, err := base64.StdEncoding.DecodeString(key)
		if err != nil {
			panic(err)
		}
		origKey := string(decoded)
		splitKey := strings.Split(origKey, "__")

		incentivesList[i] = ApiIncentivesInfo{
			Key:       key,
			StartTime: bigint(splitKey[0]),
			EndTime:   bigint(splitKey[1]),
			// Refundee: std.Address(splitKey[2]),
			// TotalRewardUnclaimed: value.(Incentive).totalRewardUnclaimed,
			// TotalSecondsClaimedX128: value.(Incentive).totalSecondsClaimedX128,
			NumberOfStakes: value.(Incentive).numberOfStakes,
		}
	}

	return incentivesList
}

func getStakesList() []ApiStakesInfo {
	stakesOuterSize := stakes.Size()
	var totalSize int

	for i := 0; i < stakesOuterSize; i++ {
		_, value := stakes.GetByIndex(i)

		_inner := value.(avl.Tree)
		inner := _inner.(avl.Tree)
		totalSize += inner.Size()
	}

	stakesSize := totalSize
	stakesList := make([]ApiStakesInfo, stakesSize)

	for j := 0; j < stakesOuterSize; j++ {
		tid, value := stakes.GetByIndex(j)

		_inner := value.(avl.Tree)
		inner := _inner.(avl.Tree)

		for k := 0; k < inner.Size(); k++ {
			fk, fv := inner.GetByIndex(k)

			// decode key
			decoded, err := base64.StdEncoding.DecodeString(fk)
			if err != nil {
				panic(err)
			}

			origKey := string(decoded)
			splitKey := strings.Split(origKey, "__")

			sfv := fv.(Stake)

			stakesList[k] = ApiStakesInfo{
				TokenID:                              string(tid),
				IncentiveID:                          fk,
				StartTime:                            bigint(splitKey[0]),
				EndTime:                              bigint(splitKey[1]),
				Refundee:                             std.Address(splitKey[2]),
				SecondsPerLiquidityInsideInitialX128: sfv.secondsPerLiquidityInsideInitialX128,
				LiquidityNoOverflow:                  sfv.liquidityNoOverflow,
				LiquidityIfOverflow:                  sfv.liquidityIfOverflow,
			}
		}
	}

	return stakesList
}

func getRewardList() []ApiRewardInfo {
	rewardSize := rewards.Size()
	rewardList := make([]ApiRewardInfo, rewardSize)

	for i := 0; i < rewardSize; i++ {
		key, value := rewards.GetByIndex(i)

		rewardList[i] = ApiRewardInfo{
			Address: std.Address(key),
			Reward:  value.(bigint),
		}
	}

	return rewardList
}

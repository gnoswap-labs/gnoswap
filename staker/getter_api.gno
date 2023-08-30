package staker

import (
	b64 "encoding/base64"
	"encoding/json"
	"strings"

	"gno.land/p/demo/ufmt"
)

type ApiQueryBase struct {
	Height    int64 `json:"height"`
	Timestamp int64 `json:"timestamp"`
}

type ApiIncentive struct {
	Key       string `json:"key"`
	StartTime string `json:"start_time"`
	EndTime   string `json:"end_time"`
	Refundee  string `json:"refundee"`
	NumStakes string `json:"num_stakes"`
}

type ResponseGetIncentives struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Data []ApiIncentive `json:"data"`
	} `json:"response"`
}

func ApiGetIncentives() string {
	incentiveList := []ApiIncentive{}

	for k, v := range incentives {
		st, et, rf := incentiveKeyDivide(k)

		si := ApiIncentive{
			Key:       k,
			StartTime: st,
			EndTime:   et,
			Refundee:  rf,
			NumStakes: string(v.numberOfStakes),
		}

		incentiveList = append(incentiveList, si)
	}

	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	r := ResponseGetIncentives{
		Stat: qb,
		Response: struct {
			Data []ApiIncentive `json:"data"`
		}{
			Data: incentiveList,
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		println("PANIC__ApiGetIncentives")
		panic(err)
	}

	return string(rr)
}

// since `stakes` var includes `incentives`
// below api might be duplicated wit ApiGetIncentives
// need further test, specially when relationships are N:N:N // r3v4_xxx
type ApiStake struct {
	TokenID     string `json:"token_id"`
	IncentiveID string `json:"incentive_id"`
	StartTime   string `json:"start_time"`
	EndTime     string `json:"end_time"`
	Refundee    string `json:"refundee"`
	// SecondsPerLiquidityInsideInitialX128 string `json:"seconds_per_liquidity_inside_initial_x128"`
	LiquidityNoOverflow string `json:"liquidity_no_overflow"`
	LiquidityIfOverflow string `json:"liquidity_if_overflow"`
}

type ResponseGetStakes struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Data []ApiStake `json:"data"`
	} `json:"response"`
}

func ApiGetStakes() string {
	stakeList := []ApiStake{}

	for k, v := range stakes {
		for k2, v2 := range v {
			st, et, rf := incentiveKeyDivide(k2)

			ss := ApiStake{
				TokenID:             string(k),
				IncentiveID:         k2,
				StartTime:           st,
				EndTime:             et,
				Refundee:            rf,
				LiquidityNoOverflow: string(v2.liquidityNoOverflow),
				LiquidityIfOverflow: string(v2.liquidityIfOverflow),
			}

			stakeList = append(stakeList, ss)
		}
	}

	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	r := ResponseGetStakes{
		Stat: qb,
		Response: struct {
			Data []ApiStake `json:"data"`
		}{
			Data: stakeList,
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] getter_api.ApiGetStakes() || %v", err))
	}

	return string(rr)
}

// xxx TBD when detailed stake logic is implemented
// func ApiGetDeposits() string {} // how lockDuartion will be handled
// func ApiGetReward() string {} // how reward will be calculated

func incentiveKeyDivide(incenKey string) (string, string, string) {
	// b64d
	kDec, _ := b64.StdEncoding.DecodeString(incenKey)
	incenKey = string(kDec)

	res := strings.Split(incenKey, "__")
	if len(res) != 3 {
		panic(ufmt.Sprintf("[STAKER] getter_api.gno__incentiveKeyDivide() || invalid incentiveKey(%s)", incenKey))
	}

	startTime, endTime, refundee := res[0], res[1], res[2]

	return startTime, endTime, refundee
}

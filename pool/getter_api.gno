package gnoswap

import (
	"encoding/base64"
	"encoding/json"
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
)

type ApiPoolInfo struct {
	Address      string
	Path         string
	Token0       string
	Token1       string
	Liquidity    bigint
	Token0Amount bigint
	Token1Amount bigint
	SwapFee      bigint
	ProtocolFees bigint
	MinTick      bigint
	MaxTick      bigint
}

type ApiTokenInfo struct {
	Name     string
	Symbol   string
	Decimals uint
	Path     string
}

type ApiUserInfo struct {
	OwedPosition []ApiPositionInfo
	Token0       string
	Token0Amount bigint
	Token1       string
	Token1Amount bigint
}

type ApiPositionInfo struct {
	Liquidity bigint

	FeeGrowthInside0LastX128 bigint
	FeeGrowthInside1LastX128 bigint

	TokensOwed0 bigint
	TokensOwed1 bigint

	TickLower bigint
	TickUpper bigint
}

type ApiBasicInfo struct {
	Height    int64
	Timestamp int64
}

func ApiGetPoolInfo() string {
	abi := ApiBasicInfo{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}
	api := ApiPoolInfo{
		Address:      GetOrigPkgAddr().String(),
		Path:         "d__gno.land/gnoswap/pool/91u24jfabj",
		Token0:       token0.GetName(),
		Token1:       token1.GetName(),
		Liquidity:    GetLiquidity(),
		Token0Amount: BalanceOf(token0, GetOrigPkgAddr()),
		Token1Amount: BalanceOf(token1, GetOrigPkgAddr()),
		SwapFee:      GetFee(),
		// swapFeeAmount: 123,
		ProtocolFees: GetSlot0().feeProtocol,
		// protocolFeeAmount: 123,
		MinTick: findMinTick(),
		MaxTick: findMaxTick(),
	}

	r := struct {
		ApiBasicInfo
		ApiPoolInfo
	}{
		abi,
		api,
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(err)
	}

	return string(rr)
}

func ApiGetTokenInfo(gat *grc20.AdminToken) string {
	abi := ApiBasicInfo{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}
	ati := ApiTokenInfo{
		Name:     gat.GetName(),
		Symbol:   gat.GetSymbol(),
		Decimals: gat.GetDecimals(),
		Path:     "d__gno.land/gnoswap/token/91u24jfabj",
	}

	r := struct {
		ApiBasicInfo
		ApiTokenInfo
	}{
		abi,
		ati,
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(err)
	}

	return string(rr)
}

func ApiGetUserInfo(addr string) string {
	abi := ApiBasicInfo{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}
	aui := ApiUserInfo{
		OwedPosition: userPosition(addr),
		Token0:       token0.GetName(),
		Token0Amount: BalanceOf(token0, s2a(addr)),
		Token1:       token1.GetName(),
		Token1Amount: BalanceOf(token1, s2a(addr)),
	}

	r := struct {
		ApiBasicInfo
		ApiUserInfo
	}{
		abi,
		aui,
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(err)
	}

	return string(rr)
}

func userPosition(addr string) []ApiPositionInfo { // []PositionInfo
	userPos := []ApiPositionInfo{}

	for _, key := range positionWithKeys() {
		decoded, _ := base64.StdEncoding.DecodeString(key)

		if strings.Contains(string(decoded), addr) {
			// userPos = append(userPos, positions[key])
			_tl := strings.Split(string(decoded), "__")[1]
			_tu := strings.Split(string(decoded), "__")[2]

			_userPos, exists := positions.Get(key) // return PositionInfo
			if exists {
				// userPos = append(userPos, _userPos.(ApiPositionInfo))
				_withTickUserPos := ApiPositionInfo{
					Liquidity:                _userPos.(PositionInfo).liquidity,
					FeeGrowthInside0LastX128: _userPos.(PositionInfo).feeGrowthInside0LastX128,
					FeeGrowthInside1LastX128: _userPos.(PositionInfo).feeGrowthInside1LastX128,
					TokensOwed0:              _userPos.(PositionInfo).tokensOwed0,
					TokensOwed1:              _userPos.(PositionInfo).tokensOwed1,
					TickLower:                bigint(_tl),
					TickUpper:                bigint(_tu),
				}
				userPos = append(userPos, _withTickUserPos)
			}
		}
	}
	return userPos
}

func positionWithKeys() []string {
	posSize := positions.Size()
	keys := make([]string, posSize)

	for i := 0; i < posSize; i++ {
		key, value := positions.GetByIndex(i)
		keys[i] = key
	}

	return keys
}

func tickRange() []bigint {
	tickList := []bigint{}
	ticks := GetTicks()

	for i := 0; i < ticks.Size(); i++ {
		key, _ := ticks.GetByIndex(i)
		tickList = append(tickList, bigint(key))
	}

	return tickList
}

func findMinTick() bigint {
	ticks := tickRange()
	min := ticks[0]

	for _, number := range ticks {
		if number < min {
			min = number
		}
	}

	return min
}

func findMaxTick() bigint {
	ticks := tickRange()
	max := ticks[0]

	for _, number := range ticks {
		if number > max {
			max = number
		}
	}

	return max
}

func s2a(addr string) std.Address {
	return std.Address(addr)
}

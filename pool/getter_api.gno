package gnoswap

import (
	"std"
	"strings"
	"encoding/base64"

	"gno.land/p/demo/grc/grc20"
)

type PoolInfo struct {
	Address				string
	Path					string
	token0				string
	token1				string
	liquidity			bigint
	token0Amount	bigint
	token1Amount	bigint
	swapFee				bigint
	protocolFees	bigint
	minTick				bigint
	maxTick				bigint
}

type TokenInfo struct {
	Name			string
	Symbol		string
	Decimals	uint
	Path			string
}

type UserInfo struct {
	OwedPosition []PositionInfo
	token0				string
	token0Amount	bigint
	token1				string
	token1Amount	bigint
}


func GetPoolInfo() PoolInfo {
	return PoolInfo{
		Address: GetOrigPkgAddr().String(),
		Path: "d__gno.land/gnoswap/pool/91u24jfabj",
		token0: token0.GetName(),
		token1: token1.GetName(),
		liquidity: GetLiquidity(),
		token0Amount: BalanceOf(token0, GetOrigPkgAddr()),
		token1Amount: BalanceOf(token1, GetOrigPkgAddr()),
		swapFee: GetFee(),
		// swapFeeAmount: 123,
		protocolFees: GetSlot0().feeProtocol,
		// protocolFeeAmount: 123,
		minTick: findMinTick(),
		maxTick: findMaxTick(),
	}
}

func GetTokenInfo(gat *grc20.AdminToken) TokenInfo {
	return TokenInfo{
		Name: gat.GetName(),
		Symbol: gat.GetSymbol(),
		Decimals: gat.GetDecimals(),
		Path: "d__gno.land/gnoswap/token/91u24jfabj",
	}
}

func GetUserInfo(addr string) UserInfo {
	return UserInfo{
		OwedPosition: userPosition(addr),
		token0: token0.GetName(),
		token0Amount: BalanceOf(token0, s2a(addr)),
		token1: token1.GetName(),
		token1Amount: BalanceOf(token1, s2a(addr)),
	}
}


func userPosition(addr string) []PositionInfo {
	userPos := []PositionInfo{}

	for _, key := range positionWithKeys() {		
		decoded, _ := base64.StdEncoding.DecodeString(key)
		// println("DECODED =>", string(decoded))
	
		if strings.Contains(string(decoded), addr) {
			// userPos = append(userPos, positions[key])
			
			_userPos, exists := positions.Get(key)
			if exists {
				userPos = append(userPos, _userPos.(PositionInfo))
			}
		}
	}
	return userPos
}

func positionWithKeys() []string {
	posSize := positions.Size()
	keys := make([]string, posSize)

	for i := 0; i < posSize; i++ {
		key, value := positions.GetByIndex(0)
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
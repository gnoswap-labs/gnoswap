package gnoswap

import (
	"encoding/base64"
	"sort"
	"std"
	"strings"
	"testing"

	"gno.land/p/demo/grc/grc20"
	"gno.land/r/demo/users"
)

type PoolInfo struct {
	Address      string
	Path         string
	token0       string
	token1       string
	liquidity    bigint
	token0Amount bigint
	token1Amount bigint
	swapFee      bigint
	protocolFees bigint
	minTick      bigint
	maxTick      bigint
}

func GetPoolInfo() PoolInfo {
	return PoolInfo{
		Address:      GetOrigPkgAddr().String(),
		Path:         "d__gno.land/gnoswap/pool/91u24jfabj",
		token0:       token0.GetName(),
		token1:       token1.GetName(),
		liquidity:    GetLiquidity(),
		token0Amount: BalanceOf(token0, GetOrigPkgAddr()),
		token1Amount: BalanceOf(token1, GetOrigPkgAddr()),
		swapFee:      GetFee(),
		// swapFeeAmount: 123,
		protocolFees: GetSlot0().feeProtocol,
		// protocolFeeAmount: 123,
		minTick: FindMin(),
		maxTick: FindMax(),
	}
}

func TestGetPoolInfo(t *testing.T) {
	pi := GetPoolInfo()
	// println(pi)
}

type TokenInfo struct {
	Name     string
	Symbol   string
	Decimals uint
	Path     string
}

func GetTokenInfo(gat *grc20.AdminToken) TokenInfo {
	return TokenInfo{
		Name:     gat.GetName(),
		Symbol:   gat.GetSymbol(),
		Decimals: gat.GetDecimals(),
		Path:     "d__gno.land/gnoswap/token/91u24jfabj",
	}
}

func TestGetTokenInfo(t *testing.T) {
	ti0 := GetTokenInfo(token0)
	// println(ti0)

	ti1 := GetTokenInfo(token1)
	// println(ti1)
}

type UserInfo struct {
	OwedPosition []PositionInfo
	token0       string
	token0Amount bigint
	token1       string
	token1Amount bigint
}

func GetUserInfo(addr string) UserInfo {
	return UserInfo{
		OwedPosition: UserPosition(addr),
		token0:       token0.GetName(),
		token0Amount: BalanceOf(token0, S2A(addr)),
		token1:       token1.GetName(),
		token1Amount: BalanceOf(token1, S2A(addr)),
	}
}

func TestGetUserInfo(t *testing.T) {
	ui := GetUserInfo("g1d3crqv2lta047h6lta047h6lta047h6lnjw069")
	// println(ui)
}

func UserPosition(addr string) []PositionInfo {
	userPos := []PositionInfo{}

	for _, key := range PositionWithKeys() {
		decoded, _ := base64.StdEncoding.DecodeString(key)

		if strings.Contains(string(decoded), addr) {
			userPos = append(userPos, positions[key])
		}
	}

	return userPos
}

func PositionWithKeys() []string {
	keys := make([]string, len(positions))
	i := 0

	for key := range positions {
		keys[i] = key
		i++
	}

	return keys
}

func TickRange() []bigint {
	tickList := []bigint{}
	for k := range GetTicks() {
		tickList = append(tickList, k)
	}

	return tickList
}

func FindMinMax() (bigint, bigint) {
	ticks := TickRange()

	min, max := ticks[0], ticks[0]

	for _, number := range ticks {
		if number < min {
			min = number
		}
		if number > max {
			max = number
		}
	}

	return min, max
}

func FindMin() bigint {
	ticks := TickRange()

	min := ticks[0]

	for _, number := range ticks {
		if number < min {
			min = number
		}
	}

	return min
}

func FindMax() bigint {
	ticks := TickRange()

	max := ticks[0]

	for _, number := range ticks {
		if number > max {
			max = number
		}
	}

	return max
}

func S2A(addr string) std.Address {
	return std.Address(addr)
}

package gnoswap

import (
	"std"

	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/r/demo/users"
)

var (
	lp01 = users.AddressOrName(testutils.TestAddress("lp01"))
	recv01 = users.AddressOrName(testutils.TestAddress("recv01"))
	recv02 = users.AddressOrName(testutils.TestAddress("recv02"))
)

func TestInit(t *testing.T) {
	// Init
	var fee uint64 = 0
	var tickSpacing bigint = 100
	var sqrtPrice bigdec = 8
	var tick bigint = 43946
	Init(fee, tickSpacing, sqrtPrice, tick)
}

func TestMint(t *testing.T) {
	// Mint
	var recipient std.Address = std.Address("g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5")
	var tickLower bigint = 200
	var tickUpper bigint = 45000
	var amount bigdec = 5000

	// - approve token for mint
	token0.Approve(lp01.Resolve(), GetOrigPkgAddr(), 10000)
	token1.Approve(lp01.Resolve(), GetOrigPkgAddr(), 10000)
	Mint(lp01.Resolve(), tickLower, tickUpper, amount) // liquidity amount
}
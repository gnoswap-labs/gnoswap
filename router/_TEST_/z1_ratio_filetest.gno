package main

import (
	"gno.land/p/demo/json"

	"std"
	"testing"

	"gno.land/r/demo/bar"
	"gno.land/r/demo/baz"
	"gno.land/r/demo/foo"
	"gno.land/r/demo/gns"
	"gno.land/r/demo/obl"
	"gno.land/r/demo/qux"
	"gno.land/r/demo/wugnot"

	pusers "gno.land/p/demo/users"

	"gno.land/r/demo/gnoswap/common"
	"gno.land/r/demo/gnoswap/consts"

	pl "gno.land/r/demo/pool"
	pn "gno.land/r/demo/position"
	rr "gno.land/r/demo/router"
)

var (
	gsa   std.Address = consts.GNOSWAP_ADMIN
	test1 std.Address = std.Address("g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5")

	fooPath string = "gno.land/r/demo/foo"
	barPath string = "gno.land/r/demo/bar"
	bazPath string = "gno.land/r/demo/baz"
	quxPath string = "gno.land/r/demo/qux"

	oblPath string = "gno.land/r/demo/obl"

	fee100  uint32 = 100
	fee500  uint32 = 500
	fee3000 uint32 = 3000

	max_timeout int64 = 9999999999

	maxApprove uint64 = 18446744073709551615

	// TESTING
	t *testing.T
)

type FooToken struct{}

func (FooToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return foo.Transfer
}
func (FooToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return foo.TransferFrom
}
func (FooToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return foo.BalanceOf
}
func (FooToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return foo.Approve
}

type BarToken struct{}

func (BarToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return bar.Transfer
}
func (BarToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return bar.TransferFrom
}
func (BarToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return bar.BalanceOf
}
func (BarToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return bar.Approve
}

type BazToken struct{}

func (BazToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return baz.Transfer
}
func (BazToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return baz.TransferFrom
}
func (BazToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return baz.BalanceOf
}
func (BazToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return baz.Approve
}

type QuxToken struct{}

func (QuxToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return qux.Transfer
}
func (QuxToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return qux.TransferFrom
}
func (QuxToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return qux.BalanceOf
}
func (QuxToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return qux.Approve
}

type WugnotToken struct{}

func (WugnotToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return wugnot.Transfer
}
func (WugnotToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return wugnot.TransferFrom
}
func (WugnotToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return wugnot.BalanceOf
}
func (WugnotToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return wugnot.Approve
}

type OBLToken struct{}

func (OBLToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return obl.Transfer
}
func (OBLToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return obl.TransferFrom
}
func (OBLToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return obl.BalanceOf
}
func (OBLToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return obl.Approve
}

type GNSToken struct{}

func (GNSToken) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return gns.Transfer
}

func (GNSToken) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return gns.TransferFrom
}

func (GNSToken) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return gns.BalanceOf
}

func (GNSToken) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return gns.Approve
}

/* HELPER FUNCTIONS */
func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func ugnotBalanceOf(addr std.Address) uint64 {
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)

	coins := testBanker.GetCoins(addr)
	if len(coins) == 0 {
		return 0
	}

	return uint64(testBanker.GetCoins(addr)[0].Amount)
}

func init() {
	// FAUCET
	std.TestSetPrevAddr(test1)

	for i := 0; i < 100; i++ {
		foo.Faucet()
		bar.Faucet()
		baz.Faucet()
		qux.Faucet()
		obl.Faucet()
	}

	// TOKEN REGISTER
	std.TestSetPrevAddr(gsa)
	pl.RegisterGRC20Interface("gno.land/r/demo/foo", FooToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/bar", BarToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/baz", BazToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/qux", QuxToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/obl", OBLToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
	pl.RegisterGRC20Interface("gno.land/r/demo/gns", GNSToken{})

	rr.RegisterGRC20Interface("gno.land/r/demo/foo", FooToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/bar", BarToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/baz", BazToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/qux", QuxToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/obl", OBLToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/wugnot", WugnotToken{})
	rr.RegisterGRC20Interface("gno.land/r/demo/gns", GNSToken{})
}

/* START TEST */
func main() {
	createPool()
	mint()
	ratio()
}

func createPool() {
	// call gns faucet to get creation fee
	std.TestSetPrevAddr(test1)
	for i := 0; i < (5 * 10); i++ {
		gns.Faucet()
		std.TestSkipHeights(1)
	}

	gns.Approve(a2u(consts.POOL_ADDR), consts.POOL_CREATION_FEE*10)
	std.TestSkipHeights(1)

	// 1 HOPS
	pl.CreatePool(barPath, consts.WRAPPED_WUGNOT, fee100, common.TickMathGetSqrtRatioAtTick(10_000).ToString())
	pl.CreatePool(barPath, consts.WRAPPED_WUGNOT, fee500, common.TickMathGetSqrtRatioAtTick(20_000).ToString())
	pl.CreatePool(barPath, consts.WRAPPED_WUGNOT, fee3000, common.TickMathGetSqrtRatioAtTick(60_000).ToString()) // NOT USED BY SMALL LIQ
	// -10_000 0.367897
	// -20_000 0.135348
	// 0.367897 + 0.135348 = 0.503245
	// 0.503245 / 2 = 0.2516225
	// 1 WGNOT = 0.2516225 BAR

	// 2 HOPS
	pl.CreatePool(consts.WRAPPED_WUGNOT, quxPath, fee100, common.TickMathGetSqrtRatioAtTick(0).ToString()) // 1:1
	pl.CreatePool(quxPath, fooPath, fee100, common.TickMathGetSqrtRatioAtTick(50_000).ToString())
	pl.CreatePool(quxPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(60_000).ToString())
	pl.CreatePool(quxPath, fooPath, fee3000, common.TickMathGetSqrtRatioAtTick(100_000).ToString()) // NOT USED BY SMALL LIQ
	// 50_000 148.376062
	// 60_000 403.307791
	// 148.376062 + 403.307791 = 551.683853
	// 551.683853 / 2 = 275.8419265
	// 1 WGNOT = 275.8419265 FOO

	// 3 HOPS
	pl.CreatePool(consts.WRAPPED_WUGNOT, bazPath, fee100, common.TickMathGetSqrtRatioAtTick(6932).ToString()) // 1:2
	pl.CreatePool(bazPath, oblPath, fee100, common.TickMathGetSqrtRatioAtTick(6932).ToString())               // 1:2
	pl.CreatePool(oblPath, consts.GNS_PATH, fee100, common.TickMathGetSqrtRatioAtTick(6932).ToString())       // 1:2
	// 1 WGNOT = 8 GNS
}

func mint() {
	std.TestSetOrigCaller(test1)

	// prepare ugnot
	testBanker := std.GetBanker(std.BankerTypeRealmIssue)
	testBanker.IssueCoin(test1, "ugnot", 100_000_000_000)
	std.TestSetOrigSend(std.Coins{{"ugnot", 100_000_000_000}}, nil)
	testBanker.RemoveCoin(std.GetOrigCaller(), "ugnot", 100_000_000_000)

	// Deposit(wrap)
	std.TestSetPrevAddr(test1)
	wugnot.Deposit()

	bar.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	wugnot.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	qux.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)
	foo.Approve(a2u(consts.POOL_ADDR), consts.UINT64_MAX)

	std.TestSetPrevRealm(consts.STAKER_PATH)
	pn.Mint(barPath, consts.WRAPPED_WUGNOT, fee100, 8000, 12000, "100000000", "100000000", "0", "0", max_timeout, test1.String())
	pn.Mint(barPath, consts.WRAPPED_WUGNOT, fee500, 18000, 22000, "80000000", "80000000", "0", "0", max_timeout, test1.String())
	pn.Mint(barPath, consts.WRAPPED_WUGNOT, fee3000, 58020, 62040, "10000000", "10000000", "0", "0", max_timeout, test1.String())

	pn.Mint(quxPath, fooPath, fee100, 48000, 52000, "100000000", "100000000", "0", "0", max_timeout, test1.String())
	pn.Mint(quxPath, fooPath, fee500, 58000, 62000, "80000000", "80000000", "0", "0", max_timeout, test1.String())
	pn.Mint(quxPath, fooPath, fee3000, 98040, 10020, "100000", "100000", "0", "0", max_timeout, test1.String())

	// pn.Mint(fooPath, consts.GNS_PATH, fee100, 48000, 52000, "100000000", "100000000","0", "0" max_timeout, test1.String())
}

func ratio() {
	ratios := rr.ApiGetRatiosFromBase()

	root, err := json.Unmarshal([]byte(ratios))
	if err != nil {
		panic(err)
	}

	response, err := root.GetKey("response")
	if err != nil {
		panic(err)
	}
	if response.Size() != 7 {
		panic("response size should be 7")
	}

	arr, err := response.GetArray()
	if err != nil {
		panic(err)
	}

	token0, _ := response.GetIndex(0)
	if token0.String() != "{\"token\":\"gno.land/r/demo/wugnot\",\"ratio\":\"79228162514264337593543950336\"}" {
		panic("token0 wrong")
	}

	token1, _ := response.GetIndex(1)
	if token1.String() != "{\"token\":\"gno.land/r/demo/bar\",\"ratio\":\"19935653721785907863909200771\"}" {
		panic("token1 wrong")
	}

	token2, _ := response.GetIndex(2)
	if token2.String() != "{\"token\":\"gno.land/r/demo/qux\",\"ratio\":\"79228162514264337593543950338\"}" {
		panic("token2 wrong")
	}

	token3, _ := response.GetIndex(3)
	if token3.String() != "{\"token\":\"gno.land/r/demo/foo\",\"ratio\":\"21854449020437189859372345675086\"}" {
		panic("token3 wrong")
	}

	token4, _ := response.GetIndex(4)
	if token4.String() != "{\"token\":\"gno.land/r/demo/baz\",\"ratio\":\"158459202898910110285447649633\"}" {
		panic("token4 wrong")
	}

	token5, _ := response.GetIndex(5)
	if token5.String() != "{\"token\":\"gno.land/r/demo/obl\",\"ratio\":\"316924161643118367991168631862\"}" {
		panic("token5 wrong")
	}

	token6, _ := response.GetIndex(6)
	if token6.String() != "{\"token\":\"gno.land/r/demo/gns\",\"ratio\":\"633859835185907382391729498085\"}" {
		panic("token6 wrong")
	}
}

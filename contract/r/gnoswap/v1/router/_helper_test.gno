package router

import (
	"chain"
	"chain/banker"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/obl"
	"gno.land/r/onbloc/qux"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
)

const (
	ugnotDenom string = "ugnot"
	ugnotPath  string = "ugnot"

	gnsPath string = "gno.land/r/gnoswap/gns"
	barPath string = "gno.land/r/onbloc/bar"
	bazPath string = "gno.land/r/onbloc/baz"
	fooPath string = "gno.land/r/onbloc/foo"
	oblPath string = "gno.land/r/onbloc/obl"
	quxPath string = "gno.land/r/onbloc/qux"

	fee100      uint32 = 100
	fee500      uint32 = 500
	fee3000     uint32 = 3000
	max_timeout int64  = 9999999999

	TIER_1 uint64 = 1
	TIER_2 uint64 = 2
	TIER_3 uint64 = 3

	poolCreationFee = 100_000_000
)

const (
	FEE_LOW    uint32 = 500
	FEE_MEDIUM uint32 = 3000
	FEE_HIGH   uint32 = 10000
)

var (
	// define addresses to use in tests
	addr01 = testutils.TestAddress("addr01")
	addr02 = testutils.TestAddress("addr02")
)

var (
	user1Addr       address = testutils.TestAddress("user1")
	user2Addr       address = testutils.TestAddress("user2")
	singlePoolPath          = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000"
	singlePoolPath2         = "gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:3000"
)

var (
	minTick int32 = -887220
	maxTick int32 = 887220
)

var (
	admin, _  = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminAddr = admin

	alice = testutils.TestAddress("alice")
	bob   = testutils.TestAddress("bob")

	adminRealm = testing.NewUserRealm(admin)

	routerPath  = "gno.land/r/gnoswap/v1/router"
	routerRealm = testing.NewUserRealm(routerAddr)

	posPath  = "gno.land/r/gnoswap/v1/position"
	posRealm = testing.NewCodeRealm(posPath)

	wugnotAddr address = "g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"

	// addresses used in tests
	addrUsedInTest = []address{addr01, addr02}
)

func TokenFaucet(t *testing.T, tokenPath string, to address) {
	t.Helper()
	testing.SetOriginCaller(admin)
	defaultAmount := int64(5_000_000_000)

	switch tokenPath {
	case wugnotPath:
		wugnotTransfer(t, to, defaultAmount)
	case gnsPath:
		gnsTransfer(t, to, defaultAmount)
	case barPath:
		barTransfer(t, to, defaultAmount)
	case bazPath:
		bazTransfer(t, to, defaultAmount)
	case fooPath:
		fooTransfer(t, to, defaultAmount)
	case oblPath:
		oblTransfer(t, to, defaultAmount)
	case quxPath:
		quxTransfer(t, to, defaultAmount)
	default:
		panic("token not found")
	}
}

func TokenFaucet2(t *testing.T, tokenPath string, to address) {
	t.Helper()
	testing.SetOriginCaller(admin)
	defaultAmount := int64(10_000_000_000)

	switch tokenPath {
	case wugnotPath:
		wugnotTransfer(t, to, defaultAmount)
	case gnsPath:
		gnsTransfer(t, to, defaultAmount)
	case barPath:
		barTransfer(t, to, defaultAmount)
	case bazPath:
		bazTransfer(t, to, defaultAmount)
	case fooPath:
		fooTransfer(t, to, defaultAmount)
	case oblPath:
		oblTransfer(t, to, defaultAmount)
	case quxPath:
		quxTransfer(t, to, defaultAmount)
	default:
		panic("token not found")
	}
}

func TokenApprove(t *testing.T, tokenPath string, owner, spender address, amount int64) {
	t.Helper()
	switch tokenPath {
	case wugnotPath:
		wugnotApprove(t, owner, spender, amount)
	case gnsPath:
		gnsApprove(t, owner, spender, amount)
	case barPath:
		barApprove(t, owner, spender, amount)
	case bazPath:
		bazApprove(t, owner, spender, amount)
	case fooPath:
		fooApprove(t, owner, spender, amount)
	case oblPath:
		oblApprove(t, owner, spender, amount)
	case quxPath:
		quxApprove(t, owner, spender, amount)
	default:
		panic("token not found")
	}
}

func CreatePool(t *testing.T,
	token0 string,
	token1 string,
	fee uint32,
	sqrtPriceX96 string,
	caller address,
) {
	t.Helper()

	testing.SetRealm(testing.NewUserRealm(caller))
	poolPath := pl.GetPoolPath(token0, token1, fee)
	if !pl.ExistsPoolPath(poolPath) {
		pl.CreatePool(cross, token0, token1, fee, sqrtPriceX96)
		sr.SetPoolTier(cross, poolPath, TIER_1)
	}
}

func wugnotApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	wugnot.Approve(cross, spender, amount)
}

func gnsApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	gns.Approve(cross, spender, amount)
}

func barApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	bar.Approve(cross, spender, amount)
}

func bazApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	baz.Approve(cross, spender, amount)
}

func fooApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	foo.Approve(cross, spender, amount)
}

func oblApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	obl.Approve(cross, spender, amount)
}

func quxApprove(t *testing.T, owner, spender address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(owner))
	qux.Approve(cross, spender, amount)
}

func wugnotTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(admin))
	wugnot.Transfer(cross, to, amount)
}

func gnsTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(admin))
	gns.Transfer(cross, to, amount)
}

func barTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(admin))
	bar.Transfer(cross, to, amount)
}

func bazTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(admin))
	baz.Transfer(cross, to, amount)
}

func fooTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(admin))
	foo.Transfer(cross, to, amount)
}

func oblTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(admin))
	obl.Transfer(cross, to, amount)
}

func quxTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(admin))
	qux.Transfer(cross, to, amount)
}

// ----------------------------------------------------------------------------
// ugnot

func ugnotTransfer(t *testing.T, from, to address, amount int64) {
	t.Helper()

	testing.SetRealm(testing.NewUserRealm(from))
	testing.SetOriginSend(chain.Coins{{ugnotDenom, int64(amount)}})
	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(from, to, chain.Coins{{ugnotDenom, int64(amount)}})
}

func ugnotBalanceOf(t *testing.T, addr address) int64 {
	t.Helper()

	banker_ := banker.NewBanker(banker.BankerTypeRealmIssue)
	coins := banker_.GetCoins(addr)
	if len(coins) == 0 {
		return 0
	}

	return coins.AmountOf(ugnotDenom)
}

func ugnotMint(t *testing.T, addr address, denom string, amount int64) {
	t.Helper()
	banker_ := banker.NewBanker(banker.BankerTypeRealmIssue)
	banker_.IssueCoin(addr, denom, amount)
	testing.IssueCoins(addr, chain.Coins{{denom, amount}})
}

func ugnotBurn(t *testing.T, addr address, denom string, amount int64) {
	t.Helper()
	banker_ := banker.NewBanker(banker.BankerTypeRealmIssue)
	banker_.RemoveCoin(addr, denom, amount)
}

func ugnotFaucet(t *testing.T, to address, amount int64) {
	t.Helper()
	faucetAddress := admin
	testing.SetOriginCaller(faucetAddress)

	if ugnotBalanceOf(t, faucetAddress) < amount {
		newCoins := chain.Coins{{ugnotDenom, int64(amount)}}
		ugnotMint(t, faucetAddress, newCoins[0].Denom, newCoins[0].Amount)
		testing.SetOriginSend(newCoins)
	}
	ugnotTransfer(t, faucetAddress, to, amount)
}

func ugnotDeposit(t *testing.T, addr address, amount uint64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(addr))
	wugnotAddr := wugnotAddr
	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(addr, wugnotAddr, chain.Coins{{ugnotDenom, int64(amount)}})
	wugnot.Deposit(cross)
}

func CreatePoolWithoutFee(t *testing.T) {
	testing.SetRealm(adminRealm)
	// set pool create fee to 0 for testing
	pl.SetPoolCreationFee(cross, 0)
	CreatePool(t, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString(), admin)
	CreatePool(t, bazPath, fooPath, fee3000, common.TickMathGetSqrtRatioAtTick(0).ToString(), admin)
	CreatePool(t, barPath, bazPath, fee3000, common.TickMathGetSqrtRatioAtTick(0).ToString(), admin)
	CreatePool(t, barPath, bazPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString(), admin)
}

func CreateSecondPoolWithoutFee(t *testing.T) {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)

	CreatePool(t,
		bazPath,
		quxPath,
		fee3000,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
		admin,
	)
}

func MakeMintPositionWithoutFee(t *testing.T) (uint64, string, string, string) {
	t.Helper()

	// make actual data to test resetting not only position's state but also pool's state
	testing.SetRealm(adminRealm)

	TokenApprove(t, barPath, admin, poolAddr, maxApprove)
	TokenApprove(t, bazPath, admin, poolAddr, maxApprove)

	// mint position
	return pn.Mint(
		cross,
		barPath,
		bazPath,
		fee3000,
		-887220,
		887220,
		"50000",
		"50000",
		"0",
		"0",
		max_timeout,
		admin,
		admin,
		"",
	)
}

func MakeSecondMintPositionWithoutFee(t *testing.T) (uint64, string, string, string) {
	t.Helper()

	testing.SetRealm(adminRealm)

	TokenApprove(t, bazPath, admin, poolAddr, maxApprove)
	TokenApprove(t, quxPath, admin, poolAddr, maxApprove)

	return pn.Mint(
		cross,
		bazPath,
		quxPath,
		fee3000,
		-887220,
		887220,
		"50000",
		"50000",
		"0",
		"0",
		max_timeout,
		admin,
		admin,
		"",
	)
}

func MakeThirdMintPositionWithoutFee(t *testing.T) (uint64, string, string, string) {
	t.Helper()

	testing.SetRealm(adminRealm)

	TokenApprove(t, barPath, admin, poolAddr, maxApprove)
	TokenApprove(t, fooPath, admin, poolAddr, maxApprove)

	return pn.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-887220,
		887220,
		"50000",
		"50000",
		"0",
		"0",
		max_timeout,
		admin,
		admin,
		"",
	)
}

func MakeForthMintPositionWithoutFee(t *testing.T) (uint64, string, string, string) {
	t.Helper()

	// make actual data to test resetting not only position's state but also pool's state
	testing.SetRealm(adminRealm)

	TokenApprove(t, barPath, admin, poolAddr, maxApprove)
	TokenApprove(t, bazPath, admin, poolAddr, maxApprove)

	// mint position
	return pn.Mint(
		cross,
		barPath,
		bazPath,
		fee500,
		-887220,
		887220,
		"50000",
		"50000",
		"0",
		"0",
		max_timeout,
		admin,
		admin,
		"",
	)
}

func initRouterTest(t *testing.T) {
	t.Helper()

	pl.InitPoolTest(t)
	pn.InitPositionTest(t)
	gnft.InitGNFTTest(t)
}

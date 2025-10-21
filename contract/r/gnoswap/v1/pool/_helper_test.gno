package pool

import (
	"chain"
	"chain/banker"
	"strconv"
	"testing"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/obl"
	"gno.land/r/onbloc/qux"
	"gno.land/r/onbloc/usdc"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"

	"gno.land/p/nt/uassert"

	_ "gno.land/r/gnoswap/rbac" // initialize rbac package
)

const (
	ugnotDenom string = "ugnot"
	ugnotPath  string = "ugnot"
	wugnotPath string = "gno.land/r/gnoland/wugnot"
	gnsPath    string = "gno.land/r/gnoswap/gns"
	barPath    string = "gno.land/r/onbloc/bar"
	bazPath    string = "gno.land/r/onbloc/baz"
	fooPath    string = "gno.land/r/onbloc/foo"
	oblPath    string = "gno.land/r/onbloc/obl"
	quxPath    string = "gno.land/r/onbloc/qux"

	fee100      uint32 = 100
	fee500      uint32 = 500
	fee3000     uint32 = 3000
	maxApprove  int64  = 9223372036854775806
	max_timeout int64  = 9999999999

	maxSqrtPriceLimitX96 string = "1461373636630004318706518188784493106690254656249"
)

var (
	// define addresses to use in tests
	addr01 = testutils.TestAddress("addr01")
	addr02 = testutils.TestAddress("addr02")
)

var (
	fooToken = common.GetToken(fooPath)
	barToken = common.GetToken(barPath)
	bazToken = common.GetToken(bazPath)
)

var (
	adminAddr, _  = access.GetAddress(prabc.ROLE_ADMIN.String())
	devOpsAddr, _ = access.GetAddress(prabc.ROLE_DEVOPS.String())

	govAddr, _      = access.GetAddress(prabc.ROLE_GOVERNANCE.String())
	stakerAddr, _   = access.GetAddress(prabc.ROLE_STAKER.String())
	emissionAddr, _ = access.GetAddress(prabc.ROLE_EMISSION.String())

	wugnotAddr address = "g15vj5q08amlvyd0nx6zjgcvwq2d0gt9fcchrvum"

	alice      = testutils.TestAddress("alice")
	adminRealm = testing.NewUserRealm(adminAddr)

	posPath  = "gno.land/r/gnoswap/v1/position"
	posRealm = testing.NewCodeRealm(posPath)

	routerPath = "gno.land/r/gnoswap/router"
	rouRealm   = testing.NewCodeRealm(routerPath)

	addrUsedInTest = []address{addr01, addr02}
)

const (
	MIN_PRICE string = "4295128740"
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341"
)

func InitialisePoolTest(t *testing.T) {
	t.Helper()

	ugnotFaucet(t, adminAddr, 100_000_000_000_000)
	ugnotDeposit(t, adminAddr, 100_000_000_000_000)

	testing.SetOriginCaller(adminAddr)
	func() {
		testing.SetRealm(adminRealm)
		TokenApprove(t, gnsPath, adminAddr, poolAddr, maxApprove)
		poolPath := GetPoolPath(wugnotPath, gnsPath, fee3000)
		if !ExistsPoolPath(poolPath) {
			CreatePool(cross, wugnotPath, gnsPath, fee3000, "79228162514264337593543950336")
		}
	}()

	// 2. create position
	testing.SetOriginCaller(alice)
	func() {
		testing.SetRealm(testing.NewUserRealm(alice))
		TokenFaucet(t, wugnotPath, alice)
		TokenFaucet(t, gnsPath, alice)
		TokenApprove(t, wugnotPath, alice, poolAddr, 1000)
		TokenApprove(t, gnsPath, alice, poolAddr, 1000)
		MintPosition(t,
			wugnotPath,
			gnsPath,
			fee3000,
			int32(1020),
			int32(5040),
			"1000",
			"1000",
			"0",
			"0",
			max_timeout,
			alice,
			alice,
		)
	}()
}

func TokenFaucet(t *testing.T, tokenPath string, to address) {
	t.Helper()
	testing.SetOriginCaller(adminAddr)
	defaultAmount := int64(5_000_000_000)

	func() {
		testing.SetRealm(adminRealm)
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
	}()
}

func TokenBalance(t *testing.T, tokenPath string, owner address) int64 {
	t.Helper()
	switch tokenPath {
	case wugnotPath:
		return wugnot.BalanceOf(owner)
	case gnsPath:
		return gns.BalanceOf(owner)
	case barPath:
		return bar.BalanceOf(owner)
	case bazPath:
		return baz.BalanceOf(owner)
	case fooPath:
		return foo.BalanceOf(owner)
	case oblPath:
		return obl.BalanceOf(owner)
	case quxPath:
		return qux.BalanceOf(owner)
	default:
		panic("token not found")
	}
}

func TokenAllowance(t *testing.T, tokenPath string, owner, spender address) int64 {
	t.Helper()
	switch tokenPath {
	case wugnotPath:
		return wugnot.Allowance(owner, spender)
	case gnsPath:
		return gns.Allowance(owner, spender)
	case barPath:
		return bar.Allowance(owner, spender)
	case bazPath:
		return baz.Allowance(owner, spender)
	case fooPath:
		return foo.Allowance(owner, spender)
	case oblPath:
		return obl.Allowance(owner, spender)
	case quxPath:
		return qux.Allowance(owner, spender)
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

func MintPosition(t *testing.T,
	token0 string,
	token1 string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	amount0Desired string, // *u256.Uint
	amount1Desired string, // *u256.Uint
	amount0Min string, // *u256.Uint
	amount1Min string, // *u256.Uint
	deadline int64,
	mintTo address,
	caller address,
) (string, string) {
	t.Helper()
	testing.SetRealm(posRealm)

	return Mint(
		cross,
		token0,
		token1,
		fee,
		tickLower,
		tickUpper,
		amount0Desired,
		caller,
	)
}

func MintPositionAll(t *testing.T, caller address) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(caller))
	TokenApprove(t, gnsPath, caller, poolAddr, maxApprove)
	TokenApprove(t, gnsPath, caller, routerAddr, maxApprove)
	TokenApprove(t, wugnotPath, caller, poolAddr, maxApprove)
	TokenApprove(t, wugnotPath, caller, routerAddr, maxApprove)

	params := []struct {
		tickLower int32
		tickUpper int32
		liquidity uint64
		zeroToOne bool
	}{
		{
			tickLower: -300,
			tickUpper: -240,
			liquidity: 10,
			zeroToOne: true,
		},
		{
			tickLower: -240,
			tickUpper: -180,
			liquidity: 10,
			zeroToOne: true,
		},
		{
			tickLower: -180,
			tickUpper: -120,
			liquidity: 10,
			zeroToOne: true,
		},
		{
			tickLower: -120,
			tickUpper: -60,
			liquidity: 10,
			zeroToOne: true,
		},
		{
			tickLower: -60,
			tickUpper: 0,
			liquidity: 10,
			zeroToOne: true,
		},
		{
			tickLower: 0,
			tickUpper: 60,
			liquidity: 10,
			zeroToOne: false,
		},
		{
			tickLower: 60,
			tickUpper: 120,
			liquidity: 10,
			zeroToOne: false,
		},
		{
			tickLower: 120,
			tickUpper: 180,
			liquidity: 10,
			zeroToOne: false,
		},
		{
			tickLower: 180,
			tickUpper: 240,
			liquidity: 10,
			zeroToOne: false,
		},
		{
			tickLower: 240,
			tickUpper: 300,
			liquidity: 10,
			zeroToOne: false,
		},
		{
			tickLower: -360,
			tickUpper: -300,
			liquidity: 10,
			zeroToOne: true,
		},
		{
			tickLower: -420,
			tickUpper: -360,
			liquidity: 10,
			zeroToOne: true,
		},
		{
			tickLower: -480,
			tickUpper: -420,
			liquidity: 10,
			zeroToOne: true,
		},
		{
			tickLower: -540,
			tickUpper: -480,
			liquidity: 10,
			zeroToOne: true,
		},
		{
			tickLower: -600,
			tickUpper: -540,
			liquidity: 10,
			zeroToOne: true,
		},
		{
			tickLower: 300,
			tickUpper: 360,
			liquidity: 10,
			zeroToOne: false,
		},
		{
			tickLower: 360,
			tickUpper: 420,
			liquidity: 10,
			zeroToOne: false,
		},
		{
			tickLower: 420,
			tickUpper: 480,
			liquidity: 10,
			zeroToOne: false,
		},
		{
			tickLower: 480,
			tickUpper: 540,
			liquidity: 10,
			zeroToOne: false,
		},
		{
			tickLower: 540,
			tickUpper: 600,
			liquidity: 10,
			zeroToOne: false,
		},
	}

	for _, p := range params {
		MintPosition(t,
			wugnotPath,
			gnsPath,
			fee3000,
			p.tickLower,
			p.tickUpper,
			"100000000", // liquidityAmount
			"100000000", // unused
			"0",         // unused
			"0",         // unused
			max_timeout, // unused
			caller,      // mintTo (recipient)
			caller)      // positionCaller
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
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	wugnot.Transfer(cross, to, amount)
}

func gnsTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	gns.Transfer(cross, to, amount)
}

func barTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	bar.Transfer(cross, to, amount)
}

func bazTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	baz.Transfer(cross, to, amount)
}

func fooTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	foo.Transfer(cross, to, amount)
}

func oblTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	obl.Transfer(cross, to, amount)
}

func quxTransfer(t *testing.T, to address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	qux.Transfer(cross, to, amount)
}

// ----------------------------------------------------------------------------
// ugnot

func ugnotTransfer(t *testing.T, from, to address, amount int64) {
	t.Helper()

	testing.SetRealm(testing.NewUserRealm(from))
	testing.SetOriginSend(chain.Coins{{ugnotDenom, amount}})
	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(from, to, chain.Coins{{ugnotDenom, amount}})
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
	testing.IssueCoins(addr, chain.Coins{{denom, amount}})
}

func ugnotBurn(t *testing.T, addr address, denom string, amount int64) {
	t.Helper()
	banker_ := banker.NewBanker(banker.BankerTypeRealmIssue)
	banker_.RemoveCoin(addr, denom, amount)
}

func ugnotFaucet(t *testing.T, to address, amount int64) {
	t.Helper()
	faucetAddress := adminAddr
	testing.SetOriginCaller(faucetAddress)

	if ugnotBalanceOf(t, faucetAddress) < amount {
		newCoins := chain.Coins{{ugnotDenom, int64(amount)}}
		ugnotMint(t, faucetAddress, newCoins[0].Denom, newCoins[0].Amount)
		testing.SetOriginSend(newCoins)
	}
	ugnotTransfer(t, faucetAddress, to, amount)
}

func ugnotDeposit(t *testing.T, addr address, amount int64) {
	t.Helper()
	testing.SetRealm(testing.NewUserRealm(addr))
	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(addr, wugnotAddr, chain.Coins{{ugnotDenom, int64(amount)}})
	wugnot.Deposit(cross)
}

// resetObject resets the object state(clear or make it default values)
func resetObject(t *testing.T) {
	pools = avl.NewTree()
	slot0FeeProtocol = 0
	poolCreationFee = 100_000_000
	withdrawalFeeBPS = 100
}

func burnTokens(t *testing.T) {
	t.Helper()

	// burn tokens
	for _, addr := range addrUsedInTest {
		burnFoo(addr)
		burnBar(addr)
		burnBaz(addr)
		burnQux(addr)
		burnObl(addr)
		burnUsdc(addr)
	}
}

func burnFoo(addr address) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	foo.Burn(cross, addr, foo.BalanceOf(addr))
}

func burnBar(addr address) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	bar.Burn(cross, addr, bar.BalanceOf(addr))
}

func burnBaz(addr address) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	baz.Burn(cross, addr, baz.BalanceOf(addr))
}

func burnQux(addr address) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	qux.Burn(cross, addr, qux.BalanceOf(addr))
}

func burnObl(addr address) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	obl.Burn(cross, addr, obl.BalanceOf(addr))
}

func burnUsdc(addr address) {
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	usdc.Burn(cross, addr, usdc.BalanceOf(addr))
}

func TestBeforeResetObject(t *testing.T) {
	// make some data
	pools = avl.NewTree()
	pools.Set("gno.land/r/gnoswap/gns:gno.land/r/onbloc/usdc", &Pool{
		token0Path: "gno.land/r/gnoswap/gns",
		token1Path: "gno.land/r/onbloc/usdc",
	})

	slot0FeeProtocol = 1
	poolCreationFee = 100_000_000
	withdrawalFeeBPS = 100

	// transfer some tokens
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	func() {
		testing.SetRealm(testing.NewUserRealm(adminAddr))
		foo.Transfer(cross, addr01, 100_000_000)
		bar.Transfer(cross, addr01, 100_000_000)
	}()

	uassert.Equal(t, foo.BalanceOf(addr01), int64(100_000_000))
	uassert.Equal(t, bar.BalanceOf(addr01), int64(100_000_000))
}

func TestResetObject(t *testing.T) {
	resetObject(t)
	uassert.Equal(t, pools.Size(), 0)
	uassert.Equal(t, slot0FeeProtocol, uint8(0))
	uassert.Equal(t, poolCreationFee, int64(100_000_000))
	uassert.Equal(t, withdrawalFeeBPS, uint64(100))
}

func TestBurnTokens(t *testing.T) {
	burnTokens(t)

	uassert.Equal(t, foo.BalanceOf(addr01), int64(0)) // 100_000_000 -> 0
	uassert.Equal(t, bar.BalanceOf(addr01), int64(0)) // 100_000_000 -> 0
}

func mockSwapCallback(token0Path string, token1Path string, amount0Delta string, amount1Delta string) error {
	func(cur realm) {
		testing.SetRealm(adminRealm)

		amount0Int64, _ := strconv.ParseInt(amount0Delta, 10, 64)
		amount1Int64, _ := strconv.ParseInt(amount1Delta, 10, 64)

		if amount0Int64 > 0 {
			if token0Path == wugnotPath {
				testing.SetOriginSend(chain.Coins{{ugnotDenom, amount0Int64}})
				wugnot.Deposit(cross)
			}

			common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Int64)
		}
		if amount1Int64 > 0 {
			if token1Path == wugnotPath {
				testing.SetOriginSend(chain.Coins{{ugnotDenom, amount1Int64}})
				wugnot.Deposit(cross)
			}

			common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Int64)
		}
	}(cross)

	return nil
}

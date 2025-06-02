package staker

import (
	"math"
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	en "gno.land/r/gnoswap/v1/emission"
	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"

	"gno.land/r/demo/wugnot"
	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/obl"
	"gno.land/r/onbloc/qux"
)

const (
	ugnotDenom string = "ugnot"
	ugnotPath  string = "ugnot"
	wugnotPath string = "gno.land/r/demo/wugnot"
	gnsPath    string = "gno.land/r/gnoswap/v1/gns"
	barPath    string = "gno.land/r/onbloc/bar"
	bazPath    string = "gno.land/r/onbloc/baz"
	fooPath    string = "gno.land/r/onbloc/foo"
	oblPath    string = "gno.land/r/onbloc/obl"
	quxPath    string = "gno.land/r/onbloc/qux"

	fee100      uint32 = 100
	fee500      uint32 = 500
	fee3000     uint32 = 3000
	maxApprove  uint64 = 18446744073709551615
	max_timeout int64  = 9999999999
)

var (
	// define addresses to use in tests
	addr01 = testutils.TestAddress("addr01")
	addr02 = testutils.TestAddress("addr02")
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	admin        = adminAddr
	adminRealm   = std.NewUserRealm(admin)

	alice = testutils.TestAddress("alice")

	govGovernanceAddr, _ = access.GetAddress(access.ROLE_GOVERNANCE)
	poolAddr, _          = access.GetAddress(access.ROLE_POOL)
	routerAddr, _        = access.GetAddress(access.ROLE_ROUTER)
	emissionAddr, _      = access.GetAddress(access.ROLE_EMISSION)

	posRealm = std.NewCodeRealm(consts.POSITION_PATH)
	rouRealm = std.NewCodeRealm(consts.ROUTER_PATH)

	// addresses used in tests
	addrUsedInTest = []std.Address{addr01, addr02}

	dummyAddr  = testutils.TestAddress("dummy")
	dummyRealm = std.NewUserRealm(dummyAddr)
)

func CreatePool(t *testing.T,
	token0 string,
	token1 string,
	fee uint32,
	sqrtPriceX96 string,
	caller std.Address,
) {
	t.Helper()

	testing.SetRealm(std.NewUserRealm(caller))
	poolPath := pl.GetPoolPath(token0, token1, fee)
	if !pl.DoesPoolPathExist(poolPath) {
		pl.CreatePool(token0, token1, fee, sqrtPriceX96)
	}
}

func LPTokenStake(t *testing.T, owner std.Address, positionId uint64) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(owner))
}

func LPTokenUnStake(t *testing.T, owner std.Address, positionId uint64, unwrap bool) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(owner))
}

func InitialisePoolTest(t *testing.T) {
	t.Helper()

	ugnotFaucet(t, admin, 100_000_000_000_000)
	ugnotDeposit(t, admin, 100_000_000_000_000)
	TokenFaucet(t, gnsPath, admin)

	testing.SetOriginCaller(admin)
	TokenApprove(t, gnsPath, admin, poolAddr, maxApprove)
	poolPath := pl.GetPoolPath(wugnotPath, gnsPath, fee3000)
	if !pl.DoesPoolPathExist(poolPath) {
		pl.CreatePool(wugnotPath, gnsPath, fee3000, "79228162514264337593543950336")
	}

	testing.SetOriginCaller(alice)
	TokenFaucet(t, wugnotPath, alice)
	TokenFaucet(t, gnsPath, alice)
	TokenApprove(t, wugnotPath, alice, poolAddr, uint64(1000))
	TokenApprove(t, gnsPath, alice, poolAddr, uint64(1000))
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
}

func CreateSecondPoolWithoutFee(t *testing.T) {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFeeByAdmin(0)

	CreatePool(t,
		barPath,
		bazPath,
		fee3000,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
		admin,
	)
}

func MakeMintPositionWithoutFee(t *testing.T) (uint64, string, string, string) {
	t.Helper()

	// make actual data to test resetting not only position's state but also pool's state
	testing.SetRealm(adminRealm)

	TokenApprove(t, barPath, admin, poolAddr, consts.UINT64_MAX)
	TokenApprove(t, bazPath, admin, poolAddr, consts.UINT64_MAX)

	// mint position
	return pn.Mint(
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

func TokenFaucet(t *testing.T, tokenPath string, to std.Address) {
	t.Helper()
	testing.SetOriginCaller(admin)
	defaultAmount := uint64(5_000_000_000)

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

func TokenBalance(t *testing.T, tokenPath string, owner std.Address) uint64 {
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

func TokenAllowance(t *testing.T, tokenPath string, owner, spender std.Address) uint64 {
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

func TokenApprove(t *testing.T, tokenPath string, owner, spender std.Address, amount uint64) {
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
	mintTo std.Address,
	caller std.Address,
) (uint64, string, string, string) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(caller))

	return pn.Mint(
		token0,
		token1,
		fee,
		tickLower,
		tickUpper,
		amount0Desired,
		amount1Desired,
		amount0Min,
		amount1Min,
		deadline,
		mintTo,
		caller,
		"",
	)
}

func wugnotApprove(t *testing.T, owner, spender std.Address, amount uint64) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(owner))
	wugnot.Approve(spender, amount)
}

func gnsApprove(t *testing.T, owner, spender std.Address, amount uint64) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(owner))
	gns.Approve(spender, amount)
}

func barApprove(t *testing.T, owner, spender std.Address, amount uint64) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(owner))
	bar.Approve(spender, amount)
}

func bazApprove(t *testing.T, owner, spender std.Address, amount uint64) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(owner))
	baz.Approve(spender, amount)
}

func fooApprove(t *testing.T, owner, spender std.Address, amount uint64) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(owner))
	foo.Approve(spender, amount)
}

func oblApprove(t *testing.T, owner, spender std.Address, amount uint64) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(owner))
	obl.Approve(spender, amount)
}

func quxApprove(t *testing.T, owner, spender std.Address, amount uint64) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(owner))
	qux.Approve(spender, amount)
}

func wugnotTransfer(t *testing.T, to std.Address, amount uint64) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(admin))
	wugnot.Transfer(to, amount)
}

func gnsTransfer(t *testing.T, to std.Address, amount uint64) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(admin))
	gns.Transfer(to, amount)
}

func barTransfer(t *testing.T, to std.Address, amount uint64) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(admin))
	bar.Transfer(to, amount)
}

func bazTransfer(t *testing.T, to std.Address, amount uint64) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(admin))
	baz.Transfer(to, amount)
}

func fooTransfer(t *testing.T, to std.Address, amount uint64) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(admin))
	foo.Transfer(to, amount)
}

func oblTransfer(t *testing.T, to std.Address, amount uint64) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(admin))
	obl.Transfer(to, amount)
}

func quxTransfer(t *testing.T, to std.Address, amount uint64) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(admin))
	qux.Transfer(to, amount)
}

// ----------------------------------------------------------------------------
// ugnot

func ugnotTransfer(t *testing.T, from, to std.Address, amount uint64) {
	t.Helper()

	testing.SetRealm(std.NewUserRealm(from))
	testing.SetOriginSend(std.Coins{{ugnotDenom, int64(amount)}})
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(from, to, std.Coins{{ugnotDenom, int64(amount)}})
}

func ugnotBalanceOf(t *testing.T, addr std.Address) uint64 {
	t.Helper()

	banker := std.NewBanker(std.BankerTypeRealmIssue)
	coins := banker.GetCoins(addr)
	if len(coins) == 0 {
		return 0
	}

	return uint64(coins.AmountOf(ugnotDenom))
}

func ugnotMint(t *testing.T, addr std.Address, denom string, amount int64) {
	t.Helper()
	testing.IssueCoins(addr, std.Coins{{denom, int64(amount)}})
}

func ugnotBurn(t *testing.T, addr std.Address, denom string, amount int64) {
	t.Helper()
	banker := std.NewBanker(std.BankerTypeRealmIssue)
	banker.RemoveCoin(addr, denom, amount)
}

func ugnotFaucet(t *testing.T, to std.Address, amount uint64) {
	t.Helper()
	faucetAddress := admin
	testing.SetOriginCaller(faucetAddress)

	if ugnotBalanceOf(t, faucetAddress) < amount {
		newCoins := std.Coins{{ugnotDenom, int64(amount)}}
		ugnotMint(t, faucetAddress, newCoins[0].Denom, newCoins[0].Amount)
		testing.SetOriginSend(newCoins)
	}
	ugnotTransfer(t, faucetAddress, to, amount)
}

func ugnotDeposit(t *testing.T, addr std.Address, amount uint64) {
	t.Helper()
	testing.SetRealm(std.NewUserRealm(addr))
	wugnotAddr := consts.WUGNOT_ADDR
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(addr, wugnotAddr, std.Coins{{ugnotDenom, int64(amount)}})
	wugnot.Deposit()
}

// burnAllNFT burns all NFTs
func burnAllNFT(t *testing.T) {
	t.Helper()

	testing.SetRealm(std.NewCodeRealm(consts.POSITION_PATH))
	for i := uint64(1); i <= gnft.TotalSupply(); i++ {
		gnft.Burn(positionIdFrom(i))
	}
}

func deletePoolTier(t *testing.T, poolPath string) {
	t.Helper()
	if poolTier != nil {
		poolTier.changeTier(std.ChainHeight(), pools, poolPath, 0)
	} else {
		panic("poolTier is nil")
	}
}

func addPoolTier(t *testing.T, poolPath string, tier uint64) {
	t.Helper()
	if poolTier != nil {
		if pools != nil {
			pools.GetOrCreate(poolPath)
		} else {
			panic(addDetailToError(
				errPoolNotFound, ufmt.Sprintf("unknown error - pools is nil")))
		}
		poolTier.changeTier(std.ChainHeight(), pools, poolPath, tier)
	} else {
		poolTier = NewPoolTier(pools, std.ChainHeight(), poolPath, en.GetEmission, en.GetHalvingBlocksInRange)
		pools.GetOrCreate(poolPath) // must update pools tree
		poolTier.changeTier(std.ChainHeight(), pools, poolPath, tier)
	}
}

func changeWarmup(t *testing.T, index int, blockDuration int64) {
	modifyWarmup(index, blockDuration)
}

func getNumPoolTiers(t *testing.T) (uint64, uint64, uint64) {
	counts := poolTier.CurrentAllTierCounts()
	tier1Num := counts[1]
	tier2Num := counts[2]
	tier3Num := counts[3]

	return uint64(tier1Num), uint64(tier2Num), uint64(tier3Num)
}

type gnsBalanceTracker struct {
	height               int64
	stakerBalance        uint64
	devOpsBalance        uint64
	communityPoolBalance uint64
	govStakerBalance     uint64
	protocolFeeBalance   uint64
	callerBalance        uint64
}

func gnsBalanceCheck(t *testing.T, beforeBalance gnsBalanceTracker, printChange bool) gnsBalanceTracker {
	t.Helper()

	caller := std.PreviousRealm().Address()
	height := std.ChainHeight()
	stakerBalance := gns.BalanceOf(stakerAddr)
	devOpsBalance := gns.BalanceOf(devOpsAddr)
	communityPoolBalance := gns.BalanceOf(communityPoolAddr)
	govStakerBalance := gns.BalanceOf(consts.GOV_STAKER_ADDR)
	protocolFeeBalance := gns.BalanceOf(protocolFeeAddr)
	callerBalance := gns.BalanceOf(caller)

	return gnsBalanceTracker{
		height:               height,
		stakerBalance:        stakerBalance,
		devOpsBalance:        devOpsBalance,
		communityPoolBalance: communityPoolBalance,
		govStakerBalance:     govStakerBalance,
		protocolFeeBalance:   protocolFeeBalance,
		callerBalance:        callerBalance,
	}
}

// returns true if actual is within 0.0001% of expected
func isInErrorRange(expected uint64, actual uint64) bool {
	maxSafeValue := uint64(math.MaxUint64 / 100001)
	var lowerBound, upperBound uint64
	if expected > maxSafeValue {
		lowerBound = expected / 1000000 * 999999
		upperBound = expected / 1000000 * 1000001
	} else {
		lowerBound = expected * 999999 / 1000000
		upperBound = expected * 1000001 / 1000000
	}
	return actual >= lowerBound && actual <= upperBound
}

func getRewardRatio(t *testing.T, height int64) uint64 {
	t.Helper()
	warmups := instantiateWarmup(height)

	for _, warmup := range warmups {
		if height < warmup.NextWarmupHeight {
			return warmup.WarmupRatio
		}
	}

	// passed all warmup-periods
	return 100
}

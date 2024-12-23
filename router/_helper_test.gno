package router

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	pusers "gno.land/p/demo/users"
	"gno.land/r/demo/users"
	"gno.land/r/demo/wugnot"
	"gno.land/r/gnoswap/v1/consts"
	"gno.land/r/gnoswap/v1/gns"
	pl "gno.land/r/gnoswap/v1/pool"
	sr "gno.land/r/gnoswap/v1/staker"
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

	TIER_1 uint64 = 1
	TIER_2 uint64 = 2
	TIER_3 uint64 = 3
)

const (
	FEE_LOW    uint32 = 500
	FEE_MEDIUM uint32 = 3000
	FEE_HIGH   uint32 = 10000
)

const (
	// define addresses to use in tests
	addr01 = testutils.TestAddress("addr01")
	addr02 = testutils.TestAddress("addr02")
)

var (
	user1Addr      std.Address = "g1ecely4gjy0yl6s9kt409ll330q9hk2lj9ls3ec"
	singlePoolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000"
	singlePoolPath2 = "gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:3000"
)

var (
	minTick int32 = -887220
	maxTick int32 = 887220
)

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

func init() {
	std.TestSetRealm(std.NewUserRealm(consts.TOKEN_REGISTER))
}

var (
	admin       = pusers.AddressOrName(consts.ADMIN)
	adminAddr   = users.Resolve(admin)
	alice       = pusers.AddressOrName(testutils.TestAddress("alice"))
	bob         = pusers.AddressOrName(testutils.TestAddress("bob"))
	pool        = pusers.AddressOrName(consts.POOL_ADDR)
	protocolFee = pusers.AddressOrName(consts.PROTOCOL_FEE_ADDR)
	adminRealm  = std.NewUserRealm(users.Resolve(admin))
	posRealm    = std.NewCodeRealm(consts.POSITION_PATH)

	// addresses used in tests
	addrUsedInTest = []std.Address{addr01, addr02}
)

func InitialisePoolTest(t *testing.T) {
	t.Helper()

	ugnotFaucet(t, users.Resolve(admin), 100_000_000_000_000)
	ugnotDeposit(t, users.Resolve(admin), 100_000_000_000_000)

	std.TestSetOrigCaller(users.Resolve(admin))
	TokenApprove(t, gnsPath, admin, pool, maxApprove)
	CreatePool(t, wugnotPath, gnsPath, fee3000, "79228162514264337593543950336", users.Resolve(admin))

	//2. create position
	std.TestSetOrigCaller(users.Resolve(alice))
	TokenFaucet(t, wugnotPath, alice)
	TokenFaucet(t, gnsPath, alice)
	TokenApprove(t, wugnotPath, alice, pool, uint64(1000))
	TokenApprove(t, gnsPath, alice, pool, uint64(1000))
}

func TokenFaucet(t *testing.T, tokenPath string, to pusers.AddressOrName) {
	t.Helper()
	std.TestSetOrigCaller(users.Resolve(admin))
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

func TokenBalance(t *testing.T, tokenPath string, owner pusers.AddressOrName) uint64 {
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

func TokenAllowance(t *testing.T, tokenPath string, owner, spender pusers.AddressOrName) uint64 {
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

func TokenApprove(t *testing.T, tokenPath string, owner, spender pusers.AddressOrName, amount uint64) {
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
	caller std.Address) {
	t.Helper()

	std.TestSetRealm(std.NewUserRealm(caller))
	poolPath := pl.GetPoolPath(token0, token1, fee)
	if !pl.DoesPoolPathExist(poolPath) {
		pl.CreatePool(token0, token1, fee, sqrtPriceX96)
		sr.SetPoolTierByAdmin(poolPath, TIER_1)
	}
}

func LPTokenStake(t *testing.T, owner pusers.AddressOrName, tokenId uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(owner)))
	sr.StakeToken(tokenId)
}

func LPTokenUnStake(t *testing.T, owner pusers.AddressOrName, tokenId uint64, unwrap bool) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(owner)))
	sr.UnstakeToken(tokenId, unwrap)
}

func wugnotApprove(t *testing.T, owner, spender pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(owner)))
	wugnot.Approve(spender, amount)
}

func gnsApprove(t *testing.T, owner, spender pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(owner)))
	gns.Approve(spender, amount)
}

func barApprove(t *testing.T, owner, spender pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(owner)))
	bar.Approve(spender, amount)
}

func bazApprove(t *testing.T, owner, spender pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(owner)))
	baz.Approve(spender, amount)
}

func fooApprove(t *testing.T, owner, spender pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(owner)))
	foo.Approve(spender, amount)
}

func oblApprove(t *testing.T, owner, spender pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(owner)))
	obl.Approve(spender, amount)
}

func quxApprove(t *testing.T, owner, spender pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(owner)))
	qux.Approve(spender, amount)
}

func wugnotTransfer(t *testing.T, to pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(admin)))
	wugnot.Transfer(to, amount)
}

func gnsTransfer(t *testing.T, to pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(admin)))
	gns.Transfer(to, amount)
}

func barTransfer(t *testing.T, to pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(admin)))
	bar.Transfer(to, amount)
}

func bazTransfer(t *testing.T, to pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(admin)))
	baz.Transfer(to, amount)
}

func fooTransfer(t *testing.T, to pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(admin)))
	foo.Transfer(to, amount)
}

func oblTransfer(t *testing.T, to pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(admin)))
	obl.Transfer(to, amount)
}

func quxTransfer(t *testing.T, to pusers.AddressOrName, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(users.Resolve(admin)))
	qux.Transfer(to, amount)
}

// ----------------------------------------------------------------------------
// ugnot

func ugnotTransfer(t *testing.T, from, to std.Address, amount uint64) {
	t.Helper()

	std.TestSetRealm(std.NewUserRealm(from))
	std.TestSetOrigSend(std.Coins{{ugnotDenom, int64(amount)}}, nil)
	banker := std.GetBanker(std.BankerTypeRealmSend)
	banker.SendCoins(from, to, std.Coins{{ugnotDenom, int64(amount)}})
}

func ugnotBalanceOf(t *testing.T, addr std.Address) uint64 {
	t.Helper()

	banker := std.GetBanker(std.BankerTypeRealmIssue)
	coins := banker.GetCoins(addr)
	if len(coins) == 0 {
		return 0
	}

	return uint64(coins.AmountOf(ugnotDenom))
}

func ugnotMint(t *testing.T, addr std.Address, denom string, amount int64) {
	t.Helper()
	banker := std.GetBanker(std.BankerTypeRealmIssue)
	banker.IssueCoin(addr, denom, amount)
	std.TestIssueCoins(addr, std.Coins{{denom, int64(amount)}})
}

func ugnotBurn(t *testing.T, addr std.Address, denom string, amount int64) {
	t.Helper()
	banker := std.GetBanker(std.BankerTypeRealmIssue)
	banker.RemoveCoin(addr, denom, amount)
}

func ugnotFaucet(t *testing.T, to std.Address, amount uint64) {
	t.Helper()
	faucetAddress := users.Resolve(admin)
	std.TestSetOrigCaller(faucetAddress)

	if ugnotBalanceOf(t, faucetAddress) < amount {
		newCoins := std.Coins{{ugnotDenom, int64(amount)}}
		ugnotMint(t, faucetAddress, newCoins[0].Denom, newCoins[0].Amount)
		std.TestSetOrigSend(newCoins, nil)
	}
	ugnotTransfer(t, faucetAddress, to, amount)
}

func ugnotDeposit(t *testing.T, addr std.Address, amount uint64) {
	t.Helper()
	std.TestSetRealm(std.NewUserRealm(addr))
	wugnotAddr := consts.WUGNOT_ADDR
	banker := std.GetBanker(std.BankerTypeRealmSend)
	banker.SendCoins(addr, wugnotAddr, std.Coins{{ugnotDenom, int64(amount)}})
	wugnot.Deposit()
}

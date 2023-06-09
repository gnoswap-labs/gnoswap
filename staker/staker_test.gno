package staker

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	"gno.land/r/bar"
	"gno.land/r/foo"

	rt "gno.land/r/reward" // reward Token

	pool "gno.land/r/pool"
	position "gno.land/r/position"

	nft "gno.land/r/foo721" // GNOSWAP POSITION NFT
)

var (
	_maxIncentiveStartLeadTime bigint = 1000000
	_maxIncentiveDuration      bigint = 1000000

	_startTime bigint = GetTimestamp()
	_endTime   bigint = _startTime + 100

	ci = testutils.TestAddress("ci")   // Create Incentive Caller
	rf = testutils.TestAddress("rf")   // Refundee
	rc = testutils.TestAddress("rc")   // Recipient
	lp = testutils.TestAddress("lp01") // Liquidity Provider
	oa = testutils.TestAddress("oa")   // Other Address
)

func init() {
	std.TestSetOrigCaller(ci)
	rt.Faucet()
	rt.Faucet()
	rt.Faucet()
	rt.Faucet()
	rt.Faucet()
	rt.Faucet()
	rt.Faucet()
	rt.Faucet()
	rt.Faucet()
	rt.Faucet()
	rt.Faucet() // x11

	std.TestSetOrigCaller(lp)
	foo.Faucet()
	foo.Faucet()
	foo.Faucet()
	foo.Faucet()
	foo.Faucet() // foo x5
	bar.Faucet()
	bar.Faucet()
	bar.Faucet()
	bar.Faucet()
	bar.Faucet() // bar x5
}

func TestDebug(t *testing.T) {
	println(ci, "ci")
	println(rf, "rf")
	println(rc, "rc")
	println(lp, "lp01")
	println(GetOrigPkgAddr(), "staker contract")
}

func TestPoolInit(t *testing.T) {
	std.TestSetOrigCaller(lp)
	var (
		_fee         bigint = 3000
		_tickSpacing bigint = 10
		_sqrtPrice   bigint = 130621891405341611593710811006
	)
	pool.Init(_fee, _tickSpacing, _sqrtPrice)

	foo.Approve(a2u(GetOrigPkgAddr()), 50000000) // approve foo to staker contract
	bar.Approve(a2u(GetOrigPkgAddr()), 50000000) // approve bar to staker contract

	foo.Approve(a2u(lp), 50000000) // approve foo to self
	bar.Approve(a2u(lp), 50000000) // approve bar to self
}

func TestPositionMint(t *testing.T) {
	std.TestSetOrigCaller(lp)
	_posTokenId, _posLiquidity, _posAmount0, _posAmount1 := position.Mint(
		std.Address("token0"),
		std.Address("token1"),
		bigint(3000),
		bigint(9000),
		bigint(11000),
		bigint(1000),
		bigint(1000),
		bigint(1),
		bigint(1),
		bigint(1234567890),
	)

	shouldEQ(t, _posTokenId, "1")
}

func TestIncentiveInit(t *testing.T) {
	std.TestSetOrigCaller(ci)
	Init(_maxIncentiveStartLeadTime, _maxIncentiveDuration)

	shouldEQ(t, initialized, true)
}

func TestCreateIncentive(t *testing.T) {
	std.TestSetOrigCaller(ci)
	CreateIncentive(
		_startTime, // starTime
		_endTime,   // endTime
		rf,         // refundee
		50000000,   // reward
	)
}

func TestStakeToken(t *testing.T) {
	std.TestSetOrigCaller(lp)
	StakeToken(
		_startTime, // startTime => field of IncentiveKey
		_endTime,   // endTime => field of IncentiveKey
		rf,         // refundee => field of IncentiveKey
		"1",        // tokenId
		100,        // lockDuration
	)
}

func TestGetRewardInfo(t *testing.T) {
	// XXX currently, amount of reward is exact same as amount of liquidity
	std.TestSetOrigCaller(lp)
	_reward, _secondsInsideX128 := GetRewardInfo(_startTime, _endTime, rf, "1")
}

func TestClaimReward(t *testing.T) {
	std.TestSetOrigCaller(lp)

	_oldBal := rt.BalanceOf(a2u(lp))
	ClaimReward(_startTime, _endTime, rf, "1")
	_newBal := rt.BalanceOf(a2u(lp))

	shouldGT(t, _oldBal, _newBal)
}

func TestUnstakeAndWithdraw(t *testing.T) {
	// NFT was staked with lockDuration 100
	// so, it can be withdrawl after 100 seconds since unstake requeset
	std.TestSetOrigCaller(lp)

	UnstakeToken(_startTime, _endTime, rf, "1")
	shouldEQ(t, nft.OwnerOf("1"), GetOrigPkgAddr())

	// WithdrawToken("1", GetOrigCaller())

	std.TestSkipTimestamps(99)
	// WithdrawToken("1", GetOrigCaller())

	std.TestSkipTimestamps(1)
	// WithdrawToken("1", GetOrigCaller())

	std.TestSkipTimestamps(1)
	WithdrawToken("1", GetOrigCaller())
	shouldEQ(t, nft.OwnerOf("1"), GetOrigCaller())
}

// helper
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldNEQ(t *testing.T, got, expected interface{}) {
	if got == expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldGT(t *testing.T, l, r interface{}) {
	if !(l < r) {
		t.Errorf("expected %v < %v", l, r)
	}
}

func shouldLT(t *testing.T, l, r interface{}) {
	if !(l > r) {
		t.Errorf("expected %v > %v", l, r)
	}
}

func shouldPanic(t *testing.T, f func()) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("expected panic")
		}
	}()
	f()
}

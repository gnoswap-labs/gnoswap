package staker

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	p "gno.land/r/pool"
	s "gno.land/r/position"

	nft "gno.land/r/gnft"  // GNFT, Gnoswap NFT
	gnos "gno.land/r/gnos" // GNOS, Gnoswap Share
)

var (
	tMaxIncentiveStartLeadTime bigint = 1000000
	tMaxIncentiveDuration      bigint = 1000000

	tStartTime bigint = GetTimestamp()
	tEndTime   bigint = tStartTime + 301 // staker.gno #140 ( lockDuration is limited to 100, 200, 300 seconds)

	own      = testutils.TestAddress("own")  // Owner
	ci01     = testutils.TestAddress("ci01") // Create Incentive Caller
	rf01     = testutils.TestAddress("rf01") // Refundee
	lp01     = testutils.TestAddress("lp01") // Liquidity Provider
	poolAddr = p.GetOrigPkgAddr()            // Pool Contract
)

func init() {
	// debug - print addr
	println(ci01, "// ci01")
	println(rf01, "// rf01")
	println(lp01, "// lp01")
	println(p.GetOrigPkgAddr(), "// pool")
	println(s.GetOrigPkgAddr(), "// position")
	println(GetOrigPkgAddr(), "// staker")
}

// Init & CreatePool using Pool Contract
func TestPoolInitCreatePool(t *testing.T) {
	std.TestSetOrigCaller(own)
	p.Init()
	p.CreatePool("foo", "bar", 500, 130621891405341611593710811006)

	// fee
	// 500		= 0.05% // USv3 default
	// 3000		= 0.3% // USv3 default
	// 10000	= 1% // USv3 default

	// sqrtPrice
	// 130621891405341611593710811006 // tick = 10000
	shouldPanic(t, func() { p.CreatePool("foo", "bar", 500, 130621891405341611593710811006) })
}

func TestPositionMint(t *testing.T) {
	std.TestSetOrigCaller(lp01)
	tPosTokenId, tPosLiquidity, tPosAmount0, tPosAmount1 := s.Mint(
		std.Address("foo"),
		std.Address("bar"),
		bigint(500),
		bigint(9000),
		bigint(11000),
		bigint(1000),
		bigint(1000),
		bigint(1),
		bigint(1),
		bigint(1234567890),
	)

	shouldEQ(t, tPosTokenId, "1")
	shouldEQ(t, nft.OwnerOf("1"), GetOrigCaller()) // lp01

	// approve nft to staker
	std.TestSetPrevAddr(lp01)
	nft.Approve(a2u(GetOrigPkgAddr()), "1")
}

func TestCreateIncentive(t *testing.T) {
	std.TestSetOrigCaller(ci01)
	CreateIncentive(
		tStartTime, // starTime
		tEndTime,   // endTime
		rf01,       // refundee
	)

	// nft owner doesn't change yet
	shouldEQ(t, nft.OwnerOf("1"), lp01) // lp0
}

func TestStakeToken(t *testing.T) {
	std.TestSetOrigCaller(lp01)
	StakeToken(
		tStartTime,
		tEndTime,
		rf01,
		"1",
		100,
	)

	// nft transfered from lp01 to staker
	shouldEQ(t, nft.OwnerOf("1"), GetOrigPkgAddr())
}

func TestGetRewardInfo(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	// XXX currently, amount of reward is exact same as amount of liquidity
	tReward, tSecondsInsideX128 := GetRewardInfo(
		tStartTime,
		tEndTime,
		rf01,
		"1",
	)
}

func TestClaimReward(t *testing.T) {
	std.TestSetOrigCaller(lp01)

	tOldRewardBal := gnos.BalanceOf(a2u(lp01))
	ClaimReward(tStartTime, tEndTime, rf01, "1")
	tNewRewardBal := gnos.BalanceOf(a2u(lp01))

	shouldGT(t, tOldRewardBal, tNewRewardBal)
}

func TestUnstakeAndWithdraw(t *testing.T) {
	// NFT was staked with lockDuration 100seconds from L#91-96
	// so, it can be withdrawl after 100 seconds since unstake requeset
	std.TestSetOrigCaller(lp01)

	UnstakeToken(tStartTime, tEndTime, rf01, "1")
	shouldEQ(t, nft.OwnerOf("1"), GetOrigPkgAddr()) // staker owns nft tid 1

	shouldPanic(t, func() { WithdrawToken("1", GetOrigCaller()) })

	std.TestSkipHeights(15)
	shouldPanic(t, func() { WithdrawToken("1", GetOrigCaller()) })

	std.TestSkipHeights(5)
	shouldPanic(t, func() { WithdrawToken("1", GetOrigCaller()) })

	std.TestSkipHeights(1)
	WithdrawToken("1", GetOrigCaller())
	shouldEQ(t, nft.OwnerOf("1"), lp01)
}

/* HELPERS */
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

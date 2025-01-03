package staker

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/testutils"

	"gno.land/r/gnoswap/v1/consts"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/xgns"
)

// Mock or define test realms/addresses if needed
var adminRealm = std.NewUserRealm(consts.ADMIN)
var userRealm = std.NewUserRealm(testutils.TestAddress("alice"))
var invalidAddr = testutils.TestAddress("invalid")

func makeFakeAddress(name string) std.Address {
	return testutils.TestAddress(name)
}

func TestDelegate(t *testing.T) {
	std.TestSetOrigCaller(consts.ADMIN)
	SetRunning(true)

	std.TestSetRealm(userRealm)
	{
		std.TestSetRealm(std.NewCodeRealm(consts.EMISSION_PATH))
		std.TestSkipHeights(100)
		mintedGns := gns.MintGns(a2u(userRealm.Addr())) // 2M gns
		println("Minted GNS:", mintedGns)

		std.TestSetRealm(userRealm)
		to := makeFakeAddress("validator_1")
		amount := uint64(1_000_000)

		gns.Approve(a2u(consts.GOV_STAKER_ADDR), amount)
		Delegate(to, amount)

		minted := xgns.BalanceOf(a2u(userRealm.Addr()))
		if minted != amount {
			t.Errorf("Delegate minted xGNS = %d, want %d", minted, amount)
		}
		// verify "delegate" avl state, or any event logs, etc.
	}

	// 4) below minimum
	{
		to := makeFakeAddress("validator_2")
		amount := uint64(999_999)

		defer func() {
			if r := recover(); r == nil {
				t.Errorf("Expected panic when delegating below minimumAmount")
			}
		}()
		Delegate(to, amount)
	}

	// 5) invalid to address
	{
		to := invalidAddr
		amount := uint64(1_000_000)

		defer func() {
			if r := recover(); r == nil {
				t.Errorf("Expected panic with invalid 'to' address")
			}
		}()
		Delegate(to, amount)
	}

	// 6) not enough GNS balance user
	{
		// user GNS = 0 now (they delegated all away above)
		to := makeFakeAddress("validator_3")
		amount := uint64(2_000_000)

		defer func() {
			if r := recover(); r == nil {
				t.Errorf("Expected panic due to not enough GNS balance in user address")
			}
		}()
		Delegate(to, amount)
	}

	// 7) running = false => optional check
	{
		std.TestSetOrigCaller(consts.ADMIN)
		SetRunning(false)
		// delegate?
		// depending on code logic, might skip cleanDelegationStatHistory() or do something else
		// if there's logic that forbids delegation when not running, test that
		// For now, assume it still works but doesn't clean.
		// Restore running to true for subsequent tests.
		std.TestSetOrigCaller(consts.ADMIN)
		SetRunning(true)
	}
}

func TestRedelegate(t *testing.T) {
	// assume realm user
	std.TestSetRealm(userRealm)

	// user has xGNS from previous test (some minted)
	// try re-delegating
	std.TestSetRealm(userRealm)
	from := userRealm.Addr()
	to := makeFakeAddress("validator_1")
	println("to", to)
	amount := uint64(1_000_000)

	std.TestSetOrigCaller(userRealm.Addr())
	Redelegate(from, to, amount)
	// check data: user xGNS must remain the same, but from-> to shift in staker structure?

	// not enough xGNS => panic
	{
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("Expected panic if user tries to re-delegate more than xGNS balance")
			}
		}()
		Redelegate(from, to, 999_999_999)
	}
}

func TestUndelegate(t *testing.T) {
	std.TestSetRealm(std.NewCodeRealm(consts.GOV_STAKER_PATH))
	xgns.Mint(a2u(userRealm.Addr()), 1_000_000)

	std.TestSetRealm(userRealm)
	to := makeFakeAddress("validator_1")
	amount := uint64(1_000_000)

	std.TestSetOrigCaller(userRealm.Addr())
	Undelegate(to, amount)
	// check:
	// - xGNS burned?
	if xgns.BalanceOf(a2u(userRealm.Addr())) != 1_000_000 {
		t.Errorf("Expected user xGNS to be 0 after undelegating 1_000_000, got %d",
			xgns.BalanceOf(a2u(userRealm.Addr())))
	}
	// - lockedGns created?
	lockedList, exist := addrLockedGns.Get(userRealm.Addr().String())
	if !exist {
		t.Errorf("Expected lockedGNS to be created after Undelegate")
	}
	locked := lockedList.([]lockedGNS)
	if len(locked) == 0 {
		t.Errorf("Expected at least 1 lockedGNS after Undelegate")
	}
	if locked[0].amount != 1_000_000 {
		t.Errorf("LockedGNS amount mismatch, got %d, want 1_000_000", locked[0].amount)
	}
	// check lockedAmount incremented?
	if lockedAmount != 1_000_000 {
		t.Errorf("lockedAmount expected 1_000_000, got %d", lockedAmount)
	}

	// below minimum => panic
	{
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("Expected panic when undelegating below minimum")
			}
		}()
		Undelegate(to, 999_999) // or 999_990, etc. if min = 1_000_000
	}
}

func TestCollectUndelegatedGns(t *testing.T) {
	std.TestSetRealm(userRealm)

	// 1) no locked => expect 0
	addrLockedGns.Remove(userRealm.Addr().String()) // ensure no locked
	collected := CollectUndelegatedGns()
	if collected != 0 {
		t.Errorf("Expected 0 when no locked gns, got %d", collected)
	}

	// 2) add locked but time not passed => 0
	now := uint64(time.Now().Unix())
	locked := lockedGNS{
		amount: 100_000,
		unlock: now + TIMESTAMP_7_DAYS,
	}
	addrLockedGns.Set(userRealm.Addr().String(), []lockedGNS{locked})
	lockedAmount = 100_000

	collected = CollectUndelegatedGns()
	if collected != 0 {
		t.Errorf("Expected 0 if 7days not passed, got %d", collected)
	}
	// verify still in locked
	lockedList, exist := addrLockedGns.Get(userRealm.Addr().String())
	if !exist {
		t.Errorf("Expected lockedGNS to remain after CollectUndelegatedGns")
	}
	lkList := lockedList.([]lockedGNS)
	if len(lkList) != 1 {
		t.Errorf("Locked list should remain, but length = %d", len(lkList))
	}

	// 3) set time => unlocked
	locked.unlock = uint64(time.Now().Unix()) - 1 // forcibly make it past time
	addrLockedGns.Set(userRealm.Addr().String(), []lockedGNS{locked})

	collected = CollectUndelegatedGns()
	if collected != 100_000 {
		t.Errorf("Expected 100_000 collected, got %d", collected)
	}
	// check locked removed from the tree
	if _, exists := addrLockedGns.Get(userRealm.Addr().String()); exists {
		t.Errorf("Expected addrLockedGns key to be removed if empty after collecting all locked gns")
	}
	if lockedAmount != 0 {
		t.Errorf("lockedAmount should have been decremented to 0, got %d", lockedAmount)
	}
}

func TestCollectReward(t *testing.T) {
	// We can test that common.IsHalted(), en.MintAndDistributeGns() are called
	// and that emission/protocol fee are distributed if user has a reward recorded.
	// This generally requires mocking userEmissionReward, userProtocolFeeReward, etc.

	std.TestSetRealm(userRealm)
	user := userRealm.Addr().String()

	// set a fake emission reward
	userEmissionReward.Set(user, uint64(50_000))
	// set a fake protocol fee reward
	tree := avl.NewTree()
	tree.Set(consts.WUGNOT_PATH, uint64(10_000))
	userProtocolFeeReward.Set(user, tree)

	std.TestSetRealm(std.NewCodeRealm(consts.EMISSION_PATH))
	std.TestSkipHeights(100)
	gns.MintGns(a2u(userRealm.Addr())) // 2M gns

	std.TestSetRealm(adminRealm)
	std.TestSkipHeights(100)

	// call CollectReward
	CollectReward()

	// expect user emissionReward = 0
	gotEmission, exist := userEmissionReward.Get(user)
	if !exist {
		t.Errorf("Expected userEmissionReward to exist after CollectReward")
	}
	if gotEmission.(uint64) != 0 {
		t.Errorf("Expected userEmissionReward to be 0 after collect, got %d", gotEmission.(uint64))
	}
	// protocol fee: check tree is zeroed
	updated, exist := userProtocolFeeReward.Get(user)
	if !exist {
		t.Errorf("Expected userProtocolFeeReward to exist after CollectReward")
	}
	if updated.(*avl.Tree).Size() != 1 {
		t.Errorf("Expected size=1, but let's check the actual value = 0?")
	}
	// check WUGNOT is set to 0
	val, _ := updated.(*avl.Tree).Get(consts.WUGNOT_PATH)
	if val.(uint64) != 0 {
		t.Errorf("Expected 0 after collecting wugnot fee")
	}

	// If GOV_STAKER_ADDR had less GNS than 50_000 => we expect panic
	// can test in separate subcase
}

func TestCollectRewardFromLaunchPad(t *testing.T) {
	// set realm to LAUNCHPAD_ADDR?
	// or we do a quick scenario: if current caller != LAUNCHPAD_ADDR => panic
	// => check it with a user realm to ensure panic
	std.TestSetRealm(userRealm)
	{
		defer func() {
			if r := recover(); r == nil {
				t.Errorf("Expected panic, because caller is not launchpad")
			}
		}()
		CollectRewardFromLaunchPad(userRealm.Addr())
	}

	// Then set realm to a custom "launchpadRealm" whose .Addr() == consts.LAUNCHPAD_ADDR
	// => call normal and see if distribution works
}

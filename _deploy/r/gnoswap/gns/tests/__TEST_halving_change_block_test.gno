package gns

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/consts"
)

func TestEmissionAmount(t *testing.T) {
	shouldEQ(t, amountToEmission, 900_000_000_000_000)

	sumAmount := uint64(0)
	for _, amountYearly := range halvingTierAmount {
		sumAmount += uint64(amountYearly)
	}
	shouldEQ(t, sumAmount, amountToEmission)
}

func TestSetHalvingTier(t *testing.T) {
	height := std.GetHeight()
	shouldEQ(t, height, 123)
	std.TestSkipHeights(1)

	dummyAddr := testutils.TestAddress("dummy")
	dummyUser := pusers.AddressOrName(dummyAddr)

	emissionPath := consts.EMISSION_PATH
	emissionRealm := std.NewCodeRealm(emissionPath)
	std.TestSetRealm(emissionRealm)

	oldGns := BalanceOf(dummyUser)
	Mint(dummyUser)
	newGns := BalanceOf(dummyUser)
	shouldEQ(t, newGns-oldGns, 14269406)
	println()
	println()

	gsaAddr := consts.GNOSWAP_ADMIN
	gsaRealm := std.NewUserRealm(gsaAddr)
	std.TestSetRealm(gsaRealm)

	SetHalvingTierBlock(1, 124)
	SetHalvingTierBlock(2, 124)

	SetHalvingTierBlock(3, 125)
	std.TestSkipHeights(1)
	println()
	println()

	std.TestSetRealm(emissionRealm)
	oldGns = BalanceOf(dummyUser)
	Mint(dummyUser)
	newGns = BalanceOf(dummyUser)
	shouldEQ(t, newGns-oldGns, 7134703)
	std.TestSkipHeights(1)
}

func TestSetHalvingTierBlockNoPermission(t *testing.T) {
	dummyAddr := testutils.TestAddress("dummy")
	dummyRealm := std.NewUserRealm(dummyAddr)
	std.TestSetRealm(dummyRealm)

	shouldPanicWithMsg(
		t,
		func() {
			SetHalvingTierBlock(1, 1)
		},
		"only admin(g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c) or governance(g1egdt2l7xjcrm6qjwyd3g60z6e9cnr75pmcuasc) can set halving tier block, called from g1v36k6mteta047h6lta047h6lta047h6lz7gmv8",
	)
}

func TestSetHalvingTierBlockInvalidTier(t *testing.T) {
	gsaAddr := consts.GNOSWAP_ADMIN
	gsaRealm := std.NewUserRealm(gsaAddr)
	std.TestSetRealm(gsaRealm)

	shouldPanicWithMsg(
		t,
		func() {
			SetHalvingTierBlock(0, 1)
		},
		"invalid tier 0",
	)
}

func TestSetHalvingTierBlockInvalidBlock(t *testing.T) {
	gsaAddr := consts.GNOSWAP_ADMIN
	gsaRealm := std.NewUserRealm(gsaAddr)
	std.TestSetRealm(gsaRealm)

	shouldPanic(
		t,
		func() {
			SetHalvingTierBlock(1, 1)
		},
	)
}

func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
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

func shouldPanicWithMsg(t *testing.T, f func(), msg string) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("The code did not panic")
		} else {
			if r != msg {
				t.Errorf("excepted panic(%v), got(%v)", msg, r)
			}
		}
	}()
	f()
}

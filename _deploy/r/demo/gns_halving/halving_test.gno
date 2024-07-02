package gns

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	"gno.land/r/demo/gnoswap/consts"
)

func TestEmissionAmount(t *testing.T) {
	shouldEQ(t, amountToEmission, 900_000_000_000_000)

	sumAmount := uint64(0)
	for _, amountYearly := range halvingTierAmount {
		sumAmount += uint64(amountYearly)
	}
	shouldEQ(t, sumAmount, amountToEmission)
}

func TestGetHalvingTier(t *testing.T) {
	height := std.GetHeight()

	// year 1
	shouldEQ(t, getHalvingTierByBlock(height+1), 1)
	shouldEQ(t, getHalvingTierByBlock(height+6307200), 1)

	// year 2
	shouldEQ(t, getHalvingTierByBlock(height+6307200+1), 2)
	shouldEQ(t, getHalvingTierByBlock(height+12614400), 2)

	// year 3
	shouldEQ(t, getHalvingTierByBlock(height+12614400+1), 3)
	shouldEQ(t, getHalvingTierByBlock(height+18921600), 3)

	// year 4
	shouldEQ(t, getHalvingTierByBlock(height+18921600+1), 4)
	shouldEQ(t, getHalvingTierByBlock(height+25228800), 4)

	// year 5
	shouldEQ(t, getHalvingTierByBlock(height+25228800+1), 5)
	shouldEQ(t, getHalvingTierByBlock(height+31536000), 5)

	// year 6
	shouldEQ(t, getHalvingTierByBlock(height+31536000+1), 6)
	shouldEQ(t, getHalvingTierByBlock(height+37843200), 6)

	// year 7
	shouldEQ(t, getHalvingTierByBlock(height+37843200+1), 7)
	shouldEQ(t, getHalvingTierByBlock(height+44150400), 7)

	// year 8
	shouldEQ(t, getHalvingTierByBlock(height+44150400+1), 8)
	shouldEQ(t, getHalvingTierByBlock(height+50457600), 8)

	// year 9
	shouldEQ(t, getHalvingTierByBlock(height+50457600+1), 9)
	shouldEQ(t, getHalvingTierByBlock(height+56764800), 9)

	// year 10
	shouldEQ(t, getHalvingTierByBlock(height+56764800+1), 10)
	shouldEQ(t, getHalvingTierByBlock(height+63072000), 10)

	// year 11
	shouldEQ(t, getHalvingTierByBlock(height+63072000+1), 11)
	shouldEQ(t, getHalvingTierByBlock(height+69379200), 11)

	// year 12
	shouldEQ(t, getHalvingTierByBlock(height+69379200+1), 12)
	shouldEQ(t, getHalvingTierByBlock(height+75686400), 12)

	// emission end
	shouldEQ(t, getHalvingTierByBlock(height+75686400+1), 0)

}

func TestGetAmountByHeight(t *testing.T) {
	// height := std.GetHeight()

	// year 1
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 35_673_515)
	std.TestSkipHeights(6307200)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 35_673_515)

	// year 2
	std.TestSkipHeights(1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 35_673_515)
	std.TestSkipHeights(6307200 - 1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 35_673_515)

	// year 3
	std.TestSkipHeights(1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 17_836_757)
	std.TestSkipHeights(6307200 - 1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 17_836_757)

	// year 4
	std.TestSkipHeights(1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 17_836_757)
	std.TestSkipHeights(6307200 - 1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 17_836_757)

	// year 5
	std.TestSkipHeights(1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 8_918_378)
	std.TestSkipHeights(6307200 - 1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 8_918_378)

	// year 6
	std.TestSkipHeights(1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 8_918_378)
	std.TestSkipHeights(6307200 - 1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 8_918_378)

	// year 7
	std.TestSkipHeights(1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 4_459_189)
	std.TestSkipHeights(6307200 - 1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 4_459_189)

	// year 8
	std.TestSkipHeights(1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 4_459_189)
	std.TestSkipHeights(6307200 - 1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 4_459_189)

	// year 9
	std.TestSkipHeights(1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 2_229_594)
	std.TestSkipHeights(6307200 - 1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 2_229_594)

	// year 10
	std.TestSkipHeights(1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 2_229_594)
	std.TestSkipHeights(6307200 - 1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 2_229_594)

	// year 11
	std.TestSkipHeights(1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 2_229_594)
	std.TestSkipHeights(6307200 - 1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 2_229_594)

	// year 12
	std.TestSkipHeights(1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 2_229_594)
	std.TestSkipHeights(6307200 - 1)
	shouldEQ(t, getAmountByHeight(std.GetHeight()), 2_229_594)
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
		"only admin(g13f63ua8uhmuf9mgc0x8zfz04yrsaqh7j78vcgq) or governance(g1kmat25auuqf0h5qvd4q7s707r8let5sky4tr76) can set halving tier block, called from g1v36k6mteta047h6lta047h6lta047h6lz7gmv8",
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

	shouldPanicWithMsg(
		t,
		func() {
			SetHalvingTierBlock(1, 123456)
		},
		"cannot set block less than current block 75686523",
	)
}

func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
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

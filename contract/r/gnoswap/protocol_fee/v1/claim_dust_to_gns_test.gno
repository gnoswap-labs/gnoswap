package v1

import (
	"chain/runtime"
	"testing"
	"time"

	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gns"

	_ "gno.land/r/gnoswap/rbac"
)

const (
	barPath = "gno.land/r/onbloc/bar"
)

func TestClaimDustToGns_Success(t *testing.T) {
	pf := createTestProtocolFee(t)
	mock := &mockRouter{exactInResultIn: "3", exactInResultOut: "-5"}
	_ = registerMockRouter(t, mock)

	setDustRange(t, pf, 1, 1000)

	beforeProtocolGns := gns.BalanceOf(protocolFeeAddr)
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, protocolFeeAddr, 7)
	common.SafeGRC20Transfer(cross, barPath, protocolFeeAddr, 3)

	recordProtocolFeeToken(t, pf, barPath, 3)
	recordProtocolFeeToken(t, pf, gnsTokenPath, 2)

	beforeGovGns := gns.BalanceOf(govStakerAddr)

	totalGnsOut := callClaimDustToGns(
		t,
		govStakerRealm,
		pf,
		[]string{barPath, gnsTokenPath},
		[]int64{3, 2},
		[]string{barPath + ":" + gnsTokenPath + ":3000", ""},
		[]string{"100", ""},
		[]string{"1", ""},
		time.Now().Add(time.Hour).Unix(),
		"",
		govStakerAddr,
	)

	uassert.Equal(t, int64(7), totalGnsOut, "totalGnsOut mismatch")
	uassert.Equal(t, 1, mock.exactInCalls, "router should be called once")
	uassert.Equal(t, int64(0), pf.GetAmountOfToken(barPath), "bar recorded amount mismatch")
	uassert.Equal(t, int64(0), pf.GetAmountOfToken(gnsTokenPath), "gns recorded amount mismatch")
	uassert.Equal(t, int64(7), gns.BalanceOf(govStakerAddr)-beforeGovGns, "govStaker GNS delta mismatch")
	uassert.Equal(t, beforeProtocolGns, gns.BalanceOf(protocolFeeAddr), "protocolFee GNS balance mismatch")
}

func TestClaimDustToGns_LengthMismatch(t *testing.T) {
	pf := createTestProtocolFee(t)

	uassert.AbortsContains(t, "length mismatch", func() {
		callClaimDustToGns(
			t,
			govStakerRealm,
			pf,
			[]string{barPath},
			[]int64{1, 2},
			[]string{"x"},
			[]string{"100"},
			[]string{"1"},
			time.Now().Unix(),
			"",
			govStakerAddr,
		)
	})
}

func TestClaimDustToGns_Unauthorized(t *testing.T) {
	pf := createTestProtocolFee(t)

	uassert.AbortsContains(t, "unauthorized: caller", func() {
		callClaimDustToGns(
			t,
			dummyRealm,
			pf,
			[]string{barPath},
			[]int64{1},
			[]string{"x"},
			[]string{"100"},
			[]string{"1"},
			time.Now().Unix(),
			"",
			govStakerAddr,
		)
	})
}

func TestClaimDustToGns_AmountExceedsRecorded(t *testing.T) {
	pf := createTestProtocolFee(t)
	setDustRange(t, pf, 1, 1000)

	recordProtocolFeeToken(t, pf, barPath, 2)

	uassert.AbortsContains(t, "amount(3) should be less than or equal to recorded(2)", func() {
		callClaimDustToGns(
			t,
			govStakerRealm,
			pf,
			[]string{barPath},
			[]int64{3},
			[]string{barPath + ":" + gnsTokenPath + ":3000"},
			[]string{"100"},
			[]string{"1"},
			time.Now().Unix(),
			"",
			govStakerAddr,
		)
	})
}

func TestClaimDustToGns_AmountExceedsBalance(t *testing.T) {
	pf := createTestProtocolFee(t)
	currentBalance := common.BalanceOf(barPath, protocolFeeAddr)
	amount := currentBalance + 1
	setDustRange(t, pf, 1, amount+1)
	recordProtocolFeeToken(t, pf, barPath, amount)

	uassert.AbortsContains(t, ufmt.Sprintf("amount(%d) should be less than or equal to balance(%d)", amount, currentBalance), func() {
		callClaimDustToGns(
			t,
			govStakerRealm,
			pf,
			[]string{barPath},
			[]int64{amount},
			[]string{barPath + ":" + gnsTokenPath + ":3000"},
			[]string{"100"},
			[]string{"1"},
			time.Now().Unix(),
			"",
			govStakerAddr,
		)
	})
}

func TestClaimDustToGns_MissingRoute(t *testing.T) {
	pf := createTestProtocolFee(t)
	setDustRange(t, pf, 1, 1000)

	testing.SetRealm(adminRealm)
	common.SafeGRC20Transfer(cross, barPath, protocolFeeAddr, 1)
	recordProtocolFeeToken(t, pf, barPath, 1)

	uassert.AbortsContains(t, "routeArr should not be empty", func() {
		callClaimDustToGns(
			t,
			govStakerRealm,
			pf,
			[]string{barPath},
			[]int64{1},
			[]string{""},
			[]string{"100"},
			[]string{"1"},
			time.Now().Unix(),
			"",
			govStakerAddr,
		)
	})
}

func TestClaimDustToGns_InvalidRouterOutput(t *testing.T) {
	pf := createTestProtocolFee(t)
	mock := &mockRouter{exactInResultIn: "1", exactInResultOut: "notnum"}
	_ = registerMockRouter(t, mock)

	setDustRange(t, pf, 1, 1000)

	testing.SetRealm(adminRealm)
	common.SafeGRC20Transfer(cross, barPath, protocolFeeAddr, 1)
	recordProtocolFeeToken(t, pf, barPath, 1)

	uassert.AbortsContains(t, "invalid syntax", func() {
		callClaimDustToGns(
			t,
			govStakerRealm,
			pf,
			[]string{barPath},
			[]int64{1},
			[]string{barPath + ":" + gnsTokenPath + ":3000"},
			[]string{"100"},
			[]string{"1"},
			time.Now().Unix(),
			"",
			govStakerAddr,
		)
	})
}

func TestClaimDustToGns_SkipsIneligible(t *testing.T) {
	pf := createTestProtocolFee(t)
	mock := &mockRouter{exactInResultIn: "1", exactInResultOut: "1"}
	_ = registerMockRouter(t, mock)

	setDustRange(t, pf, 2, 4)

	testing.SetRealm(adminRealm)
	common.SafeGRC20Transfer(cross, barPath, protocolFeeAddr, 1)
	recordProtocolFeeToken(t, pf, barPath, 1)

	totalGnsOut := callClaimDustToGns(
		t,
		govStakerRealm,
		pf,
		[]string{barPath, "gno.land/r/onbloc/qux"},
		[]int64{1, 0},
		[]string{barPath + ":" + gnsTokenPath + ":3000", "x"},
		[]string{"100", "100"},
		[]string{"1", "1"},
		time.Now().Unix(),
		"",
		govStakerAddr,
	)

	uassert.Equal(t, int64(0), totalGnsOut, "totalGnsOut mismatch")
	uassert.Equal(t, 0, mock.exactInCalls, "router should not be called")
	uassert.Equal(t, int64(1), pf.GetAmountOfToken(barPath), ufmt.Sprintf("recorded amount mismatch: %d", pf.GetAmountOfToken(barPath)))
}

func callClaimDustToGns(
	t *testing.T,
	callerRealm runtime.Realm,
	pf *protocolFeeV1,
	tokenPaths []string,
	amounts []int64,
	routeArrs []string,
	quoteArrs []string,
	amountOutMins []string,
	deadline int64,
	referrer string,
	recipient address,
) int64 {
	t.Helper()

	var result int64
	testing.SetRealm(callerRealm)
	func(cur realm) {
		testing.SetRealm(protocolFeeRealm)
		result = pf.ClaimDustToGns(tokenPaths, amounts, routeArrs, quoteArrs, amountOutMins, deadline, referrer, recipient)
	}(cross)

	return result
}

func setDustRange(t *testing.T, pf *protocolFeeV1, min, max int64) {
	t.Helper()

	testing.SetRealm(adminRealm)
	func(cur realm) {
		testing.SetRealm(protocolFeeRealm)
		pf.SetDustClaimMaxAmount(max)
		pf.SetDustClaimMinAmount(min)
	}(cross)
}

func recordProtocolFeeToken(t *testing.T, pf *protocolFeeV1, tokenPath string, amount int64) {
	t.Helper()

	testing.SetRealm(stakerRealm)
	func(cur realm) {
		testing.SetRealm(protocolFeeRealm)
		pf.AddToProtocolFee(tokenPath, amount)
	}(cross)
}

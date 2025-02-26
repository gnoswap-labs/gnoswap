package protocol_fee

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/p/gnoswap/consts"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"

	"gno.land/r/gnoswap/v1/access"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)
	adminUser    = adminAddr

	protocolFeeAddr, _ = access.GetAddress(access.ROLE_PROTOCOL_FEE)
	devOpsAddr, _      = access.GetAddress(access.ROLE_DEVOPS)
	govStakerAddr, _   = access.GetAddress(access.ROLE_GOV_STAKER)
)

func TestDistributeProtocolFee(t *testing.T) {
	// admin > protocol_fee
	// send qux, bar for testing
	std.TestSetRealm(adminRealm)
	bar.Transfer(protocolFeeAddr, 1000)
	qux.Transfer(protocolFeeAddr, 1000)

	uassert.Equal(t, bar.BalanceOf(protocolFeeAddr), uint64(1000))
	uassert.Equal(t, bar.BalanceOf(devOpsAddr), uint64(0))
	uassert.Equal(t, bar.BalanceOf(govStakerAddr), uint64(0))

	uassert.Equal(t, qux.BalanceOf(protocolFeeAddr), uint64(1000))
	uassert.Equal(t, qux.BalanceOf(devOpsAddr), uint64(0))
	uassert.Equal(t, qux.BalanceOf(govStakerAddr), uint64(0))

	DistributeProtocolFee()

	uassert.Equal(t, bar.BalanceOf(protocolFeeAddr), uint64(0))
	uassert.Equal(t, bar.BalanceOf(devOpsAddr), uint64(0))
	uassert.Equal(t, bar.BalanceOf(govStakerAddr), uint64(1000))

	uassert.Equal(t, qux.BalanceOf(consts.PROTOCOL_FEE_ADDR), uint64(0))
	uassert.Equal(t, qux.BalanceOf(devOpsAddr), uint64(0))
	uassert.Equal(t, qux.BalanceOf(govStakerAddr), uint64(1000))
}

func TestSetDevOpsPctByAdminNoPermission(t *testing.T) {
	dummy := testutils.TestAddress("dummy")
	dummyRealm := std.NewUserRealm(dummy)
	std.TestSetRealm(dummyRealm)

	uassert.PanicsWithMessage(
		t, `caller(g1v36k6mteta047h6lta047h6lta047h6lz7gmv8) has no permission`, func() { SetDevOpsPctByAdmin(123) },
	)
}

func TestSetDevOpsPctByAdminInvalidFee(t *testing.T) {
	std.TestSetRealm(adminRealm)

	uassert.PanicsWithMessage(
		t,
		`[GNOSWAP-PROTOCOL_FEE-002] invalid percentage || pct(100001) should not be bigger than 10000`,
		func() {
			SetDevOpsPctByAdmin(100001)
		},
	)
}

func TestSetDevOpsPctByAdmin(t *testing.T) {
	std.TestSetRealm(adminRealm)

	uassert.Equal(t, GetDevOpsPct(), uint64(0))

	SetDevOpsPctByAdmin(123)
	uassert.Equal(t, GetDevOpsPct(), uint64(123))
}

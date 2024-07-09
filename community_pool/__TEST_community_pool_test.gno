package community_pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"

	"gno.land/r/gnoswap/consts"

	"gno.land/r/gnoswap/gns"
)

func TestTransferGnsNoPermission(t *testing.T) {
	dummy := testutils.TestAddress("dummy")
	dummyRealm := std.NewUserRealm(dummy)

	std.TestSetRealm(dummyRealm)
	shouldPanicWithMsg(
		t,
		func() {
			TransferGns(dummy, 1000)
		},
		"[COMMUNITY_POOL] community_pool.gno__TransferGns() || only admin(g1lmvrrrr4er2us84h2732sru76c9zl2nvknha8c) or governance(g1egdt2l7xjcrm6qjwyd3g60z6e9cnr75pmcuasc) can set transfer gns, called from g1v36k6mteta047h6lta047h6lta047h6lz7gmv8",
	)
}

func TestTransferGns(t *testing.T) {
	gsaRealm := std.NewUserRealm(consts.GNOSWAP_ADMIN)
	std.TestSetOrigCaller(consts.GNOSWAP_ADMIN)
	std.TestSetRealm(gsaRealm)

	gns.Transfer(a2u(consts.COMMUNITY_POOL_ADDR), 1000)
	shouldEQ(t, gns.BalanceOf(a2u(consts.COMMUNITY_POOL_ADDR)), 1000)

	sendTarget := testutils.TestAddress("sendTarget")
	TransferGns(sendTarget, 900)
	shouldEQ(t, gns.BalanceOf(a2u(consts.COMMUNITY_POOL_ADDR)), 100)
	shouldEQ(t, gns.BalanceOf(a2u(sendTarget)), 900)
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

func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

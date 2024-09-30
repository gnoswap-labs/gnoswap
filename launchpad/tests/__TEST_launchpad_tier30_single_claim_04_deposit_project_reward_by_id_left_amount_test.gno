package launchpad

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"

	"gno.land/r/gnoswap/v2/consts"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/obl"

	"gno.land/r/gnoswap/v2/gns"
)

var (
	projectAddr = testutils.TestAddress("projectAddr")
	user01      = testutils.TestAddress("user01")

	projectRealm = std.NewUserRealm(projectAddr)
	user01Realm  = std.NewUserRealm(user01)
)

func init() {
	println("test_init")
}

func TestCreateProject(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	std.TestSetOrigCaller(gsa)

	obl.Approve(a2u(consts.LAUNCHPAD_ADDR), uint64(1_000_000_000))
	std.TestSkipHeights(1)

	CreateProject(
		oblPath,
		projectAddr,
		uint64(1_000_000_000), // 1000000000
		"gno.land/r/onbloc/foo*PAD*gno.land/r/onbloc/bar",
		"1*PAD*2",
		uint64(10),                   // 100000000
		uint64(20),                   // 200000000
		uint64(70),                   // 700000000
		uint64(time.Now().Unix()+10), // 5 block later
	)
	std.TestSkipHeights(10) // skip 10 block, make project active
}

func TestDepositGnsToTier30(t *testing.T) {
	std.TestSetRealm(gsaRealm)
	std.TestSetOrigCaller(gsa)
	gns.Transfer(a2u(user01), uint64(1_000_000)) // to deposit
	// transfer some grc20 tokens to bypass project condition
	foo.Transfer(a2u(user01), uint64(10))
	bar.Transfer(a2u(user01), uint64(10))

	std.TestSetRealm(user01Realm)
	std.TestSetOrigCaller(user01)
	gns.Approve(a2u(consts.LAUNCHPAD_ADDR), uint64(1_000_000))

	// skip some blocks to make project active
	std.TestSkipHeights(4)
	DepositGns("gno.land/r/onbloc/obl:124:30", uint64(1_000_000))
	std.TestSkipHeights(1)
}

func TestClaimRewardByProjectId(t *testing.T) {
	std.TestSetRealm(user01Realm)
	std.TestSetOrigCaller(user01)

	t.Run("claim reward before 30 days", func(t *testing.T) {
		reward := ClaimRewardByProjectId(`gno.land/r/onbloc/obl:124`)
		shouldEQ(t, reward, uint64(0))
		std.TestSkipHeights(1)
		println()
	})

	t.Run("claim after 30 days", func(t *testing.T) {
		std.TestSkipHeights(int64(TIMESTAMP_30DAYS) / 2)
		reward := ClaimRewardByProjectId(`gno.land/r/onbloc/obl:124`)
		shouldEQ(t, reward, uint64(99999305))
		println()
	})

	t.Run("no more claim in same block", func(t *testing.T) {
		reward := ClaimRewardByProjectId(`gno.land/r/onbloc/obl:124`)
		shouldEQ(t, reward, uint64(0))
		println()
	})

	//
	shouldEQ(t, len(deposits), 1)
	deposit := deposits[`gno.land/r/onbloc/obl:124:30:g1w4ek2u3sx9047h6lta047h6lta047h6lh0ssfv:138`]
	shouldEQ(t, deposit.id, `gno.land/r/onbloc/obl:124:30:g1w4ek2u3sx9047h6lta047h6lta047h6lh0ssfv:138`)
	shouldEQ(t, deposit.projectId, `gno.land/r/onbloc/obl:124`)
	shouldEQ(t, deposit.tier, `30`)
	shouldEQ(t, deposit.depositor, user01)
	shouldEQ(t, deposit.amount, uint64(1000000))
	shouldEQ(t, deposit.depositHeight, uint64(138))
	shouldEQ(t, deposit.depositAt, uint64(1234567920))
	shouldEQ(t, deposit.depositClaimHeight, uint64(0))
	shouldEQ(t, deposit.depositClaimAt, uint64(0))
	shouldEQ(t, deposit.rewardAmount, uint64(0))
	shouldEQ(t, deposit.rewardClaimHeight, uint64(1296140))
	shouldEQ(t, deposit.rewardClaimAt, uint64(1237159924))

	//
	shouldEQ(t, len(depositsByProject), 1)
	shouldEQ(t, depositsByProject[`gno.land/r/onbloc/obl:124`][`30`][0], `gno.land/r/onbloc/obl:124:30:g1w4ek2u3sx9047h6lta047h6lta047h6lh0ssfv:138`)

	//
	shouldEQ(t, len(depositsByUser), 1)
	shouldEQ(t, depositsByUser[`g1w4ek2u3sx9047h6lta047h6lta047h6lh0ssfv`][0], `gno.land/r/onbloc/obl:124:30:g1w4ek2u3sx9047h6lta047h6lta047h6lh0ssfv:138`)
}

func TestRefundProject(t *testing.T) {
	t.Run("unauthorized", func(t *testing.T) {
		std.TestSetRealm(user01Realm)
		std.TestSetOrigCaller(user01)
		shouldPanicWithMsg(
			t,
			func() {
				RefundProject(`gno.land/r/onbloc/obl:124`)
			},
			`only recipient can refund`,
		)
	})

	t.Run("not ended", func(t *testing.T) {
		std.TestSetRealm(projectRealm)
		std.TestSetOrigCaller(projectAddr)
		shouldPanicWithMsg(
			t,
			func() {
				RefundProject(`gno.land/r/onbloc/obl:124`)
			},
			`project not ended yet`,
		)
	})

	t.Run("ended with refund", func(t *testing.T) {
		std.TestSetRealm(projectRealm)
		std.TestSetOrigCaller(projectAddr)
		std.TestSkipHeights(int64(TIMESTAMP_180DAYS) / 2)
		refund := RefundProject(`gno.land/r/onbloc/obl:124`)
		shouldNEQ(t, refund, uint64(0))
		std.TestSkipHeights(1)
	})
}

// PKGPATH: gno.land/r/gnoswap/v1/main

// ProtocolFee contract upgrade scenario test with data validation.
//
// The KV store is shared across implementations, so an upgrade must not move,
// reshape or drop any value. This test writes protocol-fee state with v1,
// snapshots every value the public getters expose, walks the implementation
// through v2_invalid (which must block the calls) up to v3_valid, and then
// asserts the snapshot is byte-for-byte identical before continuing to operate
// on the v1-created data.
package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/access"
	protocolFee "gno.land/r/gnoswap/protocol_fee"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v2_invalid"
	_ "gno.land/r/gnoswap/protocol_fee/v3_valid"
	_ "gno.land/r/gnoswap/rbac"
)

var t *testing.T

const (
	protocolFeeV1Path        = "gno.land/r/gnoswap/protocol_fee/v1"
	protocolFeeV2InvalidPath = "gno.land/r/gnoswap/protocol_fee/v2_invalid"
	protocolFeeV3ValidPath   = "gno.land/r/gnoswap/protocol_fee/v3_valid"

	barPath = "gno.land/r/onbloc/bar.BAR"
	fooPath = "gno.land/r/onbloc/foo.FOO"

	barFeeAmount = int64(1_000_000)
	fooFeeAmount = int64(2_000_000)
)

var (
	adminAddr       = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	protocolFeeAddr = access.MustGetAddress(prbac.ROLE_PROTOCOL_FEE.String())

	adminRealm  = testing.NewUserRealm(adminAddr)
	stakerRealm = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	// AddToProtocolFee transfers from the active implementation realm, so the
	// fee payer approves whichever implementation is live at that moment.
	protocolFeeV1Realm      = testing.NewCodeRealm(protocolFeeV1Path)
	protocolFeeV3ValidRealm = testing.NewCodeRealm(protocolFeeV3ValidPath)

	// snapshot of the v1-written state
	v1DevOpsPct       int64
	v1GovStakerPct    int64
	v1ReservedTokens  []string
	v1AccuGovStakeBar int64
	v1AccuDevOpsBar   int64
	v1AccuGovStakeFoo int64
	v1AccuDevOpsFoo   int64
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize protocol_fee contract with v1")
	initialize(cur)
	println()

	println("[SCENARIO] 2. Write protocol fee data with v1")
	writeDataWithV1(cur)
	println()

	println("[SCENARIO] 3. Snapshot v1 data through the getters")
	captureV1Snapshot()
	println()

	println("[SCENARIO] 4. Upgrade to v2_invalid")
	upgradeTo(cur, protocolFeeV2InvalidPath)
	println()

	println("[SCENARIO] 5. Mutating calls must be blocked by v2_invalid")
	assertAborts(cur, func() {
		testing.SetRealm(adminRealm)
		protocolFee.SetDevOpsPct(cross(cur), 5000)
	}, "[EXPECTED] SetDevOpsPct is blocked by v2_invalid")
	assertAborts(cur, func() {
		testing.SetRealm(adminRealm)
		protocolFee.DistributeProtocolFee(cross(cur))
	}, "[EXPECTED] DistributeProtocolFee is blocked by v2_invalid")
	println()

	println("[SCENARIO] 6. Upgrade to v3_valid")
	upgradeTo(cur, protocolFeeV3ValidPath)
	println()

	println("[SCENARIO] 7. Validate the v1 data through v3_valid")
	validateSnapshot()
	println()

	println("[SCENARIO] 8. Keep operating on the v1-created data with v3_valid")
	operateWithV3Valid(cur)
	println()
}

func initialize(cur realm) {
	testing.SetRealm(adminRealm)
	protocolFee.UpgradeImpl(cross(cur), protocolFeeV1Path)
	println("[EXPECTED] implementation:", protocolFee.GetImplementationPackagePath())
}

func writeDataWithV1(cur realm) {
	testing.SetRealm(adminRealm)
	protocolFee.SetGovStakerPct(cross(cur), 7000)
	protocolFee.SetDevOpsPct(cross(cur), 3000)
	println("[EXPECTED] gov staker pct:", protocolFee.GetGovStakerPct())
	println("[EXPECTED] devops pct:", protocolFee.GetDevOpsPct())

	// AddToProtocolFee pulls the tokens from the caller, so the caller (a
	// protocol realm) is funded first and approves both the protocol_fee proxy
	// and the live implementation realm.
	fundAndApprove(cur, protocolFeeV1Realm.Address())

	testing.SetRealm(stakerRealm)
	if err := protocolFee.AddToProtocolFee(cross(cur), barPath, barFeeAmount); err != nil {
		panic(err)
	}
	if err := protocolFee.AddToProtocolFee(cross(cur), fooPath, fooFeeAmount); err != nil {
		panic(err)
	}
	testing.SkipHeights(1)

	println("[EXPECTED] reserved token count:", len(protocolFee.GetReservedTokens()))
	println("[EXPECTED] BAR accrued (gov staker / devops):",
		protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath),
		protocolFee.GetAccuTransferToDevOpsByTokenPath(barPath))
	println("[EXPECTED] FOO accrued (gov staker / devops):",
		protocolFee.GetAccuTransferToGovStakerByTokenPath(fooPath),
		protocolFee.GetAccuTransferToDevOpsByTokenPath(fooPath))

	// the 70 / 30 split must hold for every accrued token
	uassert.Equal(t, barFeeAmount*7/10, protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath))
	uassert.Equal(t, barFeeAmount*3/10, protocolFee.GetAccuTransferToDevOpsByTokenPath(barPath))
	uassert.Equal(t, fooFeeAmount*7/10, protocolFee.GetAccuTransferToGovStakerByTokenPath(fooPath))
	uassert.Equal(t, fooFeeAmount*3/10, protocolFee.GetAccuTransferToDevOpsByTokenPath(fooPath))
}

func captureV1Snapshot() {
	v1DevOpsPct = protocolFee.GetDevOpsPct()
	v1GovStakerPct = protocolFee.GetGovStakerPct()
	v1ReservedTokens = protocolFee.GetReservedTokens()
	v1AccuGovStakeBar = protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath)
	v1AccuDevOpsBar = protocolFee.GetAccuTransferToDevOpsByTokenPath(barPath)
	v1AccuGovStakeFoo = protocolFee.GetAccuTransferToGovStakerByTokenPath(fooPath)
	v1AccuDevOpsFoo = protocolFee.GetAccuTransferToDevOpsByTokenPath(fooPath)

	println("[EXPECTED] snapshot pct (devops / gov staker):", v1DevOpsPct, v1GovStakerPct)
	println("[EXPECTED] snapshot reserved tokens:", len(v1ReservedTokens))
	for _, tokenPath := range v1ReservedTokens {
		println("[EXPECTED] snapshot reserved token:", tokenPath)
	}
	println("[EXPECTED] snapshot BAR accrued:", v1AccuGovStakeBar, v1AccuDevOpsBar)
	println("[EXPECTED] snapshot FOO accrued:", v1AccuGovStakeFoo, v1AccuDevOpsFoo)
}

func upgradeTo(cur realm, packagePath string) {
	testing.SetRealm(adminRealm)
	protocolFee.UpgradeImpl(cross(cur), packagePath)
	println("[EXPECTED] implementation:", protocolFee.GetImplementationPackagePath())
	uassert.Equal(t, packagePath, protocolFee.GetImplementationPackagePath())
}

func validateSnapshot() {
	uassert.Equal(t, v1DevOpsPct, protocolFee.GetDevOpsPct())
	uassert.Equal(t, v1GovStakerPct, protocolFee.GetGovStakerPct())
	// the reserved-token list drives the distribution loop, so its contents and
	// ordering matter, not just its length
	reservedTokens := protocolFee.GetReservedTokens()
	uassert.Equal(t, len(v1ReservedTokens), len(reservedTokens))
	for i, tokenPath := range v1ReservedTokens {
		uassert.Equal(t, tokenPath, reservedTokens[i])
	}
	uassert.Equal(t, v1AccuGovStakeBar, protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath))
	uassert.Equal(t, v1AccuDevOpsBar, protocolFee.GetAccuTransferToDevOpsByTokenPath(barPath))
	uassert.Equal(t, v1AccuGovStakeFoo, protocolFee.GetAccuTransferToGovStakerByTokenPath(fooPath))
	uassert.Equal(t, v1AccuDevOpsFoo, protocolFee.GetAccuTransferToDevOpsByTokenPath(fooPath))

	println("[EXPECTED] pct after upgrade (devops / gov staker):",
		protocolFee.GetDevOpsPct(), protocolFee.GetGovStakerPct())
	println("[EXPECTED] BAR accrued after upgrade:",
		protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath),
		protocolFee.GetAccuTransferToDevOpsByTokenPath(barPath))
	println("[EXPECTED] FOO accrued after upgrade:",
		protocolFee.GetAccuTransferToGovStakerByTokenPath(fooPath),
		protocolFee.GetAccuTransferToDevOpsByTokenPath(fooPath))
	for _, tokenPath := range reservedTokens {
		println("[EXPECTED] reserved token after upgrade:", tokenPath)
	}
	println("[EXPECTED] every v1 value survived the upgrade")
}

func operateWithV3Valid(cur realm) {
	// add more fee to the SAME token: this read-modify-writes the v1-created
	// per-token tree entry through the new implementation
	testing.SetRealm(adminRealm)
	bar.Transfer(cross(cur), stakerRealm.Address(), barFeeAmount)

	testing.SetRealm(stakerRealm)
	bar.Approve(cross(cur), protocolFeeAddr, barFeeAmount)
	bar.Approve(cross(cur), protocolFeeV3ValidRealm.Address(), barFeeAmount)

	testing.SetRealm(stakerRealm)
	if err := protocolFee.AddToProtocolFee(cross(cur), barPath, barFeeAmount); err != nil {
		panic(err)
	}
	testing.SkipHeights(1)
	println("[EXPECTED] BAR accrued after v3_valid add:",
		protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath),
		protocolFee.GetAccuTransferToDevOpsByTokenPath(barPath))

	// distribute one token explicitly, then everything that is left
	testing.SetRealm(adminRealm)
	protocolFee.DistributeProtocolFeeByTokenPath(cross(cur), barPath)
	testing.SkipHeights(1)
	println("[EXPECTED] BAR distributed (gov staker / devops):",
		protocolFee.GetActualDistributedToGovStakerByTokenPath(barPath),
		protocolFee.GetActualDistributedToDevOpsByTokenPath(barPath))

	protocolFee.DistributeProtocolFee(cross(cur))
	testing.SkipHeights(1)
	println("[EXPECTED] FOO distributed (gov staker / devops):",
		protocolFee.GetActualDistributedToGovStakerByTokenPath(fooPath),
		protocolFee.GetActualDistributedToDevOpsByTokenPath(fooPath))
	println("[EXPECTED] reserved token count after distribution:", len(protocolFee.GetReservedTokens()))

	// everything accrued must end up distributed
	uassert.Equal(t, v1AccuGovStakeBar+barFeeAmount*7/10, protocolFee.GetActualDistributedToGovStakerByTokenPath(barPath))
	uassert.Equal(t, v1AccuDevOpsBar+barFeeAmount*3/10, protocolFee.GetActualDistributedToDevOpsByTokenPath(barPath))
	uassert.Equal(t, v1AccuGovStakeFoo, protocolFee.GetActualDistributedToGovStakerByTokenPath(fooPath))
	uassert.Equal(t, v1AccuDevOpsFoo, protocolFee.GetActualDistributedToDevOpsByTokenPath(fooPath))
}

// fundAndApprove funds the calling protocol realm and approves both the
// protocol_fee proxy and the live implementation realm, which is the address
// grc20reg.TransferFrom actually spends from.
func fundAndApprove(cur realm, implRealmAddr address) {
	testing.SetRealm(adminRealm)
	bar.Transfer(cross(cur), stakerRealm.Address(), barFeeAmount)
	foo.Transfer(cross(cur), stakerRealm.Address(), fooFeeAmount)

	testing.SetRealm(stakerRealm)
	bar.Approve(cross(cur), protocolFeeAddr, barFeeAmount)
	bar.Approve(cross(cur), implRealmAddr, barFeeAmount)
	foo.Approve(cross(cur), protocolFeeAddr, fooFeeAmount)
	foo.Approve(cross(cur), implRealmAddr, fooFeeAmount)
}

func assertAborts(cur realm, callback func(), logMessage string) {
	uassert.AbortsContains(t, cur, "implementation", callback)
	println(logMessage)
}

// Output:
// [SCENARIO] 1. Initialize protocol_fee contract with v1
// [EXPECTED] implementation: gno.land/r/gnoswap/protocol_fee/v1
//
// [SCENARIO] 2. Write protocol fee data with v1
// [EXPECTED] gov staker pct: 7000
// [EXPECTED] devops pct: 3000
// [EXPECTED] reserved token count: 2
// [EXPECTED] BAR accrued (gov staker / devops): 700000 300000
// [EXPECTED] FOO accrued (gov staker / devops): 1400000 600000
//
// [SCENARIO] 3. Snapshot v1 data through the getters
// [EXPECTED] snapshot pct (devops / gov staker): 3000 7000
// [EXPECTED] snapshot reserved tokens: 2
// [EXPECTED] snapshot reserved token: gno.land/r/onbloc/bar.BAR
// [EXPECTED] snapshot reserved token: gno.land/r/onbloc/foo.FOO
// [EXPECTED] snapshot BAR accrued: 700000 300000
// [EXPECTED] snapshot FOO accrued: 1400000 600000
//
// [SCENARIO] 4. Upgrade to v2_invalid
// [EXPECTED] implementation: gno.land/r/gnoswap/protocol_fee/v2_invalid
//
// [SCENARIO] 5. Mutating calls must be blocked by v2_invalid
// [EXPECTED] SetDevOpsPct is blocked by v2_invalid
// [EXPECTED] DistributeProtocolFee is blocked by v2_invalid
//
// [SCENARIO] 6. Upgrade to v3_valid
// [EXPECTED] implementation: gno.land/r/gnoswap/protocol_fee/v3_valid
//
// [SCENARIO] 7. Validate the v1 data through v3_valid
// [EXPECTED] pct after upgrade (devops / gov staker): 3000 7000
// [EXPECTED] BAR accrued after upgrade: 700000 300000
// [EXPECTED] FOO accrued after upgrade: 1400000 600000
// [EXPECTED] reserved token after upgrade: gno.land/r/onbloc/bar.BAR
// [EXPECTED] reserved token after upgrade: gno.land/r/onbloc/foo.FOO
// [EXPECTED] every v1 value survived the upgrade
//
// [SCENARIO] 8. Keep operating on the v1-created data with v3_valid
// [EXPECTED] BAR accrued after v3_valid add: 1400000 600000
// [EXPECTED] BAR distributed (gov staker / devops): 1400000 600000
// [EXPECTED] FOO distributed (gov staker / devops): 1400000 600000
// [EXPECTED] reserved token count after distribution: 0

// PKGPATH: gno.land/r/gnoswap/v1/main

// ProtocolFee contract upgrade to v2_valid scenario test.
//
// Goal: prove interrealm v2 readonly-taint does NOT occur when the v2_valid
// implementation mutates v1-created data. v2_valid is a symlinked copy of the
// v1 sources under a v2_valid module path (gno.land/r/gnoswap/protocol_fee/
// v2_valid). Storage is shared across versions, so the scalar config and the
// per-token accumulated-fee BPTrees created with v1 persist and must remain
// mutable through v2_valid via realm-owned trees and domain methods.
//
// Coverage: all state-mutating protocol_fee entry points are exercised through
// the v2_valid implementation AFTER the upgrade:
//   - SetGovStakerPct / SetDevOpsPct (scalar config; coupled, sum to 10000)
//   - AddToProtocolFee (THE taint test: RMWs the AccuToGovStaker / AccuToDevOps
//     per-token BPTrees; the same token's v1-created tree entry is mutated by
//     v2_valid)
//   - DistributeProtocolFee (RMWs the accu trees + distributed-history trees)
//
// Scenario:
//  1. Initialize protocol_fee with v1.
//  2. With v1: set scalar config and AddToProtocolFee(bar) — creates the
//     reserved-token entry + per-token accumulated-fee BPTree nodes.
//  3. Upgrade to v2_valid.
//  4. Read v1-created data through v2_valid (shared storage).
//  5. With v2_valid: MUTATE the v1-created structures via real entry points
//     (SetDevOpsPct/SetGovStakerPct, AddToProtocolFee for the SAME token to RMW
//     the v1-allocated tree node, then DistributeProtocolFee). A broken
//     migration would panic with a readonly-taint error here.
//  6. Read final accumulated + distributed data and show it updated.
package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	protocolFee "gno.land/r/gnoswap/protocol_fee"

	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v2_valid"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/onbloc/bar"
)

var (
	adminAddr, _       = access.GetAddress(prbac.ROLE_ADMIN.String())
	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	govStakerAddr, _   = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	devOpsAddr, _      = access.GetAddress(prbac.ROLE_DEVOPS.String())

	adminRealm     = testing.NewUserRealm(adminAddr)
	stakerRealm    = testing.NewCodeRealm("gno.land/r/gnoswap/staker")
	govStakerRealm = testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker")

	// AddToProtocolFee performs SafeGRC20TransferFrom from the *implementation*
	// realm, so the caller must approve whichever implementation realm is
	// currently active (v1 before the upgrade, v2_valid after).
	protocolFeeV1Realm      = testing.NewCodeRealm(protocolFeeV1Path)
	protocolFeeV2ValidRealm = testing.NewCodeRealm(protocolFeeV2ValidPath)
)

const (
	protocolFeeV1Path      = "gno.land/r/gnoswap/protocol_fee/v1"
	protocolFeeV2ValidPath = "gno.land/r/gnoswap/protocol_fee/v2_valid"

	barPath = "gno.land/r/onbloc/bar"
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize protocol_fee contract with v1")
	initializeV1(cur)
	println()

	println("[SCENARIO] 2. Set data with v1 implementation")
	setDataV1(cur)
	println()

	println("[SCENARIO] 3. Add protocol fee with v1 (creates per-token BPTree entry)")
	addProtocolFeeV1(cur)
	println()

	println("[SCENARIO] 4. Upgrade protocol_fee contract to v2_valid")
	upgradeToV2Valid(cur)
	println()

	println("[SCENARIO] 5. Read v1 data through v2_valid (shared storage)")
	readDataAfterUpgrade(cur)
	println()

	println("[SCENARIO] 6. Update scalar config with v2_valid and verify")
	updateConfigV2Valid(cur)
	println()

	println("[SCENARIO] 7. Add protocol fee with v2_valid (RMW v1-created BPTree entry)")
	addProtocolFeeV2Valid(cur)
	println()

	println("[SCENARIO] 8. Distribute protocol fee with v2_valid (RMW accu + history trees)")
	distributeProtocolFeeV2Valid(cur)
	println()
}

func initializeV1(cur realm) {
	testing.SetRealm(adminRealm)
	protocolFee.UpgradeImpl(cross(cur), protocolFeeV1Path)
	ufmt.Printf("[EXPECTED] Current implementation: %s\n", protocolFee.GetImplementationPackagePath())
}

func setDataV1(cur realm) {
	testing.SetRealm(adminRealm)
	// Percentages are basis points (10000 = 100%) and are coupled: setting one
	// auto-adjusts the other so they sum to 10000.
	protocolFee.SetGovStakerPct(cross(cur), 7000)
	protocolFee.SetDevOpsPct(cross(cur), 3000)
	ufmt.Printf("[EXPECTED] GovStakerPct set to: %d\n", protocolFee.GetGovStakerPct())
	ufmt.Printf("[EXPECTED] DevOpsPct set to: %d\n", protocolFee.GetDevOpsPct())
}

// fundAndApproveBarFromStaker funds the staker realm with bar and approves both
// the protocol_fee role address and the given implementation realm (the spender
// inside AddToProtocolFee's TransferFrom).
func fundAndApproveBarFromStaker(cur realm, implRealmAddr address, amount int64) {
	testing.SetRealm(adminRealm)
	bar.Transfer(cross(cur), stakerRealm.Address(), amount)

	testing.SetRealm(stakerRealm)
	bar.Approve(cross(cur), protocolFeeAddr, amount)
	bar.Approve(cross(cur), implRealmAddr, amount)
}

func addProtocolFeeV1(cur realm) {
	fundAndApproveBarFromStaker(cur, protocolFeeV1Realm.Address(), 1000)

	testing.SetRealm(stakerRealm)
	if err := protocolFee.AddToProtocolFee(cross(cur), barPath, 1000); err != nil {
		panic(err)
	}

	ufmt.Printf("[EXPECTED] bar protocol_fee balance: %d\n", bar.BalanceOf(protocolFeeAddr))
	ufmt.Printf("[EXPECTED] accu to govStaker (bar): %d\n", protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath))
	ufmt.Printf("[EXPECTED] accu to devOps (bar): %d\n", protocolFee.GetAccuTransferToDevOpsByTokenPath(barPath))
}

func upgradeToV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	protocolFee.UpgradeImpl(cross(cur), protocolFeeV2ValidPath)
	ufmt.Printf("[EXPECTED] Upgraded to: %s\n", protocolFee.GetImplementationPackagePath())
}

func readDataAfterUpgrade(cur realm) {
	ufmt.Printf("[EXPECTED] GovStakerPct still: %d\n", protocolFee.GetGovStakerPct())
	ufmt.Printf("[EXPECTED] DevOpsPct still: %d\n", protocolFee.GetDevOpsPct())
	ufmt.Printf("[EXPECTED] accu to govStaker (bar) still: %d\n", protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath))
	ufmt.Printf("[EXPECTED] accu to devOps (bar) still: %d\n", protocolFee.GetAccuTransferToDevOpsByTokenPath(barPath))
}

func updateConfigV2Valid(cur realm) {
	testing.SetRealm(adminRealm)
	protocolFee.SetDevOpsPct(cross(cur), 2000)
	protocolFee.SetGovStakerPct(cross(cur), 8000)
	ufmt.Printf("[EXPECTED] DevOpsPct updated to: %d\n", protocolFee.GetDevOpsPct())
	ufmt.Printf("[EXPECTED] GovStakerPct updated to: %d\n", protocolFee.GetGovStakerPct())
}

func addProtocolFeeV2Valid(cur realm) {
	// Approve the v2_valid implementation realm this time (the new spender).
	fundAndApproveBarFromStaker(cur, protocolFeeV2ValidRealm.Address(), 1000)

	testing.SetRealm(stakerRealm)
	// Same token as v1: this RMWs the v1-created per-token BPTree entries.
	if err := protocolFee.AddToProtocolFee(cross(cur), barPath, 1000); err != nil {
		panic(err)
	}

	ufmt.Printf("[EXPECTED] bar protocol_fee balance: %d\n", bar.BalanceOf(protocolFeeAddr))
	ufmt.Printf("[EXPECTED] accu to govStaker (bar) after RMW: %d\n", protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath))
	ufmt.Printf("[EXPECTED] accu to devOps (bar) after RMW: %d\n", protocolFee.GetAccuTransferToDevOpsByTokenPath(barPath))
}

func distributeProtocolFeeV2Valid(cur realm) {
	testing.SetRealm(govStakerRealm)
	protocolFee.DistributeProtocolFee(cross(cur))

	ufmt.Printf("[EXPECTED] bar protocol_fee balance after distribute: %d\n", bar.BalanceOf(protocolFeeAddr))
	ufmt.Printf("[EXPECTED] bar govStaker balance after distribute: %d\n", bar.BalanceOf(govStakerAddr))
	ufmt.Printf("[EXPECTED] bar devOps balance after distribute: %d\n", bar.BalanceOf(devOpsAddr))
	ufmt.Printf("[EXPECTED] distributed to govStaker (bar): %d\n", protocolFee.GetActualDistributedToGovStakerByTokenPath(barPath))
	ufmt.Printf("[EXPECTED] distributed to devOps (bar): %d\n", protocolFee.GetActualDistributedToDevOpsByTokenPath(barPath))
}

// Output:
// [SCENARIO] 1. Initialize protocol_fee contract with v1
// [EXPECTED] Current implementation: gno.land/r/gnoswap/protocol_fee/v1
//
// [SCENARIO] 2. Set data with v1 implementation
// [EXPECTED] GovStakerPct set to: 7000
// [EXPECTED] DevOpsPct set to: 3000
//
// [SCENARIO] 3. Add protocol fee with v1 (creates per-token BPTree entry)
// [EXPECTED] bar protocol_fee balance: 1000
// [EXPECTED] accu to govStaker (bar): 700
// [EXPECTED] accu to devOps (bar): 300
//
// [SCENARIO] 4. Upgrade protocol_fee contract to v2_valid
// [EXPECTED] Upgraded to: gno.land/r/gnoswap/protocol_fee/v2_valid
//
// [SCENARIO] 5. Read v1 data through v2_valid (shared storage)
// [EXPECTED] GovStakerPct still: 7000
// [EXPECTED] DevOpsPct still: 3000
// [EXPECTED] accu to govStaker (bar) still: 700
// [EXPECTED] accu to devOps (bar) still: 300
//
// [SCENARIO] 6. Update scalar config with v2_valid and verify
// [EXPECTED] DevOpsPct updated to: 2000
// [EXPECTED] GovStakerPct updated to: 8000
//
// [SCENARIO] 7. Add protocol fee with v2_valid (RMW v1-created BPTree entry)
// [EXPECTED] bar protocol_fee balance: 2000
// [EXPECTED] accu to govStaker (bar) after RMW: 1500
// [EXPECTED] accu to devOps (bar) after RMW: 500
//
// [SCENARIO] 8. Distribute protocol fee with v2_valid (RMW accu + history trees)
// [EXPECTED] bar protocol_fee balance after distribute: 0
// [EXPECTED] bar govStaker balance after distribute: 1500
// [EXPECTED] bar devOps balance after distribute: 500
// [EXPECTED] distributed to govStaker (bar): 1500
// [EXPECTED] distributed to devOps (bar): 500
//

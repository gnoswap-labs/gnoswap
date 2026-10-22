// PKGPATH: gno.land/r/gnoswap/v1/main

// Protocol-fee legacy-to-patched upgrade scenario using an immutable v1 source
// snapshot from PR1481's merge commit. Fees enter through AddToProtocolFee and
// leave through the proxy distribution API; no implementation-private state is
// seeded by this scenario.
package main

import (
	"chain/runtime"
	"testing"

	prbac "gno.land/p/gnoswap/rbac/v1"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access/v1"
	protocolFee "gno.land/r/gnoswap/protocol_fee"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	_ "gno.land/r/gnoswap/common/v1"
	_ "gno.land/r/gnoswap/protocol_fee/legacy"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/rbac/v1"
)

var t = &testing.T{}

const (
	protocolFeeLegacyPath = "gno.land/r/gnoswap/protocol_fee/legacy"
	protocolFeeV1Path     = "gno.land/r/gnoswap/protocol_fee/v1"
	barPath               = "gno.land/r/onbloc/bar.BAR"
	fooPath               = "gno.land/r/onbloc/foo.FOO"

	maxInt64                = int64(9223372036854775807)
	wrapFeeAmount           = int64(1001)
	wrappedAfterWrapFee     = int64(-9223372036854774808)
	barGovBeforeBoundary    = int64(945)
	barDevOpsBeforeBoundary = int64(405)
)

var (
	adminAddr       = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	protocolFeeAddr = access.MustGetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	govStakerAddr   = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())
	devOpsAddr      = access.MustGetAddress(prbac.ROLE_DEVOPS.String())

	adminRealm             = testing.NewUserRealm(adminAddr)
	stakerRealm            = testing.NewCodeRealm("gno.land/r/gnoswap/staker")
	govStakerRealm         = testing.NewCodeRealm("gno.land/r/gnoswap/gov/staker")
	devOpsHolderRealm      = testing.NewUserRealm(devOpsAddr)
	protocolFeeHolderRealm = testing.NewUserRealm(protocolFeeAddr)
	legacyImplementation   = testing.NewCodeRealm(protocolFeeLegacyPath)
	v1Implementation       = testing.NewCodeRealm(protocolFeeV1Path)
	preUpgradeFeeSnapshot  protocolFeeSnapshot
)

type protocolFeeSnapshot struct {
	devOpsPct, govStakerPct, accrualEpoch int64
	reservedTokens, pendingTokens         []string
	barAccruedGov, barAccruedDev          int64
	barDistributedGov, barDistributedDev  int64
	fooAccruedGov, fooAccruedDev          int64
	fooDistributedGov, fooDistributedDev  int64
	barBucketEpochs, barBucketAmounts     []int64
	fooBucketEpochs, fooBucketAmounts     []int64
	barFeeBalance, fooFeeBalance          int64
	barGovBalance, barDevOpsBalance       int64
	fooGovBalance, fooDevOpsBalance       int64
	barStakerBalance, fooStakerBalance    int64
}

func main(cur realm) {
	println("[SCENARIO] 1. Initialize the frozen legacy implementation")
	upgradeProtocolFee(cur, protocolFeeLegacyPath)
	println()

	println("[SCENARIO] 2. Collect and partly distribute real fees with legacy")
	seedLegacyFeeState(cur)
	captureAndAssertLegacySnapshot()
	println()

	println("[SCENARIO] 3. Upgrade to patched v1 and verify every snapshot")
	upgradeProtocolFee(cur, protocolFeeV1Path)
	assertSnapshotPreserved()
	println("[EXPECTED] allocations, history, reservations, epochs, buckets, percentages, and balances survived")
	println()

	println("[SCENARIO] 4. Pay preserved pending fees once, then continue accrual")
	settlePreservedPendingFees(cur)
	rollbackBeforeCounterRollover(cur)
	println()

	println("[SCENARIO] 5. Cross the signed lifetime-counter boundary with recycled BAR")
	crossCounterBoundaryWithRecycledBar(cur)
	println()
}

func upgradeProtocolFee(cur realm, packagePath string) {
	testing.SetRealm(adminRealm)
	protocolFee.UpgradeImpl(cross(cur), packagePath)
	ufmt.Printf("[EXPECTED] implementation: %s\n", protocolFee.GetImplementationPackagePath())
	uassert.Equal(t, packagePath, protocolFee.GetImplementationPackagePath())
}

func seedLegacyFeeState(cur realm) {
	testing.SetRealm(adminRealm)
	protocolFee.SetGovStakerPct(cross(cur), 7000)
	protocolFee.SetDevOpsPct(cross(cur), 3000)

	fundAndApproveFromAdmin(cur, legacyImplementation.Address(), 1000, 2000)
	addFeesAsStaker(cur, 1000, 2000)

	// BAR has real distribution history while FOO and the later BAR accrual
	// remain reserved for the post-upgrade settlement.
	testing.SetRealm(adminRealm)
	protocolFee.DistributeProtocolFeeByTokenPath(cross(cur), barPath)
	testing.SkipHeights(1)

	// The Gov/Staker consumer folds BAR's first epoch bucket before changing
	// epochs. FOO's epoch-0 bucket intentionally remains live across the upgrade.
	epochs, amounts := consumeBucketsAsGovStaker(cur, barPath)
	assertInt64Slice([]int64{0}, epochs)
	assertInt64Slice([]int64{700}, amounts)
	testing.SkipHeights(1)

	testing.SetRealm(govStakerRealm)
	uassert.Equal(t, int64(1), protocolFee.AdvanceAccrualEpoch(cross(cur)))
	testing.SkipHeights(1)

	fundAndApproveFromAdmin(cur, legacyImplementation.Address(), 300, 400)
	addFeesAsStaker(cur, 300, 400)
}

func captureAndAssertLegacySnapshot() {
	preUpgradeFeeSnapshot = takeFeeSnapshot()
	s := preUpgradeFeeSnapshot

	uassert.Equal(t, int64(3000), s.devOpsPct)
	uassert.Equal(t, int64(7000), s.govStakerPct)
	uassert.Equal(t, int64(1), s.accrualEpoch)
	assertStringSlice([]string{barPath, fooPath}, s.reservedTokens)
	uassert.Equal(t, 2, len(s.pendingTokens))
	uassert.True(t, containsString(s.pendingTokens, barPath))
	uassert.True(t, containsString(s.pendingTokens, fooPath))
	uassert.Equal(t, int64(910), s.barAccruedGov)
	uassert.Equal(t, int64(390), s.barAccruedDev)
	uassert.Equal(t, int64(700), s.barDistributedGov)
	uassert.Equal(t, int64(300), s.barDistributedDev)
	uassert.Equal(t, int64(1680), s.fooAccruedGov)
	uassert.Equal(t, int64(720), s.fooAccruedDev)
	uassert.Equal(t, int64(0), s.fooDistributedGov)
	uassert.Equal(t, int64(0), s.fooDistributedDev)
	assertInt64Slice([]int64{1}, s.barBucketEpochs)
	assertInt64Slice([]int64{210}, s.barBucketAmounts)
	assertInt64Slice([]int64{0, 1}, s.fooBucketEpochs)
	assertInt64Slice([]int64{1400, 280}, s.fooBucketAmounts)
	uassert.Equal(t, int64(300), s.barFeeBalance)
	uassert.Equal(t, int64(2400), s.fooFeeBalance)
	uassert.Equal(t, int64(300), s.barDevOpsBalance)
	uassert.Equal(t, int64(700), s.barGovBalance)
	uassert.Equal(t, int64(0), s.fooDevOpsBalance)
	uassert.Equal(t, int64(0), s.fooGovBalance)

	ufmt.Printf("[EXPECTED] split (devops / gov): %d %d\n", s.devOpsPct, s.govStakerPct)
	ufmt.Printf("[EXPECTED] BAR allocation (gov / devops): %d %d\n", s.barAccruedGov, s.barAccruedDev)
	ufmt.Printf("[EXPECTED] BAR distributed history (gov / devops): %d %d\n", s.barDistributedGov, s.barDistributedDev)
	ufmt.Printf("[EXPECTED] FOO allocation (gov / devops): %d %d\n", s.fooAccruedGov, s.fooAccruedDev)
	ufmt.Printf("[EXPECTED] reserved tokens: %d; pending accrual tokens: %d; epoch: %d\n", len(s.reservedTokens), len(s.pendingTokens), s.accrualEpoch)
	ufmt.Printf("[EXPECTED] BAR buckets: %d %d:%d\n", len(s.barBucketEpochs), s.barBucketEpochs[0], s.barBucketAmounts[0])
	ufmt.Printf("[EXPECTED] FOO buckets: %d %d:%d %d:%d\n", len(s.fooBucketEpochs), s.fooBucketEpochs[0], s.fooBucketAmounts[0], s.fooBucketEpochs[1], s.fooBucketAmounts[1])
	ufmt.Printf("[EXPECTED] protocol-fee balances (BAR / FOO): %d %d\n", s.barFeeBalance, s.fooFeeBalance)
}

func takeFeeSnapshot() protocolFeeSnapshot {
	barEpochs, barAmounts := protocolFee.GetAccrualBuckets(barPath, 0)
	fooEpochs, fooAmounts := protocolFee.GetAccrualBuckets(fooPath, 0)

	return protocolFeeSnapshot{
		devOpsPct:         protocolFee.GetDevOpsPct(),
		govStakerPct:      protocolFee.GetGovStakerPct(),
		accrualEpoch:      protocolFee.GetAccrualEpoch(),
		reservedTokens:    protocolFee.GetReservedTokens(),
		pendingTokens:     protocolFee.GetAccrualPendingTokens(),
		barAccruedGov:     protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath),
		barAccruedDev:     protocolFee.GetAccuTransferToDevOpsByTokenPath(barPath),
		barDistributedGov: protocolFee.GetActualDistributedToGovStakerByTokenPath(barPath),
		barDistributedDev: protocolFee.GetActualDistributedToDevOpsByTokenPath(barPath),
		fooAccruedGov:     protocolFee.GetAccuTransferToGovStakerByTokenPath(fooPath),
		fooAccruedDev:     protocolFee.GetAccuTransferToDevOpsByTokenPath(fooPath),
		fooDistributedGov: protocolFee.GetActualDistributedToGovStakerByTokenPath(fooPath),
		fooDistributedDev: protocolFee.GetActualDistributedToDevOpsByTokenPath(fooPath),
		barBucketEpochs:   barEpochs,
		barBucketAmounts:  barAmounts,
		fooBucketEpochs:   fooEpochs,
		fooBucketAmounts:  fooAmounts,
		barFeeBalance:     bar.BalanceOf(protocolFeeAddr),
		fooFeeBalance:     foo.BalanceOf(protocolFeeAddr),
		barGovBalance:     bar.BalanceOf(govStakerAddr),
		barDevOpsBalance:  bar.BalanceOf(devOpsAddr),
		fooGovBalance:     foo.BalanceOf(govStakerAddr),
		fooDevOpsBalance:  foo.BalanceOf(devOpsAddr),
		barStakerBalance:  bar.BalanceOf(stakerRealm.Address()),
		fooStakerBalance:  foo.BalanceOf(stakerRealm.Address()),
	}
}

func assertSnapshotPreserved() {
	want := preUpgradeFeeSnapshot
	got := takeFeeSnapshot()

	uassert.Equal(t, want.devOpsPct, got.devOpsPct)
	uassert.Equal(t, want.govStakerPct, got.govStakerPct)
	uassert.Equal(t, want.accrualEpoch, got.accrualEpoch)
	assertStringSlice(want.reservedTokens, got.reservedTokens)
	assertStringSlice(want.pendingTokens, got.pendingTokens)
	uassert.Equal(t, want.barAccruedGov, got.barAccruedGov)
	uassert.Equal(t, want.barAccruedDev, got.barAccruedDev)
	uassert.Equal(t, want.barDistributedGov, got.barDistributedGov)
	uassert.Equal(t, want.barDistributedDev, got.barDistributedDev)
	uassert.Equal(t, want.fooAccruedGov, got.fooAccruedGov)
	uassert.Equal(t, want.fooAccruedDev, got.fooAccruedDev)
	uassert.Equal(t, want.fooDistributedGov, got.fooDistributedGov)
	uassert.Equal(t, want.fooDistributedDev, got.fooDistributedDev)
	assertInt64Slice(want.barBucketEpochs, got.barBucketEpochs)
	assertInt64Slice(want.barBucketAmounts, got.barBucketAmounts)
	assertInt64Slice(want.fooBucketEpochs, got.fooBucketEpochs)
	assertInt64Slice(want.fooBucketAmounts, got.fooBucketAmounts)
	uassert.Equal(t, want.barFeeBalance, got.barFeeBalance)
	uassert.Equal(t, want.fooFeeBalance, got.fooFeeBalance)
	uassert.Equal(t, want.barGovBalance, got.barGovBalance)
	uassert.Equal(t, want.barDevOpsBalance, got.barDevOpsBalance)
	uassert.Equal(t, want.fooGovBalance, got.fooGovBalance)
	uassert.Equal(t, want.fooDevOpsBalance, got.fooDevOpsBalance)
	uassert.Equal(t, want.barStakerBalance, got.barStakerBalance)
	uassert.Equal(t, want.fooStakerBalance, got.fooStakerBalance)
}

func settlePreservedPendingFees(cur realm) {
	testing.SetRealm(adminRealm)
	protocolFee.DistributeProtocolFee(cross(cur))
	testing.SkipHeights(1)

	uassert.Equal(t, int64(0), bar.BalanceOf(protocolFeeAddr))
	uassert.Equal(t, int64(0), foo.BalanceOf(protocolFeeAddr))
	uassert.Equal(t, int64(390), protocolFee.GetActualDistributedToDevOpsByTokenPath(barPath))
	uassert.Equal(t, int64(910), protocolFee.GetActualDistributedToGovStakerByTokenPath(barPath))
	uassert.Equal(t, int64(720), protocolFee.GetActualDistributedToDevOpsByTokenPath(fooPath))
	uassert.Equal(t, int64(1680), protocolFee.GetActualDistributedToGovStakerByTokenPath(fooPath))
	uassert.Equal(t, int64(390), bar.BalanceOf(devOpsAddr))
	uassert.Equal(t, int64(910), bar.BalanceOf(govStakerAddr))
	uassert.Equal(t, int64(720), foo.BalanceOf(devOpsAddr))
	uassert.Equal(t, int64(1680), foo.BalanceOf(govStakerAddr))
	uassert.Equal(t, 0, len(protocolFee.GetReservedTokens()))

	// A second public distribution call sees no reserved fees and pays nothing.
	protocolFee.DistributeProtocolFee(cross(cur))
	testing.SkipHeights(1)
	uassert.Equal(t, int64(390), protocolFee.GetActualDistributedToDevOpsByTokenPath(barPath))
	uassert.Equal(t, int64(910), protocolFee.GetActualDistributedToGovStakerByTokenPath(barPath))
	uassert.Equal(t, int64(720), protocolFee.GetActualDistributedToDevOpsByTokenPath(fooPath))
	uassert.Equal(t, int64(1680), protocolFee.GetActualDistributedToGovStakerByTokenPath(fooPath))
	uassert.Equal(t, int64(390), bar.BalanceOf(devOpsAddr))
	uassert.Equal(t, int64(910), bar.BalanceOf(govStakerAddr))
	uassert.Equal(t, int64(720), foo.BalanceOf(devOpsAddr))
	uassert.Equal(t, int64(1680), foo.BalanceOf(govStakerAddr))
	println("[EXPECTED] BAR and FOO pending balances paid once; repeating distribution made no second payment")
}

func rollbackBeforeCounterRollover(cur realm) {
	println("[SCENARIO] 4a. Roll back to legacy before counters approach the signed boundary")
	upgradeProtocolFee(cur, protocolFeeLegacyPath)
	fundAndApproveFromAdmin(cur, legacyImplementation.Address(), 50, 0)
	addFeesAsStaker(cur, 50, 0)

	testing.SetRealm(adminRealm)
	protocolFee.DistributeProtocolFeeByTokenPath(cross(cur), barPath)
	testing.SkipHeights(1)
	uassert.Equal(t, int64(405), protocolFee.GetActualDistributedToDevOpsByTokenPath(barPath))
	uassert.Equal(t, int64(945), protocolFee.GetActualDistributedToGovStakerByTokenPath(barPath))
	uassert.Equal(t, int64(0), bar.BalanceOf(protocolFeeAddr))
	uassert.Equal(t, int64(405), bar.BalanceOf(devOpsAddr))
	uassert.Equal(t, int64(945), bar.BalanceOf(govStakerAddr))
	uassert.Equal(t, 0, len(protocolFee.GetReservedTokens()))
	println("[EXPECTED] legacy rollback collected and paid 50 BAR without counter rollover")

	// Empty old reward buckets before building the near-MaxInt64 fee; the fee
	// allocation buckets remain nonnegative, representable token amounts.
	epochs, amounts := consumeBucketsAsGovStaker(cur, barPath)
	assertInt64Slice([]int64{1}, epochs)
	assertInt64Slice([]int64{245}, amounts)
	testing.SkipHeights(1)
	epochs, amounts = consumeBucketsAsGovStaker(cur, fooPath)
	assertInt64Slice([]int64{0, 1}, epochs)
	assertInt64Slice([]int64{1400, 280}, amounts)
	testing.SkipHeights(1)
	uassert.Equal(t, 0, len(protocolFee.GetAccrualPendingTokens()))

	upgradeProtocolFee(cur, protocolFeeV1Path)
	uassert.Equal(t, int64(1), protocolFee.GetAccrualEpoch())
	uassert.Equal(t, int64(945), protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath))
	uassert.Equal(t, int64(405), protocolFee.GetAccuTransferToDevOpsByTokenPath(barPath))
	println("[EXPECTED] patched v1 restored after the pre-rollover legacy rollback")
}

func crossCounterBoundaryWithRecycledBar(cur realm) {
	testing.SetRealm(adminRealm)
	protocolFee.SetDevOpsPct(cross(cur), 0)
	uassert.Equal(t, int64(0), protocolFee.GetDevOpsPct())
	ufmt.Printf("[EXPECTED] boundary-test split (devops / gov): %d %d\n", protocolFee.GetDevOpsPct(), protocolFee.GetGovStakerPct())

	// The test token starts with a small admin supply. Mint only after checking
	// the real current supply, then recycle the existing BAR balances to admin
	// so this is backed by token transfers rather than fabricated fee totals.
	bar.Mint(cross(cur), adminAddr, maxInt64-bar.TotalSupply())
	recycleBarToAdmin(cur, stakerRealm, stakerRealm.Address())
	recycleBarToAdmin(cur, protocolFeeHolderRealm, protocolFeeAddr)
	recycleBarToAdmin(cur, devOpsHolderRealm, devOpsAddr)
	recycleBarToAdmin(cur, govStakerRealm, govStakerAddr)
	uassert.Equal(t, maxInt64, bar.BalanceOf(adminAddr))
	uassert.Equal(t, maxInt64, bar.TotalSupply())

	uassert.Equal(t, barGovBeforeBoundary, protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath))
	uassert.Equal(t, barDevOpsBeforeBoundary, protocolFee.GetAccuTransferToDevOpsByTokenPath(barPath))
	topUp := maxInt64 - barGovBeforeBoundary
	fundAndApproveFromAdmin(cur, v1Implementation.Address(), topUp, 0)
	addFeesAsStaker(cur, topUp, 0)
	uassert.Equal(t, maxInt64, protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath))
	uassert.Equal(t, barGovBeforeBoundary, protocolFee.GetActualDistributedToGovStakerByTokenPath(barPath))
	uassert.Equal(t, topUp, bar.BalanceOf(protocolFeeAddr))

	testing.SetRealm(adminRealm)
	protocolFee.DistributeProtocolFeeByTokenPath(cross(cur), barPath)
	testing.SkipHeights(1)
	uassert.Equal(t, maxInt64, protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath))
	uassert.Equal(t, maxInt64, protocolFee.GetActualDistributedToGovStakerByTokenPath(barPath))
	uassert.Equal(t, int64(0), bar.BalanceOf(protocolFeeAddr))
	uassert.Equal(t, topUp, bar.BalanceOf(govStakerAddr))

	// Remove the large, now-settled epoch bucket before the next accrual so the
	// pending bucket itself stays a small, valid amount while lifetime totals wrap.
	epochs, amounts := consumeBucketsAsGovStaker(cur, barPath)
	assertInt64Slice([]int64{1}, epochs)
	assertInt64Slice([]int64{topUp}, amounts)
	testing.SkipHeights(1)

	// Recycle 1,001 already-paid BAR from Gov/Staker to the legitimate fee
	// collector, then collect it through the public proxy after the counter is at
	// MaxInt64. The checked legacy implementation is intentionally never selected
	// again after lifetime counters cross the signed boundary.
	testing.SetRealm(govStakerRealm)
	bar.Transfer(cross(cur), stakerRealm.Address(), wrapFeeAmount)
	testing.SetRealm(stakerRealm)
	bar.Approve(cross(cur), protocolFeeAddr, wrapFeeAmount)
	bar.Approve(cross(cur), v1Implementation.Address(), wrapFeeAmount)
	if err := protocolFee.AddToProtocolFee(cross(cur), barPath, wrapFeeAmount); err != nil {
		panic(err)
	}
	testing.SkipHeights(1)

	uassert.Equal(t, wrappedAfterWrapFee, protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath))
	uassert.Equal(t, maxInt64, protocolFee.GetActualDistributedToGovStakerByTokenPath(barPath))
	uassert.Equal(t, wrapFeeAmount, bar.BalanceOf(protocolFeeAddr))
	uassert.Equal(t, topUp-wrapFeeAmount, bar.BalanceOf(govStakerAddr))
	epochs, amounts = protocolFee.GetAccrualBuckets(barPath, 0)
	assertInt64Slice([]int64{1}, epochs)
	assertInt64Slice([]int64{wrapFeeAmount}, amounts)

	testing.SetRealm(adminRealm)
	protocolFee.DistributeProtocolFeeByTokenPath(cross(cur), barPath)
	testing.SkipHeights(1)
	uassert.Equal(t, wrappedAfterWrapFee, protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath))
	uassert.Equal(t, wrappedAfterWrapFee, protocolFee.GetActualDistributedToGovStakerByTokenPath(barPath))
	uassert.Equal(t, int64(0), bar.BalanceOf(protocolFeeAddr))
	uassert.Equal(t, topUp, bar.BalanceOf(govStakerAddr))
	uassert.Equal(t, 0, len(protocolFee.GetReservedTokens()))
	ufmt.Printf("[EXPECTED] wrapped BAR gov allocation / distribution history: %d %d\n",
		protocolFee.GetAccuTransferToGovStakerByTokenPath(barPath),
		protocolFee.GetActualDistributedToGovStakerByTokenPath(barPath))
	println("[EXPECTED] recycled 1,001 BAR paid after rollover; pending and reserved balances are zero")
}

func fundAndApproveFromAdmin(cur realm, implAddr address, barAmount, fooAmount int64) {
	testing.SetRealm(adminRealm)
	if barAmount > 0 {
		bar.Transfer(cross(cur), stakerRealm.Address(), barAmount)
	}
	if fooAmount > 0 {
		foo.Transfer(cross(cur), stakerRealm.Address(), fooAmount)
	}

	testing.SetRealm(stakerRealm)
	if barAmount > 0 {
		bar.Approve(cross(cur), protocolFeeAddr, barAmount)
		bar.Approve(cross(cur), implAddr, barAmount)
	}
	if fooAmount > 0 {
		foo.Approve(cross(cur), protocolFeeAddr, fooAmount)
		foo.Approve(cross(cur), implAddr, fooAmount)
	}
}

func addFeesAsStaker(cur realm, barAmount, fooAmount int64) {
	testing.SetRealm(stakerRealm)
	if barAmount > 0 {
		if err := protocolFee.AddToProtocolFee(cross(cur), barPath, barAmount); err != nil {
			panic(err)
		}
	}
	if fooAmount > 0 {
		if err := protocolFee.AddToProtocolFee(cross(cur), fooPath, fooAmount); err != nil {
			panic(err)
		}
	}
	testing.SkipHeights(1)
}

func consumeBucketsAsGovStaker(cur realm, tokenPath string) ([]int64, []int64) {
	testing.SetRealm(govStakerRealm)
	return protocolFee.ConsumeAccrualBuckets(cross(cur), tokenPath, 0)
}

func recycleBarToAdmin(cur realm, holderRealm runtime.Realm, holder address) {
	amount := bar.BalanceOf(holder)
	if amount == 0 {
		return
	}
	testing.SetRealm(holderRealm)
	bar.Transfer(cross(cur), adminAddr, amount)
}

func assertInt64Slice(want, got []int64) {
	uassert.Equal(t, len(want), len(got))
	for i := range want {
		uassert.Equal(t, want[i], got[i])
	}
}

func assertStringSlice(want, got []string) {
	uassert.Equal(t, len(want), len(got))
	for i := range want {
		uassert.Equal(t, want[i], got[i])
	}
}

func containsString(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}

// Output:
// [SCENARIO] 1. Initialize the frozen legacy implementation
// [EXPECTED] implementation: gno.land/r/gnoswap/protocol_fee/legacy
//
// [SCENARIO] 2. Collect and partly distribute real fees with legacy
// [EXPECTED] split (devops / gov): 3000 7000
// [EXPECTED] BAR allocation (gov / devops): 910 390
// [EXPECTED] BAR distributed history (gov / devops): 700 300
// [EXPECTED] FOO allocation (gov / devops): 1680 720
// [EXPECTED] reserved tokens: 2; pending accrual tokens: 2; epoch: 1
// [EXPECTED] BAR buckets: 1 1:210
// [EXPECTED] FOO buckets: 2 0:1400 1:280
// [EXPECTED] protocol-fee balances (BAR / FOO): 300 2400
//
// [SCENARIO] 3. Upgrade to patched v1 and verify every snapshot
// [EXPECTED] implementation: gno.land/r/gnoswap/protocol_fee/v1
// [EXPECTED] allocations, history, reservations, epochs, buckets, percentages, and balances survived
//
// [SCENARIO] 4. Pay preserved pending fees once, then continue accrual
// [EXPECTED] BAR and FOO pending balances paid once; repeating distribution made no second payment
// [SCENARIO] 4a. Roll back to legacy before counters approach the signed boundary
// [EXPECTED] implementation: gno.land/r/gnoswap/protocol_fee/legacy
// [EXPECTED] legacy rollback collected and paid 50 BAR without counter rollover
// [EXPECTED] implementation: gno.land/r/gnoswap/protocol_fee/v1
// [EXPECTED] patched v1 restored after the pre-rollover legacy rollback
//
// [SCENARIO] 5. Cross the signed lifetime-counter boundary with recycled BAR
// [EXPECTED] boundary-test split (devops / gov): 0 10000
// [EXPECTED] wrapped BAR gov allocation / distribution history: -9223372036854774808 -9223372036854774808
// [EXPECTED] recycled 1,001 BAR paid after rollover; pending and reserved balances are zero

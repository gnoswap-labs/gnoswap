// Tests for the ledger-level external-reward delivery guard (audit finding #4)
// and for the reward-token deny switch.
//
// The guard's premise, pinned by TestGrc20MintOverflowGuard below: grc20's Mint
// refuses amounts past MaxInt64 - totalSupply and every ledger operation
// conserves sum(balances) == totalSupply, so a recipient-balance overflow is
// unreachable and the only reachable transfer failure is the sender balance
// falling short (issuer burn, accounting drift). The guard therefore checks the
// staker realm's live balance against what both delivery legs will move —
// including carried-over pending protocol fees of the same token — and skips
// the delivery instead of letting SafeGRC20Transfer panic while staked; on an
// exit checkpoint it aborts explicitly so the fixed claim is never waived.
//
// The file name sorts after staker_collect_reward_split_test.gno; like the rest
// of this package's tests, every test re-initializes the mock instance through
// initStakerTest.
package staker

import (
	"testing"
	"time"

	prabc "gno.land/p/gnoswap/rbac/v1"
	"gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt/v1"
	pl "gno.land/r/gnoswap/pool"
	sr "gno.land/r/gnoswap/staker"

	"gno.land/r/onbloc/bar"
)

func mockInstanceSetDeniedRewardToken(cur realm, tokenPath string, denied bool) {
	getMockInstance().SetDeniedRewardToken(0, cur, tokenPath, denied)
}

// setupGuardDeposit stakes a position in a bar/baz pool carrying one external
// incentive that pays BAR, lets it accrue, and returns the position and
// incentive ids. Mirrors setupSplitCollectDeposit with a single incentive and a
// configurable unstaking fee.
func setupGuardDeposit(cur realm, t *testing.T, unstakingFee uint64) (uint64, string) {
	t.Helper()

	initStakerTest(cur, t)

	poolPath := pl.GetPoolPath(barPath, bazPath, fee3000)

	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross(cur), 0)
	createDefaultInitialPoolForStakerTest(cur, t)
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)

	testing.SetRealm(adminRealm)
	CreatePool(cur, barPath, bazPath, fee3000, "79228162514264337593543950336", adminAddr)
	mockInstanceSetPoolTier(cross(cur), poolPath, 1)

	govAddr := access.MustGetAddress(prabc.ROLE_GOVERNANCE.String())
	testing.SetRealm(testing.NewUserRealm(govAddr))
	mockInstanceSetUnstakingFee(cross(cur), unstakingFee)

	TokenFaucet(cur, t, barPath, addr01)
	TokenFaucet(cur, t, bazPath, addr01)
	TokenFaucet(cur, t, gnsPath, addr01)

	testing.SetRealm(testing.NewUserRealm(addr01))
	TokenApprove(cur, t, barPath, addr01, poolAddr, maxApprove)
	TokenApprove(cur, t, bazPath, addr01, poolAddr, maxApprove)

	positionId, _, _, _ := MintPosition(
		cur,
		t,
		barPath,
		bazPath,
		fee3000,
		-18000,
		18000,
		"1000000",
		"1000000",
		"0",
		"0",
		max_timeout,
		addr01,
		addr01,
	)
	mockNFTMint(cur, addr01, positionId)
	mockNFTApprove(cur, stakerAddr, positionId)

	testing.SetRealm(testing.NewUserRealm(addr01))
	sr.StakeToken(cross(cur), positionId, "")

	testing.SetRealm(testing.NewUserRealm(addr01))
	gnsApprove(cur, t, addr01, stakerAddr, maxApprove)

	startTimestamp := time.Now().AddDate(0, 0, 2).Truncate(24 * time.Hour).Unix()
	CreateExternalIncentiveAsAdmin(
		cur, t,
		poolPath,
		barPath,
		rewardMinimumAmount,
		startTimestamp,
		startTimestamp+incentiveDuration,
	)

	// Move to the incentive start (a test block is 5 seconds), then let the
	// emission and the external reward accrue.
	testing.SkipHeights((startTimestamp - time.Now().Unix()) / 5)
	testing.SkipHeights(3600)

	barIncentiveId := ""
	getMockInstance().getExternalIncentives().tree.Iterate("", "", func(key string, value any) bool {
		barIncentiveId = key
		return true
	})
	if barIncentiveId == "" {
		t.Fatal("expected the external incentive to be created")
	}

	return positionId, barIncentiveId
}

// burnStakerBar removes the staker realm's entire BAR balance, the issuer-burn
// trigger of audit finding #4.
func burnStakerBar(cur realm, t *testing.T) int64 {
	t.Helper()

	burned := bar.BalanceOf(stakerAddr)
	uassert.True(t, burned > 0)

	testing.SetRealm(adminRealm) // bar's ownable owner is the admin address
	bar.Burn(cross(cur), stakerAddr, burned)
	uassert.Equal(t, int64(0), bar.BalanceOf(stakerAddr))

	return burned
}

// An issuer burning the staker realm's balance of the reward token must not
// lock the position: UnStakeToken writes its checkpoint without touching the
// token. The permissionless collect that settles the checkpoint aborts instead
// of forfeiting the fixed claim, and once the balance is restored the same
// collect pays the owner, clears the checkpoint and frees the position to
// stake again. The quote getters follow the checkpoint the whole way.
func TestExternalRewardGuard_IssuerBurnDoesNotLockCheckpoint(cur realm, t *testing.T) {
	positionId, barIncentiveId := setupGuardDeposit(cur, t, 0)

	collectableStaked, err := sr.CollectableExternalIncentiveReward(positionId, barIncentiveId)
	uassert.NoError(t, err)
	uassert.True(t, collectableStaked > 0)

	testing.SetRealm(testing.NewUserRealm(addr01))
	sr.UnStakeToken(cross(cur), positionId)

	uassert.False(t, getMockInstance().getDeposits().Has(positionId))
	uassert.True(t, sr.HasUnstakedPosition(positionId))
	uassert.Equal(t, int64(1), sr.GetUncollectedIncentiveCount(barIncentiveId))

	// The quotes resolve the checkpoint: same block, so the same amount as while staked.
	collectableCheckpoint, err := sr.CollectableExternalIncentiveReward(positionId, barIncentiveId)
	uassert.NoError(t, err)
	uassert.Equal(t, collectableStaked, collectableCheckpoint)
	_, err = sr.CollectableEmissionReward(positionId)
	uassert.NoError(t, err)

	burned := burnStakerBar(cur, t)

	incentive := getMockInstance().getExternalIncentives().get(barIncentiveId)
	incentiveRewardBefore := incentive.RewardAmount()
	ownerBarBefore := bar.BalanceOf(addr01)

	// A third party cannot settle the checkpoint while the balance is short: the collect aborts
	// before any bookkeeping, so nothing is deducted and the claim stays owed.
	testing.SetRealm(testing.NewUserRealm(addr02))
	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-027]", func() {
		sr.CollectExternalIncentiveReward(cross(cur), positionId, barIncentiveId)
	})

	uassert.True(t, sr.HasUnstakedPosition(positionId))
	uassert.Equal(t, int64(1), sr.GetUncollectedIncentiveCount(barIncentiveId))
	incentive = getMockInstance().getExternalIncentives().get(barIncentiveId)
	uassert.Equal(t, incentiveRewardBefore, incentive.RewardAmount())

	// Restoring the balance lets the same permissionless collect pay the owner.
	testing.SetRealm(adminRealm)
	bar.Mint(cross(cur), stakerAddr, burned)

	testing.SetRealm(testing.NewUserRealm(addr02))
	sr.CollectReward(cross(cur), positionId)

	uassert.Equal(t, ownerBarBefore+collectableCheckpoint, bar.BalanceOf(addr01))
	uassert.False(t, sr.HasUnstakedPosition(positionId))
	uassert.Equal(t, int64(0), sr.GetUncollectedIncentiveCount(barIncentiveId))

	// The position is free to stake again.
	mockNFTApprove(cur, stakerAddr, positionId)
	testing.SetRealm(testing.NewUserRealm(addr01))
	sr.StakeToken(cross(cur), positionId, "")
	uassert.True(t, getMockInstance().getDeposits().Has(positionId))
}

// While the position stays staked, a guard skip is a deferral, not a loss: the
// per-incentive collect cursor is left untouched, and restoring the balance
// makes the very same reward collectible again.
func TestExternalRewardGuard_DeferralWhileStaked(cur realm, t *testing.T) {
	positionId, barIncentiveId := setupGuardDeposit(cur, t, 0)

	burned := burnStakerBar(cur, t)

	lastCollectBefore, err := sr.GetDepositExternalRewardLastCollectTimestamp(positionId, barIncentiveId)
	uassert.NoError(t, err)
	ownerBarBefore := bar.BalanceOf(addr01)

	testing.SetRealm(testing.NewUserRealm(addr01))
	sr.CollectReward(cross(cur), positionId)

	// Skipped: nothing paid, cursor not advanced.
	uassert.Equal(t, ownerBarBefore, bar.BalanceOf(addr01))
	lastCollectAfterSkip, err := sr.GetDepositExternalRewardLastCollectTimestamp(positionId, barIncentiveId)
	uassert.NoError(t, err)
	uassert.Equal(t, lastCollectBefore, lastCollectAfterSkip)

	// Anyone restoring the balance (here the issuer re-mints) makes the same
	// window collectible again.
	testing.SetRealm(adminRealm)
	bar.Mint(cross(cur), stakerAddr, burned)

	collectable, err := sr.CollectableExternalIncentiveReward(positionId, barIncentiveId)
	uassert.NoError(t, err)
	uassert.True(t, collectable > 0)

	testing.SetRealm(testing.NewUserRealm(addr01))
	sr.CollectReward(cross(cur), positionId)

	uassert.True(t, bar.BalanceOf(addr01) > ownerBarBefore)
	lastCollectAfterPay, err := sr.GetDepositExternalRewardLastCollectTimestamp(positionId, barIncentiveId)
	uassert.NoError(t, err)
	uassert.True(t, lastCollectAfterPay > lastCollectBefore)
}

// The fee leg settles carried-over pending protocol fees of the same token
// together with the current fee, so the guard must demand balance for the
// pending amount too: a balance that would cover the reward alone, but not
// reward+pending, must still skip.
func TestExternalRewardGuard_PendingFeeCoupling(cur realm, t *testing.T) {
	positionId, barIncentiveId := setupGuardDeposit(cur, t, 100) // 1% unstaking fee

	// Collect once with the protocol_fee op halted: the fee leg parks its cut
	// as a pending protocol fee instead of transferring it.
	testing.SetRealm(adminRealm)
	halt.SetOperationStatus(cross(cur), halt.OpTypeProtocolFee, true)

	testing.SetRealm(testing.NewUserRealm(addr01))
	sr.CollectReward(cross(cur), positionId)

	testing.SetRealm(adminRealm)
	halt.SetOperationStatus(cross(cur), halt.OpTypeProtocolFee, false)

	pending := getMockInstance().store.GetPendingProtocolFees()[barPath]
	uassert.True(t, pending > 0)

	// Let a fresh reward accrue, then shrink the staker balance below the
	// pending amount alone — necessarily below reward+pending as well.
	testing.SkipHeights(3600)

	testing.SetRealm(adminRealm)
	stakerBar := bar.BalanceOf(stakerAddr)
	uassert.True(t, stakerBar >= pending)
	bar.Burn(cross(cur), stakerAddr, stakerBar-pending+1)

	ownerBarBefore := bar.BalanceOf(addr01)
	lastCollectBefore, err := sr.GetDepositExternalRewardLastCollectTimestamp(positionId, barIncentiveId)
	uassert.NoError(t, err)

	testing.SetRealm(testing.NewUserRealm(addr01))
	sr.CollectReward(cross(cur), positionId)

	uassert.Equal(t, ownerBarBefore, bar.BalanceOf(addr01))
	lastCollectAfterSkip, err := sr.GetDepositExternalRewardLastCollectTimestamp(positionId, barIncentiveId)
	uassert.NoError(t, err)
	uassert.Equal(t, lastCollectBefore, lastCollectAfterSkip)

	// Restoring the balance lets the collect pay the reward AND flush the
	// pending fee to the protocol_fee realm.
	testing.SetRealm(adminRealm)
	bar.Mint(cross(cur), stakerAddr, stakerBar)

	protocolFeeAddr := access.MustGetAddress(prabc.ROLE_PROTOCOL_FEE.String())
	protocolFeeBarBefore := bar.BalanceOf(protocolFeeAddr)

	testing.SetRealm(testing.NewUserRealm(addr01))
	sr.CollectReward(cross(cur), positionId)

	uassert.True(t, bar.BalanceOf(addr01) > ownerBarBefore)
	uassert.True(t, bar.BalanceOf(protocolFeeAddr) >= protocolFeeBarBefore+pending)
	uassert.Equal(t, int64(0), getMockInstance().store.GetPendingProtocolFees()[barPath])
}

// Pins the invariant the guard's derivation rests on: grc20 Mint refuses any
// amount past MaxInt64 - totalSupply, so sum(balances) == totalSupply can never
// exceed MaxInt64 and a recipient-balance overflow in Transfer/TransferFrom is
// unreachable. If this test ever fails, the delivery guard must be re-derived
// (see docs/staker.md).
func TestGrc20MintOverflowGuard_PinsSupplyInvariant(cur realm, t *testing.T) {
	const maxInt64 = int64(9223372036854775807)

	supplyBefore := bar.TotalSupply()
	headroom := maxInt64 - supplyBefore

	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(t, cur, "mint overflow", func() {
		bar.Mint(cross(cur), addr01, headroom+1)
	})

	uassert.Equal(t, supplyBefore, bar.TotalSupply())
}

// The deny switch blocks NEW incentive creation for a pair token, is reversible,
// leaves already-created incentives collectible, protects the default protocol
// tokens, and is admin/governance-only.
func TestSetDeniedRewardToken_StopSwitch(cur realm, t *testing.T) {
	positionId, barIncentiveId := setupGuardDeposit(cur, t, 0)
	poolPath := pl.GetPoolPath(barPath, bazPath, fee3000)

	// Deny BAZ: a new BAZ incentive is refused even though BAZ is a pair token.
	// (BAZ rather than BAR, because the pool already carries an unfinished BAR
	// incentive and one token can only carry one unfinished incentive at a time.)
	testing.SetRealm(adminRealm)
	mockInstanceSetDeniedRewardToken(cross(cur), bazPath, true)

	startTimestamp := time.Now().AddDate(0, 0, 3).Truncate(24 * time.Hour).Unix()
	TokenApprove(cur, t, bazPath, adminAddr, stakerAddr, maxApprove)
	TokenApprove(cur, t, gnsPath, adminAddr, stakerAddr, maxApprove)
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(
		t, cur,
		"[GNOSWAP-STAKER-025] denied reward token || tokenPath(gno.land/r/onbloc/baz.BAZ) is denied as an external reward token",
		func() {
			mockInstanceCreateExternalIncentive(cross(cur), poolPath, bazPath, rewardMinimumAmount, startTimestamp, startTimestamp+incentiveDuration)
		},
	)

	// The existing BAR incentive keeps collecting: denial gates creation only.
	ownerBarBefore := bar.BalanceOf(addr01)
	testing.SetRealm(testing.NewUserRealm(addr01))
	sr.CollectReward(cross(cur), positionId)
	uassert.True(t, bar.BalanceOf(addr01) > ownerBarBefore)
	_ = barIncentiveId

	// Un-deny: creation works again.
	testing.SetRealm(adminRealm)
	mockInstanceSetDeniedRewardToken(cross(cur), bazPath, false)
	CreateExternalIncentiveAsAdmin(cur, t, poolPath, bazPath, rewardMinimumAmount, startTimestamp, startTimestamp+incentiveDuration)

	// Default protocol tokens cannot be denied.
	testing.SetRealm(adminRealm)
	uassert.AbortsWithMessage(
		t, cur,
		"[GNOSWAP-STAKER-026] cannot deny default token: cannot deny default token(gno.land/r/gnoswap/gns.GNS)",
		func() {
			mockInstanceSetDeniedRewardToken(cross(cur), gnsPath, true)
		},
	)

	// Only the admin or governance may flip the flag.
	testing.SetRealm(testing.NewUserRealm(addr01))
	uassert.AbortsContains(t, cur, "is not admin or governance", func() {
		mockInstanceSetDeniedRewardToken(cross(cur), bazPath, true)
	})
}

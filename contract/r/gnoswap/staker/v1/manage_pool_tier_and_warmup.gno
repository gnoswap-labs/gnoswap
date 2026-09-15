package staker

import (
	"chain"
	"chain/runtime"
	"time"

	"gno.land/p/gnoswap/utils"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
	sr "gno.land/r/gnoswap/staker"
)

const (
	NOT_EMISSION_TARGET_TIER uint64 = 0
)

// SetPoolTier assigns a tier level to a pool for internal GNS emission rewards.
// Only admin or governance can call this function.
//
// Parameters:
//   - _: Noncrossing implementation-call discriminator; pass 0.
//   - rlm: Current realm context forwarded unchanged by the staker proxy.
//   - poolPath: Existing pool path whose internal GNS emission tier is being assigned.
//   - tier: Emission tier to assign; valid values are below AllTierCount, including 0 for no emission target.
func (s *stakerV1) SetPoolTier(_ int, rlm realm, poolPath string, tier uint64) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedStaker()

	caller := rlm.Previous().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsPoolExists(s, poolPath)
	assertIsValidPoolTier(tier)

	// If the tier is already set, do nothing
	poolTier := s.getPoolTier()
	previousTier := poolTier.CurrentTier(poolPath)
	if previousTier == tier {
		return
	}

	currentTime := time.Now().Unix()
	rewardPerSecond, tierRewards := s.setPoolTier(0, rlm, poolPath, tier, currentTime)

	previousRealm := rlm.Previous()
	emitSetPoolTier(
		previousRealm.Address().String(),
		previousRealm.PkgPath(),
		poolPath,
		tier,
		rewardPerSecond,
		tierRewards,
		poolTier.counts,
		currentTime,
	)
}

// ChangePoolTier modifies the tier level of an existing pool.
// Only admin or governance can call this function.
//
// Parameters:
//   - _: Noncrossing implementation-call discriminator; pass 0.
//   - rlm: Current realm context forwarded unchanged by the staker proxy.
//   - poolPath: Existing pool path whose emission tier is being changed.
//   - tier: Replacement emission tier; values at or above AllTierCount are rejected.
func (s *stakerV1) ChangePoolTier(_ int, rlm realm, poolPath string, tier uint64) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedStaker()

	previousRealm := rlm.Previous()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsPoolExists(s, poolPath)
	assertIsValidPoolTier(tier)

	poolTier := s.getPoolTier()

	// If the tier is already set, do nothing
	previousTier := poolTier.CurrentTier(poolPath)
	if previousTier == tier {
		return
	}

	currentTime := time.Now().Unix()
	previousTier, newTier, rewardPerSecond, tierRewards := s.changePoolTier(0, rlm, poolPath, tier, currentTime)

	chain.Emit(
		"ChangePoolTier",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", poolPath,
		"prevTier", utils.FormatUint(previousTier),
		"newTier", utils.FormatUint(newTier),
		"rewardPerSecond", utils.FormatInt(rewardPerSecond),
		"tier1RewardPerSecond", utils.FormatInt(tierRewards[Tier1]),
		"tier2RewardPerSecond", utils.FormatInt(tierRewards[Tier2]),
		"tier3RewardPerSecond", utils.FormatInt(tierRewards[Tier3]),
		"tier1Count", utils.FormatUint(poolTier.counts[Tier1]),
		"tier2Count", utils.FormatUint(poolTier.counts[Tier2]),
		"tier3Count", utils.FormatUint(poolTier.counts[Tier3]),
		"currentTime", utils.FormatInt(currentTime),
		"currentHeight", utils.FormatInt(runtime.ChainHeight()),
	)
}

// RemovePoolTier removes a pool from internal GNS emission rewards.
// Only admin or governance can call this function.
//
// Parameters:
//   - _: Noncrossing implementation-call discriminator; pass 0.
//   - rlm: Current realm context forwarded unchanged by the staker proxy.
//   - poolPath: Existing pool path to remove from the emission-tier accounting.
func (s *stakerV1) RemovePoolTier(_ int, rlm realm, poolPath string) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedStaker()

	previousRealm := rlm.Previous()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsPoolExists(s, poolPath)

	poolTier := s.getPoolTier()

	// If the tier is already set, do nothing
	previousTier := poolTier.CurrentTier(poolPath)
	if previousTier == NOT_EMISSION_TARGET_TIER {
		return
	}

	currentTime := time.Now().Unix()
	rewardPerSecond, tierRewards := s.removePoolTier(0, rlm, poolPath, currentTime)

	chain.Emit(
		"RemovePoolTier",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", poolPath,
		"rewardPerSecond", utils.FormatInt(rewardPerSecond),
		"tier1RewardPerSecond", utils.FormatInt(tierRewards[Tier1]),
		"tier2RewardPerSecond", utils.FormatInt(tierRewards[Tier2]),
		"tier3RewardPerSecond", utils.FormatInt(tierRewards[Tier3]),
		"tier1Count", utils.FormatUint(poolTier.counts[Tier1]),
		"tier2Count", utils.FormatUint(poolTier.counts[Tier2]),
		"tier3Count", utils.FormatUint(poolTier.counts[Tier3]),
		"currentTime", utils.FormatInt(currentTime),
		"currentHeight", utils.FormatInt(runtime.ChainHeight()),
	)
}

// SetWarmUp configures the duration for the warm-up tier selected by its fixed ratio.
// Finite tiers are capped at 365 days; the final 100% tier must remain math.MaxInt64.
// Only admin or governance can call this function.
//
// Parameters:
//   - _: Noncrossing implementation-call discriminator; pass 0.
//   - rlm: Current realm context forwarded unchanged by the staker proxy.
//   - pct: Warm-up tier percentage selecting one of the configured 30%, 50%, 70%, or 100% templates.
//   - timeDuration: Warm-up duration in seconds; finite tiers are capped at 365 days while the 100% tier uses the maximum int64 duration.
func (s *stakerV1) SetWarmUp(_ int, rlm realm, pct, timeDuration int64) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedStaker()

	previousRealm := rlm.Previous()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	s.setWarmUp(0, rlm, pct, timeDuration)

	chain.Emit(
		"SetWarmUp",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"pct", utils.FormatInt(pct),
		"timeDuration", utils.FormatInt(timeDuration),
	)
}

// setPoolTier internally sets the pool tier.
//
// Parameters:
//   - _: Internal crossing discriminator forwarded as 0 to dependent realm calls.
//   - rlm: Propagated realm context used for minting emission and updating staker state.
//   - poolPath: Pool path whose tier state is updated.
//   - tier: New emission tier to apply to the pool.
//   - currentTime: Unix timestamp in seconds at which reward accounting is synchronized.
//
// Returns:
//   - currentEmission: Updated aggregate GNS emission rate after applying the tier change.
//   - tierRewards: Per-tier reward rates after the change, keyed by tier number.
func (s *stakerV1) setPoolTier(_ int, rlm realm, poolPath string, tier uint64, currentTime int64) (int64, map[uint64]int64) {
	s.emissionAccessor.MintAndDistributeGns(0, rlm)

	pool := s.getPools().GetPoolOrNil(poolPath)
	if pool == nil {
		pool = sr.NewPool(poolPath, currentTime)
		s.getPools().set(poolPath, pool)
	}
	poolTier := s.getPoolTier()
	tierRewards := poolTier.changeTier(currentTime, s.getPools(), poolPath, tier)

	s.updatePoolTier(0, rlm, poolTier)

	return poolTier.currentEmission, tierRewards
}

// changePoolTier internally changes the pool tier and returns old and new tiers.
//
// Parameters:
//   - _: Internal crossing discriminator forwarded as 0 to dependent realm calls.
//   - rlm: Propagated realm context used for minting emission and updating staker state.
//   - poolPath: Pool path whose existing tier is being replaced.
//   - tier: Replacement emission tier.
//   - currentTime: Unix timestamp in seconds at which reward accounting is synchronized.
//
// Returns:
//   - previousTier: Emission tier assigned before the change.
//   - newTier: Emission tier assigned after the change.
//   - currentEmission: Updated aggregate GNS emission rate.
//   - tierRewards: Per-tier reward rates after the change, keyed by tier number.
func (s *stakerV1) changePoolTier(_ int, rlm realm, poolPath string, tier uint64, currentTime int64) (uint64, uint64, int64, map[uint64]int64) {
	s.emissionAccessor.MintAndDistributeGns(0, rlm)
	poolTier := s.getPoolTier()
	previousTier := poolTier.CurrentTier(poolPath)

	tierRewards := poolTier.changeTier(currentTime, s.getPools(), poolPath, tier)

	s.updatePoolTier(0, rlm, poolTier)

	return previousTier, tier, poolTier.currentEmission, tierRewards
}

// removePoolTier internally removes the pool from tier system.
//
// Parameters:
//   - _: Internal crossing discriminator forwarded as 0 to dependent realm calls.
//   - rlm: Propagated realm context used for minting emission and updating staker state.
//   - poolPath: Pool path whose tier is being removed.
//   - currentTime: Unix timestamp in seconds at which reward accounting is synchronized.
//
// Returns:
//   - currentEmission: Updated aggregate GNS emission rate after removing the pool tier.
//   - tierRewards: Per-tier reward rates after the removal, keyed by tier number.
func (s *stakerV1) removePoolTier(_ int, rlm realm, poolPath string, currentTime int64) (int64, map[uint64]int64) {
	s.emissionAccessor.MintAndDistributeGns(0, rlm)

	poolTier := s.getPoolTier()
	tierRewards := poolTier.changeTier(currentTime, s.getPools(), poolPath, NOT_EMISSION_TARGET_TIER)
	s.updatePoolTier(0, rlm, poolTier)

	return poolTier.currentEmission, tierRewards
}

// setWarmUp internally sets the warm-up parameters.
//
// Parameters:
//   - _: Internal crossing discriminator forwarded as 0 to dependent realm calls.
//   - rlm: Propagated realm context used for minting emission and updating the warm-up template.
//   - pct: Warm-up tier percentage selecting the template slot to modify.
//   - timeDuration: Warm-up duration in seconds written into the selected template.
func (s *stakerV1) setWarmUp(_ int, rlm realm, pct, timeDuration int64) {
	s.emissionAccessor.MintAndDistributeGns(0, rlm)

	warmupTemplate := s.store.GetWarmupTemplate()
	warmupTemplate = modifyWarmup(warmupTemplate, pctToIndex(pct), timeDuration)

	err := s.store.SetWarmupTemplate(0, rlm, warmupTemplate)
	if err != nil {
		panic(err)
	}
}

// pctToIndex converts percentage to warmup index.
//
// Parameters:
//   - pct: Warm-up percentage whose template index is required; accepted values are 30, 50, 70, and 100.
//
// Returns:
//   - index: Zero-based warm-up template index corresponding to pct.
func pctToIndex(pct int64) int {
	switch pct {
	case 30:
		return 0
	case 50:
		return 1
	case 70:
		return 2
	case 100:
		return 3
	default:
		panic("staker.gno__pctToIndex() || pct is not valid")
	}
}

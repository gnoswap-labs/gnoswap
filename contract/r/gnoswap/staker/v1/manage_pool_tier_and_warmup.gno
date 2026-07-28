package staker

import (
	"chain"
	"chain/runtime"
	"errors"
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
func (s *stakerV1) SetPoolTier(_ int, rlm realm, poolPath string, tier uint64) {
	if !rlm.IsCurrent() {
		panic(errors.New(errSpoofedRealm))
	}

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
func (s *stakerV1) ChangePoolTier(_ int, rlm realm, poolPath string, tier uint64) {
	if !rlm.IsCurrent() {
		panic(errors.New(errSpoofedRealm))
	}

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
func (s *stakerV1) RemovePoolTier(_ int, rlm realm, poolPath string) {
	if !rlm.IsCurrent() {
		panic(errors.New(errSpoofedRealm))
	}

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

// SetWarmUp configures the warm-up percentage and duration for rewards.
// Only admin or governance can call this function.
func (s *stakerV1) SetWarmUp(_ int, rlm realm, pct, timeDuration int64) {
	if !rlm.IsCurrent() {
		panic(errors.New(errSpoofedRealm))
	}

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
func (s *stakerV1) changePoolTier(_ int, rlm realm, poolPath string, tier uint64, currentTime int64) (uint64, uint64, int64, map[uint64]int64) {
	s.emissionAccessor.MintAndDistributeGns(0, rlm)
	poolTier := s.getPoolTier()
	previousTier := poolTier.CurrentTier(poolPath)

	tierRewards := poolTier.changeTier(currentTime, s.getPools(), poolPath, tier)

	s.updatePoolTier(0, rlm, poolTier)

	return previousTier, tier, poolTier.currentEmission, tierRewards
}

// removePoolTier internally removes the pool from tier system.
func (s *stakerV1) removePoolTier(_ int, rlm realm, poolPath string, currentTime int64) (int64, map[uint64]int64) {
	s.emissionAccessor.MintAndDistributeGns(0, rlm)

	poolTier := s.getPoolTier()
	tierRewards := poolTier.changeTier(currentTime, s.getPools(), poolPath, NOT_EMISSION_TARGET_TIER)
	s.updatePoolTier(0, rlm, poolTier)

	return poolTier.currentEmission, tierRewards
}

// setWarmUp internally sets the warm-up parameters.
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

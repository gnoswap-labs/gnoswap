package v1

import (
	"chain"
	"chain/runtime"
	"time"

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
		panic(errSpoofedRealm)
	}

	halt.AssertIsNotHaltedStaker()

	caller := rlm.Previous().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsPoolExists(s, poolPath)
	assertIsValidPoolTier(tier)

	currentTime := time.Now().Unix()
	s.setPoolTier(0, rlm, poolPath, tier, currentTime)

	previousRealm := rlm.Previous()
	chain.Emit(
		"SetPoolTier",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", poolPath,
		"tier", formatUint(tier),
		"currentTime", formatAnyInt(currentTime),
		"currentHeight", formatAnyInt(runtime.ChainHeight()),
	)
}

// ChangePoolTier modifies the tier level of an existing pool.
// Only admin or governance can call this function.
func (s *stakerV1) ChangePoolTier(_ int, rlm realm, poolPath string, tier uint64) {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

	halt.AssertIsNotHaltedStaker()

	previousRealm := rlm.Previous()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsPoolExists(s, poolPath)
	assertIsValidPoolTier(tier)

	currentTime := time.Now().Unix()
	previousTier, newTier := s.changePoolTier(0, rlm, poolPath, tier, currentTime)

	chain.Emit(
		"ChangePoolTier",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", poolPath,
		"prevTier", formatUint(previousTier),
		"newTier", formatUint(newTier),
		"currentTime", formatAnyInt(currentTime),
		"currentHeight", formatAnyInt(runtime.ChainHeight()),
	)
}

// RemovePoolTier removes a pool from internal GNS emission rewards.
// Only admin or governance can call this function.
func (s *stakerV1) RemovePoolTier(_ int, rlm realm, poolPath string) {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

	halt.AssertIsNotHaltedStaker()

	previousRealm := rlm.Previous()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsPoolExists(s, poolPath)

	currentTime := time.Now().Unix()
	s.removePoolTier(0, rlm, poolPath, currentTime)

	chain.Emit(
		"RemovePoolTier",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", poolPath,
		"currentTime", formatAnyInt(currentTime),
		"currentHeight", formatAnyInt(runtime.ChainHeight()),
	)
}

// SetWarmUp configures the warm-up percentage and duration for rewards.
// Only admin or governance can call this function.
func (s *stakerV1) SetWarmUp(_ int, rlm realm, pct, timeDuration int64) {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
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
		"pct", formatAnyInt(pct),
		"timeDuration", formatAnyInt(timeDuration),
	)
}

// setPoolTier internally sets the pool tier.
func (s *stakerV1) setPoolTier(_ int, rlm realm, poolPath string, tier uint64, currentTime int64) {
	s.emissionAccessor.MintAndDistributeGns(0, rlm)

	pool := s.getPools().GetPoolOrNil(poolPath)
	if pool == nil {
		pool = sr.NewPool(poolPath, currentTime)
		s.getPools().set(poolPath, pool)
	}
	poolTier := s.getPoolTier()
	poolTier.changeTier(currentTime, s.getPools(), poolPath, tier)
	s.updatePoolTier(0, rlm, poolTier)
}

// changePoolTier internally changes the pool tier and returns old and new tiers.
func (s *stakerV1) changePoolTier(_ int, rlm realm, poolPath string, tier uint64, currentTime int64) (uint64, uint64) {
	s.emissionAccessor.MintAndDistributeGns(0, rlm)
	poolTier := s.getPoolTier()
	previousTier := poolTier.CurrentTier(poolPath)

	poolTier.changeTier(currentTime, s.getPools(), poolPath, tier)
	s.updatePoolTier(0, rlm, poolTier)

	return previousTier, tier
}

// removePoolTier internally removes the pool from tier system.
func (s *stakerV1) removePoolTier(_ int, rlm realm, poolPath string, currentTime int64) {
	s.emissionAccessor.MintAndDistributeGns(0, rlm)

	poolTier := s.getPoolTier()
	poolTier.changeTier(currentTime, s.getPools(), poolPath, NOT_EMISSION_TARGET_TIER)
	s.updatePoolTier(0, rlm, poolTier)
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

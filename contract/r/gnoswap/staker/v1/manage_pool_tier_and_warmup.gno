package v1

import (
	"chain"
	"chain/runtime"
	"time"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/halt"
	sr "gno.land/r/gnoswap/staker"
)

const (
	NOT_EMISSION_TARGET_TIER uint64 = 0
)

// SetPoolTier assigns a tier level to a pool for internal GNS emission rewards.
// Only admin or governance can call this function.
func (s *stakerV1) SetPoolTier(poolPath string, tier uint64) {
	halt.AssertIsNotHaltedStaker()

	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsPoolExists(s, poolPath)
	assertIsValidPoolTier(tier)

	currentTime := time.Now().Unix()
	s.setPoolTier(poolPath, tier, currentTime)

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"SetPoolTier",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", poolPath,
		"tier", formatUint(tier),
		"currentTime", formatInt(currentTime),
		"currentHeight", formatInt(runtime.ChainHeight()),
	)
}

// ChangePoolTier modifies the tier level of an existing pool.
// Only admin or governance can call this function.
func (s *stakerV1) ChangePoolTier(poolPath string, tier uint64) {
	halt.AssertIsNotHaltedStaker()

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsPoolExists(s, poolPath)
	assertIsValidPoolTier(tier)

	currentTime := time.Now().Unix()
	previousTier, newTier := s.changePoolTier(poolPath, tier, currentTime)

	chain.Emit(
		"ChangePoolTier",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", poolPath,
		"prevTier", formatUint(previousTier),
		"newTier", formatUint(newTier),
		"currentTime", formatInt(currentTime),
		"currentHeight", formatInt(runtime.ChainHeight()),
	)
}

// RemovePoolTier removes a pool from internal GNS emission rewards.
// Only admin or governance can call this function.
func (s *stakerV1) RemovePoolTier(poolPath string) {
	halt.AssertIsNotHaltedStaker()

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	assertIsPoolExists(s, poolPath)

	currentTime := time.Now().Unix()
	s.removePoolTier(poolPath, currentTime)

	chain.Emit(
		"RemovePoolTier",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"poolPath", poolPath,
		"currentTime", formatInt(currentTime),
		"currentHeight", formatInt(runtime.ChainHeight()),
	)
}

// SetWarmUp configures the warm-up percentage and duration for rewards.
// Only admin or governance can call this function.
func (s *stakerV1) SetWarmUp(pct, timeDuration int64) {
	halt.AssertIsNotHaltedStaker()

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	access.AssertIsAdminOrGovernance(caller)

	s.setWarmUp(pct, timeDuration)

	chain.Emit(
		"SetWarmUp",
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"pct", formatInt(pct),
		"timeDuration", formatInt(timeDuration),
	)
}

// setPoolTier internally sets the pool tier.
func (s *stakerV1) setPoolTier(poolPath string, tier uint64, currentTime int64) {
	s.emissionAccessor.MintAndDistributeGns()

	pool := s.getPools().GetPoolOrNil(poolPath)
	if pool == nil {
		pool = sr.NewPool(poolPath, time.Now().Unix())
		s.getPools().set(poolPath, pool)
	}
	poolTier := s.getPoolTier()
	poolTier.changeTier(runtime.ChainHeight(), currentTime, s.getPools(), poolPath, tier)
	s.updatePoolTier(poolTier)
}

// changePoolTier internally changes the pool tier and returns old and new tiers.
func (s *stakerV1) changePoolTier(poolPath string, tier uint64, currentTime int64) (uint64, uint64) {
	s.emissionAccessor.MintAndDistributeGns()
	poolTier := s.getPoolTier()
	previousTier := poolTier.CurrentTier(poolPath)

	poolTier.changeTier(runtime.ChainHeight(), currentTime, s.getPools(), poolPath, tier)
	s.updatePoolTier(poolTier)

	return previousTier, tier
}

// removePoolTier internally removes the pool from tier system.
func (s *stakerV1) removePoolTier(poolPath string, currentTime int64) {
	s.emissionAccessor.MintAndDistributeGns()

	poolTier := s.getPoolTier()
	poolTier.changeTier(runtime.ChainHeight(), currentTime, s.getPools(), poolPath, NOT_EMISSION_TARGET_TIER)
	s.updatePoolTier(poolTier)
}

// setWarmUp internally sets the warm-up parameters.
func (s *stakerV1) setWarmUp(pct, timeDuration int64) {
	s.emissionAccessor.MintAndDistributeGns()

	warmupTemplate := s.store.GetWarmupTemplate()
	warmupTemplate = modifyWarmup(warmupTemplate, pctToIndex(pct), timeDuration)

	err := s.store.SetWarmupTemplate(warmupTemplate)
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

// assertPoolMustExist panics if the pool doesn't exist.
func assertPoolMustExist(s *stakerV1, poolPath string) {
	if !s.poolAccessor.ExistsPoolPath(poolPath) {
		panic(makeErrorWithDetails(
			errInvalidPoolPath,
			ufmt.Sprintf("pool(%s) does not exist", poolPath),
		))
	}
}

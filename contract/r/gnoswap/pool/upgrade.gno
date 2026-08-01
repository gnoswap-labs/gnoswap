package pool

import (
	"errors"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
)

// EmissionAccessor provides pool/v1 with cross-realm access to emission
// functions. Wrappers are constructed inside the pool domain so that
// closures persisted into emission state are owned by the pool proxy.
type EmissionAccessor interface {
	SetDefaultInitialPoolChecker(_ int, rlm realm, checker func() bool)
}

type emissionAccessor struct{}

func (e *emissionAccessor) SetDefaultInitialPoolChecker(_ int, rlm realm, checker func() bool) {
	if !rlm.IsCurrent() {
		panic(errors.New(ErrSpoofedRealm))
	}

	// Wrap the caller-provided checker in an adapter constructed HERE, inside
	// the /r/gnoswap/pool domain package. By borrow rule #3 the wrapper
	// closure is owned by /r/gnoswap/pool (its construction realm), not by the
	// v1 implementation that passed `checker` in. This lets emission persist
	// the checker into its package-level var without hitting "cannot persist
	// realm value" (which fires when a v1-constructed closure is stored there
	// directly).
	emission.SetDefaultInitialPoolChecker(cross(rlm), func() bool {
		return checker()
	})
}

func newEmissionAccessor() EmissionAccessor {
	return &emissionAccessor{}
}

// RegisterInitializer registers a new pool implementation version.
// This function is called by each version (v1, v2, etc.) during initialization
// to register their implementation with the proxy system.
//
// The initializer function creates a new instance of the implementation
// using the provided poolStore interface.
//
// The stateInitializer function creates the initial state for this version.
//
// Security: Only contracts within the domain path can register initializers.
// Each package path can only register once to prevent duplicate registrations.
func RegisterInitializer(cur realm, initializer func(_ int, rlm realm, poolStore IPoolStore, emissionAccessor EmissionAccessor) IPool) {
	initializerFunc := func(_ int, rlm realm, domainStore any) any {
		if !rlm.IsCurrent() {
			panic(errors.New(ErrSpoofedRealm))
		}

		currentPoolStore, ok := domainStore.(IPoolStore)
		if !ok {
			panic("domainStore is not an IPoolStore")
		}

		return initializer(0, rlm, currentPoolStore, newEmissionAccessor())
	}

	err := versionManager.RegisterInitializer(0, cur, initializerFunc)
	if err != nil {
		panic(err)
	}

	err = updateImplementation()
	if err != nil {
		panic(err)
	}
}

// UpgradeImpl switches the active pool implementation to a different version.
// This function allows seamless upgrades from one version to another without
// data migration or downtime.
//
// Security: Only admin or governance can perform upgrades.
// The new implementation must have been previously registered via RegisterInitializer.
// The pool must not be locked (see assertPoolUnlocked).
func UpgradeImpl(cur realm, packagePath string) {
	// Ensure only admin or governance can perform upgrades
	caller := cur.Previous().Address()
	access.AssertIsAdminOrGovernance(caller)

	assertPoolUnlocked()

	err := versionManager.ChangeImplementation(0, cur, packagePath)
	if err != nil {
		panic(err)
	}

	err = updateImplementation()
	if err != nil {
		panic(err)
	}
}

// assertPoolUnlocked panics if the pool's reentrancy lock is currently held.
// It mirrors poolV1.assertPoolUnlocked (r/gnoswap/pool/v1/lock.gno): read-only,
// so it is safe to call before the admin/governance authorization check too.
// HasUnlocked() is false until a swap has ever run, so pools with no swap
// history are unaffected.
func assertPoolUnlocked() {
	s := NewPoolStore(kvStore)
	if s.HasUnlocked() && !s.GetUnlocked() {
		panic(errors.New(errUpgradeWhileLocked))
	}
}

// GetImplementationPackagePath returns the package path of the currently active implementation.
func GetImplementationPackagePath() string {
	return versionManager.GetCurrentPackagePath()
}

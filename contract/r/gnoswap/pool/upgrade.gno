package pool

import (
	"errors"

	"gno.land/r/gnoswap/access/v1"
)

// RegisterInitializer registers a new pool implementation version.
// This function is called by each version (v1, v2, etc.) during initialization
// to register their implementation with the proxy system.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this
//     realm.
//   - initializer: Version factory receiving the forwarded discriminator, current
//     realm, and shared IPoolStore; it returns the implementation instance to
//     register and later activate.
//
// Security: Only contracts within the domain path can register initializers.
// Each package path can only register once to prevent duplicate registrations.
func RegisterInitializer(cur realm, initializer func(_ int, rlm realm, poolStore IPoolStore) IPool) {
	initializerFunc := func(_ int, rlm realm, domainStore any) any {
		access.AssertIsRlmCurrent(0, rlm)

		currentPoolStore, ok := domainStore.(IPoolStore)
		if !ok {
			panic("domainStore is not an IPoolStore")
		}

		return initializer(0, rlm, currentPoolStore)
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
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this
//     realm.
//   - packagePath: Full package path of a version previously registered for this
//     pool domain.
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
//
// Returns:
//   - packagePath: Full package path of the active implementation; empty before
//     any version has been registered.
func GetImplementationPackagePath() string {
	return versionManager.GetCurrentPackagePath()
}

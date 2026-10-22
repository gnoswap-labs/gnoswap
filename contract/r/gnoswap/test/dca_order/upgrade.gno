package dca_order

import (
	"gno.land/r/gnoswap/access/v1"
)

// RegisterInitializer registers a DCA order implementation version.
// Each version calls it from init; the version manager restricts callers to
// packages under this domain path and activates the first registration.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur).
//   - initializer: version factory receiving the shared store.
func RegisterInitializer(cur realm, initializer func(_ int, rlm realm, dcaStore IDCAOrderStore) IDCAOrder) {
	initializerFunc := func(_ int, rlm realm, domainStore any) any {
		access.AssertIsRlmCurrent(0, rlm)

		currentStore, ok := domainStore.(IDCAOrderStore)
		if !ok {
			panic("domainStore is not an IDCAOrderStore")
		}

		return initializer(0, rlm, currentStore)
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

// UpgradeImpl switches the active implementation. Admin or governance only.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur).
//   - packagePath: package path of a previously registered version.
func UpgradeImpl(cur realm, packagePath string) {
	caller := cur.Previous().Address()
	access.AssertIsAdminOrGovernance(caller)

	// Never swap implementations under an in-flight round: the old version
	// still has to write the accumulator when its router swap returns.
	if NewDCAOrderStore(kvStore).IsExecuting() {
		panic(ErrUpgradeWhileExecuting)
	}

	err := versionManager.ChangeImplementation(0, cur, packagePath)
	if err != nil {
		panic(err)
	}

	err = updateImplementation()
	if err != nil {
		panic(err)
	}
}

// GetImplementationPackagePath returns the active implementation path.
func GetImplementationPackagePath() string {
	return versionManager.GetCurrentPackagePath()
}

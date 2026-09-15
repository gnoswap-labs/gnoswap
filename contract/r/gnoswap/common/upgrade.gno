package common

import (
	"gno.land/r/gnoswap/access/v1"
)

func RegisterInitializer(cur realm, initializer func(_ int, rlm realm) ICommon) {
	initializerFunc := func(_ int, rlm realm, _ any) any {
		access.AssertIsRlmCurrent(0, rlm)

		return initializer(0, rlm)
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

func UpgradeImpl(cur realm, packagePath string) {
	prev := cur.Previous()
	access.AssertIsAdminOrGovernance(prev.Address())

	err := versionManager.ChangeImplementation(0, cur, packagePath)
	if err != nil {
		panic(err)
	}

	err = updateImplementation()
	if err != nil {
		panic(err)
	}
}

func GetImplementationPackagePath() string {
	return versionManager.GetCurrentPackagePath()
}

package pool

import (
	"std"

	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/consts"
)

var (
	govRealm string

	// flagHalt is set to true when the emergency halt proposal is passed
	// when this flag is set to true, all public functions in this package will panic
	flagHalt bool
)

func init() {
	govRealm = consts.GOV_PATH
	flagHalt = false
}

func assertCalledByGovRealm() {
	if std.PrevRealm() != govRealm {
		panic(ufmt.Sprintf("[POOL] emergency_halt.gno__assertCalledByGovRealm() || function can only be called from gov realm(%s)", std.PrevRealm().PkgPath()))
	}
}

func halt() {
	assertCalledByGovRealm()
	flagHalt = true
}

func assertNotHalt() {
	if flagHalt {
		panic("[POOL] emergency_halt.gno__assertNotHalt() || emergency halt")
	}
}

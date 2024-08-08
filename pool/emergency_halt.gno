package pool

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v2/consts"
)

var (
	// flagHalt is set to true when the emergency halt proposal is passed
	// when this flag is set to true, all public functions in this package will panic
	flagHalt bool
)

func init() {
	flagHalt = false
}

func assertCalledByGovRealm() {
	if std.PrevRealm().PkgPath() != consts.GOV_PATH {
		panic(ufmt.Sprintf("[POOL] emergency_halt.gno__assertCalledByGovRealm() || only gov(%s) can call, but called from(%s)", consts.GOV_PATH, std.PrevRealm().PkgPath()))
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

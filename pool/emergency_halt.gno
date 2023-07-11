package pool

var govRealm string

// flagHalt is set to true when the emergency halt proposal is passed
// when this flag is set to true, all public functions in this package will panic
var flagHalt bool

func init() {
	govRealm = "gno.land/r/gov"
	halt = false
}

func assertCalledByGovRealm() {
	if std.PrevRealm() != govRealm {
		panic("function can only be called from gov realm")
	}
}

func halt() {
	assertCalledByGovRealm()
	flagHalt = true
}

func assertNotHalt() {
	if flagHalt {
		panic("emergency halt")
	}
}
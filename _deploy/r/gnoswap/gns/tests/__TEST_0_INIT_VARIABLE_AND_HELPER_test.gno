package gns

import (
	"std"

	"testing"

	pusers "gno.land/p/demo/users"

	consts "gno.land/r/gnoswap/v2/consts"
)

var (
	swapAdmin      std.Address = consts.ADMIN
	swapAdminRealm             = std.NewUserRealm(swapAdmin)

	emissionUsers = pusers.AddressOrName(consts.EMISSION_ADDR)
	emissionRealm = std.NewCodeRealm(consts.EMISSION_PATH)
)

func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got\n%v\n\nexpected\n%v\n", got, expected)
	}
}

func shouldPanic(t *testing.T, f func()) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("expected panic")
		}
	}()
	f()
}

func shouldPanicWithMsg(t *testing.T, f func(), msg string) {
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("The code did not panic")
		} else {
			if r != msg {
				t.Errorf("excepted panic(%v), got(%v)", msg, r)
			}
		}
	}()
	f()
}

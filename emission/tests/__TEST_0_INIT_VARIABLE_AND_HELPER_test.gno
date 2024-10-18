package emission

import (
	"std"
	"strings"
	"testing"

	"gno.land/r/gnoswap/v2/consts"
)

var (
	admin std.Address = consts.ADMIN
)

// Realms to mock frames
var (
	adminRealm = std.NewUserRealm(admin)

	govRealm = std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH)
)

/* HELPER */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got %v, expected %v", got, expected)
	}
}

func shouldNEQ(t *testing.T, got, expected interface{}) {
	if got == expected {
		t.Errorf("got %v, didn't expected %v", got, expected)
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
			if !strings.Contains(string(r), msg) {
				t.Errorf("excepted panic\n%v\n\ngot\n%v\n", msg, r)
			}
		}
	}()
	f()
}

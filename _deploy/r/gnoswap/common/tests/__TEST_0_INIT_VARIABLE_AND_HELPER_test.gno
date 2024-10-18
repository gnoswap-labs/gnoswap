package common

import (
	"std"
	"strings"
	"testing"

	"gno.land/p/demo/testutils"

	"gno.land/r/gnoswap/v2/consts"
)

var (
	admin      = consts.ADMIN
	adminRealm = std.NewUserRealm(admin)

	dummy      = testutils.TestAddress("dummy")
	dummyRealm = std.NewUserRealm(dummy)

	govRealm = std.NewCodeRealm(consts.GOV_GOVERNANCE_PATH)
)

/* HELPER */
func shouldEQ(t *testing.T, got, expected interface{}) {
	if got != expected {
		t.Errorf("got\n%v\n\nexpected\n%v\n", got, expected)
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

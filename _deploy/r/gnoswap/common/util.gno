package common

import (
	"std"
)

func getPrev() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}

func boolToStr(b bool) string {
	if b {
		return "true"
	}

	return "false"
}

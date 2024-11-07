package staker

import (
	b64 "encoding/base64"
	"std"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
)

func maxUint64(a, b uint64) uint64 {
	if a > b {
		return a
	}
	return b
}

func marshal(data *json.Node) string {
	b, err := json.Marshal(data)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}

func b64Encode(data string) string {
	return string(b64.StdEncoding.EncodeToString([]byte(data)))
}

func prevRealm() string {
	return std.PrevRealm().PkgPath()
}

func isUserCall() bool {
	return std.PrevRealm().IsUser()
}

func assertUserCall() {
	if !isUserCall() {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("util.gno__assertUserCall() || must be called by user, called from %s", std.PrevRealm().PkgPath()),
		))
	}
}

func getPrev() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}

package staker

import (
	b64 "encoding/base64"
	"std"
	"strconv"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
)

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

func getPrev() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func formatUint(v uint64) string {
	return strconv.FormatUint(v, 10)
}

func formatInt(v int64) string {
	return strconv.FormatInt(v, 10)
}

func assertCallerIsAdmin() {
	caller := std.PrevRealm().Addr()
	if err := common.AdminOnly(caller); err != nil {
		panic(err)
	}
}

func assertCallerIsLaunchpad() {
	caller := std.PrevRealm().Addr()
	if caller != consts.LAUNCHPAD_ADDR {
		panic(addDetailToError(
			errNoPermission,
			ufmt.Sprintf("only launchpad can call CollectRewardFromLaunchPad(), called from %s", caller.String()),
		))
	}
}

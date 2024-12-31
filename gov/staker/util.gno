package staker

import (
	b64 "encoding/base64"
	"std"
	"strconv"

	"gno.land/p/demo/json"
	pusers "gno.land/p/demo/users"
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

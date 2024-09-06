package staker

import (
	"std"

	b64 "encoding/base64"

	"gno.land/p/demo/json"
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

func origCaller() string {
	return std.GetOrigCaller().String()
}

func prevRealm() string {
	return std.PrevRealm().PkgPath()
}

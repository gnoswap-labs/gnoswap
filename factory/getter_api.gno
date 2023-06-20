package factory

import (
	"encoding/json"
)

type ApiBasicInfo struct {
	Height    int64
	Timestamp int64
}

type ApiPoolKeyList struct {
	PoolKeys []string
}

func ApiGetPools() string {
	abi := ApiBasicInfo{
		Height:    GetHeight(),
		Timestamp: GetTimestamp(),
	}

	apl := poolKeys

	r := struct {
		ApiBasicInfo
		ApiPoolKeyList
	}{
		abi,
		ApiPoolKeyList{apl},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(err)
	}

	return string(rr)
}

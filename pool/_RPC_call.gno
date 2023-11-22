package pool

import (
	"encoding/json"

	"gno.land/p/demo/ufmt"
)

func RpcGetPools() string {
	poolsDetail := []SinglePool{}

	for poolPath, pool := range pools {
		singlePool := handleSinglePool(poolPath)
		poolsDetail = append(poolsDetail, singlePool)
	}

	rr, err := json.Marshal(poolsDetail)
	if err != nil {
		panic(ufmt.Sprintf("[POOL] getter_api.gno__ApiGetPools() || %v", err))
	}

	return string(rr)
}

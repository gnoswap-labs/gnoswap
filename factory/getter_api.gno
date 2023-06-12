package factory

import (
	"encoding/json"
	"strings"

	p "gno.land/r/pool"
)

type ApiBasicInfo struct {
	Height    int64
	Timestamp int64
}

type ApiPoolInfo struct {
	Token0    string
	Token1    string
	Fee       bigint
	Liquidity bigint
}

func ApiGetPools() string {
	abi := ApiBasicInfo{
		Height:    GetHeight(),
		Timestamp: GetTimestamp(),
	}

	apl := getPoolList()

	r := struct {
		ApiBasicInfo
		Pools []ApiPoolInfo
	}{
		abi,
		apl,
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(err)
	}

	return string(rr)
}

func getPoolList() []ApiPoolInfo {
	poolSize := pools.Size()
	poolList := make([]ApiPoolInfo, poolSize)

	for i := 0; i < poolSize; i++ {
		key, value := pools.GetByIndex(i)
		// single pool
		sp := value.(*p.Pool)

		poolList[i] = ApiPoolInfo{
			Token0:    p.GetPoolToken0(sp).GetName(),
			Token1:    p.GetPoolToken1(sp).GetName(),
			Fee:       p.GetPoolFee(sp),
			Liquidity: p.GetPoolLiquidity(sp),
		}
	}

	return poolList
}

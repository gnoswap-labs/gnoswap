package position

import (
	"encoding/json"
	"std"

	nft "gno.land/r/foo721"

	"gno.land/p/demo/avl"

	"gno.land/p/demo/grc/grc721"
)

type ApiPoolList struct {
	Address std.Address
	Id      bigint
}

type ApiPositionInfo struct {
	Nonce                    bigint
	Operator                 std.Address
	PoolId                   bigint
	TickLower                bigint
	TickUpper                bigint
	Liquidity                bigint
	FeeGrowthInside0LastX128 bigint
	FeeGrowthInside1LastX128 bigint
	TokensOwed0              bigint
	TokensOwed1              bigint
}

type ApiBasicInfo struct {
	Height    int64
	Timestamp int64
}

func ApiGetPoolList() string {
	abi := ApiBasicInfo{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}
	apl := getPoolList()

	r := struct {
		ApiBasicInfo
		PoolList []ApiPoolList
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

func ApiGetPositionList() string {
	abi := ApiBasicInfo{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	tids := getTokenIdList()
	apl := make(map[string]ApiPositionInfo)
	for _, tid := range tids {
		apl[string(tid)] = getPositionInfo(string(tid))
	}

	r := struct {
		ApiBasicInfo
		PositionList map[string]ApiPositionInfo
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

func getPoolList() []ApiPoolList {
	poolSize := poolIds.Size()
	poolList := make([]ApiPoolList, poolSize)

	for i := 0; i < poolSize; i++ {
		key, value := poolIds.GetByIndex(i)
		poolList[i] = ApiPoolList{
			Address: std.Address(key),
			Id:      value.(bigint),
		}
	}

	return poolList
}

func getTokenIdList() []bigint {
	tids := make([]bigint, 0)

	for i := bigint(1); i < nextId; i++ {
		exist := nft.Exists(grc721.TokenID(i))

		if exist {
			fid := i // found token id
			tids = append(tids, fid)
		}
	}

	return tids
}

func getPositionInfo(tid string) ApiPositionInfo {
	pi, ok := positions.Get(tid)
	if ok {
		return ApiPositionInfo(pi.(Position))
	}
	return nil
}

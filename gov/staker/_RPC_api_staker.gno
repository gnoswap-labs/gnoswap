package staker

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
)

func GetLockedAmount() uint64 {
	return lockedAmount
}

func GetLockedInfoByAddress(addr string) string {
	lockeds, exist := addrLockedXGns[addr]
	if !exist {
		// panic("no locked xGNS")
		return ""
	}

	now := uint64(time.Now().Unix())

	totalLocked := uint64(0)
	claimableAmount := uint64(0)

	for _, locked := range lockeds {
		amount := locked.amount
		unlock := locked.unlock

		totalLocked += amount

		if now >= unlock {
			claimableAmount += amount
		}
	}

	lockedObj := json.ObjectNode("", nil)
	lockedObj.AppendObject("height", json.StringNode("height", ufmt.Sprintf("%d", std.GetHeight())))
	lockedObj.AppendObject("now", json.StringNode("now", ufmt.Sprintf("%d", time.Now().Unix())))
	lockedObj.AppendObject("totalLocked", json.StringNode("totalLocked", ufmt.Sprintf("%d", totalLocked)))
	lockedObj.AppendObject("claimableAmount", json.StringNode("claimableAmount", ufmt.Sprintf("%d", claimableAmount)))

	b, err := json.Marshal(lockedObj)
	if err != nil {
		panic(ufmt.Sprintf("JSON marshal error: %v", err))
	}

	return string(b)

}

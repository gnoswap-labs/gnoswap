package staker

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
)

// GetLockedAmount gets the total locked amount of GNS.
func GetLockedAmount() uint64 {
	return lockedAmount
}

// GetLockedInfoByAddress gets the locked info of an address.
// - total locked amount
// - claimable amount
func GetLockedInfoByAddress(addr string) string {
	lockeds, exist := addrLockedGns[addr]
	if !exist {
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

	return marshal(lockedObj)
}

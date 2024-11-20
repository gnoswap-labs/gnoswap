package staker

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	en "gno.land/r/gnoswap/v1/emission"
)

// GetPossibleVotingAddressWithWeight returns the max voting weight + and possible voting address with weight
func GetPossibleVotingAddressWithWeight(endTimestamp uint64) (uint64, map[std.Address]uint64) {
	en.MintAndDistributeGns()
	calculateReward()

	if endTimestamp > uint64(time.Now().Unix()) {
		panic(addDetailToError(
			errFutureTime,
			ufmt.Sprintf("_RPC_api_history.gno__GetPossibleVotingAddressWithWeight() || endTimestamp(%d) > now(%d)", endTimestamp, time.Now().Unix()),
		))
	}

	totalWeight := uint64(0)
	addressWithWeight := make(map[std.Address]uint64)

	for to, history := range delegationStatHistory {
		// reverse history
		for i := len(history) - 1; i >= 0; i-- {
			record := history[i]

			if record.updatedAt > endTimestamp {
				continue
			}

			addressWithWeight[to] = record.amount
			totalWeight += record.amount

			break
		}
	}

	return totalWeight, addressWithWeight
}

// GetPossibleVotingAddressWithWeightJSON returns the max voting weight + and possible voting address with weight(string json format)
func GetPossibleVotingAddressWithWeightJSON(endTimestamp uint64) (uint64, string) {
	en.MintAndDistributeGns()
	calculateReward()

	if endTimestamp > uint64(time.Now().Unix()) {
		panic(addDetailToError(
			errFutureTime,
			ufmt.Sprintf("_RPC_api_history.gno__GetPossibleVotingAddressWithWeightJSON() || endTimestamp(%d) > now(%d)", endTimestamp, time.Now().Unix()),
		))
	}

	totalWeight := uint64(0)
	addressWithWeight := make(map[std.Address]uint64)

	for to, history := range delegationStatHistory {
		// reverse history
		for i := len(history) - 1; i >= 0; i-- {
			record := history[i]

			if record.updatedAt > endTimestamp {
				continue
			}

			addressWithWeight[to] = record.amount
			totalWeight += record.amount

			break
		}
	}

	possibleObj := json.ObjectNode("", nil)
	possibleObj.AppendObject("height", json.StringNode("height", ufmt.Sprintf("%d", std.GetHeight())))
	possibleObj.AppendObject("now", json.StringNode("now", ufmt.Sprintf("%d", time.Now().Unix())))

	possibleArr := json.ArrayNode("votingPower", nil)
	for to, weight := range addressWithWeight {
		addrWithWeightObj := json.ObjectNode("", nil)
		addrWithWeightObj.AppendObject("address", json.StringNode("address", to.String()))
		addrWithWeightObj.AppendObject("weight", json.StringNode("weight", ufmt.Sprintf("%d", weight)))
		possibleArr.AppendArray(addrWithWeightObj)
	}

	possibleObj.AppendObject("votingPower", possibleArr)

	return totalWeight, marshal(possibleObj)
}

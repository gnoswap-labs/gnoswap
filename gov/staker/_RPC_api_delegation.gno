package staker

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/gns"
	"gno.land/r/gnoswap/v2/gov/xgns"

	en "gno.land/r/gnoswap/v2/emission"
)

// GetTotalStaked returns the total amount of GNS staked.
func GetTotalStaked() uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	return gns.BalanceOf(a2u(std.CurrentRealm().Addr()))
}

// GetTotalStaked returns the total amount of GNS staked.
func GetTotalStakedWithoutLockedAmount() uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	return gns.BalanceOf(a2u(std.CurrentRealm().Addr())) - lockedAmount
}

// GetTotalDelegated returns the total amount of xGNS delegated.
func GetTotalDelegated() uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	return totalDelegated
}

// GetTotalDelegatedFrom returns the total amount of xGNS delegated by given address.
func GetTotalDelegatedFrom(from std.Address) uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	amount, exist := delegatorAmount[from]
	if !exist {
		return 0
	}
	return amount
}

// GetTotalDelegatedTo returns the total amount of xGNS delegated to given address.
func GetTotalDelegatedTo(to std.Address) uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	amount, exist := delegatedTo[to]
	if !exist {
		return 0
	}
	return amount
}

// GetDelegationAmountFromTo returns the amount of xGNS delegated by given address to given address.
func GetDelegationAmountFromTo(from, to std.Address) uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	toAmount, exist := delegatedFromTo[from]
	if !exist {
		return 0
	}

	amount, exist := toAmount[to]
	if !exist {
		return 0
	}

	return amount
}

// GetDelegationRatioBase returns the data that can be used to calculate the delegation ratio.
// It returns the total supply of GNS and xGNS.
func GetDelegationRatioBase() string {
	en.MintAndDistributeGns()
	calculateReward()

	gnsTotalSupply := gns.TotalSupply()
	xGnsTotalSupply := xgns.TotalSupply()

	ratioObj := json.ObjectNode("", nil)
	ratioObj.AppendObject("height", json.StringNode("height", ufmt.Sprintf("%d", std.GetHeight())))
	ratioObj.AppendObject("now", json.StringNode("now", ufmt.Sprintf("%d", time.Now().Unix())))
	ratioObj.AppendObject("gnsTotalSupply", json.StringNode("gnsTotalSupply", ufmt.Sprintf("%d", gnsTotalSupply)))
	ratioObj.AppendObject("xGnsTotalSupply", json.StringNode("xGnsTotalSupply", ufmt.Sprintf("%d", xGnsTotalSupply)))

	b, err := json.Marshal(ratioObj)
	if err != nil {
		panic(ufmt.Sprintf("JSON marshal error: %v", err))
	}

	return string(b)
}

// GetVotingPowerBase returns the data that can be used to calculate the voting power.
// It returns the total delegated amount and the list of addresses and their delegated amount.
func GetVotingPowerBase() string {
	en.MintAndDistributeGns()
	calculateReward()

	votingObj := json.ObjectNode("", nil)
	votingObj.AppendObject("height", json.StringNode("height", ufmt.Sprintf("%d", std.GetHeight())))
	votingObj.AppendObject("now", json.StringNode("now", ufmt.Sprintf("%d", time.Now().Unix())))
	votingObj.AppendObject("totalDelegated", json.StringNode("totalDelegated", ufmt.Sprintf("%d", totalDelegated)))

	votingArr := json.ArrayNode("", nil)
	for addr, amount := range delegatedTo {
		votingObj := json.ObjectNode("", nil)
		votingObj.AppendObject("address", json.StringNode("address", addr.String()))
		votingObj.AppendObject("delegated", json.StringNode("delegated", ufmt.Sprintf("%d", amount)))
		votingArr.AppendArray(votingObj)
	}

	votingObj.AppendObject("votingPower", votingArr)

	b, err := json.Marshal(votingObj)
	if err != nil {
		panic(ufmt.Sprintf("JSON marshal error: %v", err))
	}

	return string(b)
}

// GetVotingPowerBaseByAddress returns the data that can be used to calculate the voting power of given address.
// It returns the total delegated amount and the delegated amount of given address.
func GetVotingPowerBaseByAddress(addr std.Address) string {
	en.MintAndDistributeGns()
	calculateReward()

	votingObj := json.ObjectNode("", nil)
	votingObj.AppendObject("height", json.StringNode("height", ufmt.Sprintf("%d", std.GetHeight())))
	votingObj.AppendObject("now", json.StringNode("now", ufmt.Sprintf("%d", time.Now().Unix())))
	votingObj.AppendObject("totalDelegated", json.StringNode("totalDelegated", ufmt.Sprintf("%d", totalDelegated)))

	votingArr := json.ArrayNode("", nil)
	for toAddr, amount := range delegatedTo {
		if toAddr == addr {
			votingObj := json.ObjectNode("", nil)
			votingObj.AppendObject("address", json.StringNode("address", addr.String()))
			votingObj.AppendObject("delegated", json.StringNode("delegated", ufmt.Sprintf("%d", amount)))
			votingArr.AppendArray(votingObj)
			break
		}
	}

	votingObj.AppendObject("votingPower", votingArr)

	b, err := json.Marshal(votingObj)
	if err != nil {
		panic(ufmt.Sprintf("JSON marshal error: %v", err))
	}

	return string(b)
}

// func GetTotalDelegatedUntil calculates the total delegated amount until given timestamp.
func GetTotalDelegatedUntil(timestamp uint64) uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	total := uint64(0)

	for _, history := range delegationModifiedHistory {
		for i := len(history) - 1; i >= 0; i-- {
			if history[i].delegatedTimestamp <= timestamp {
				total += history[i].delegatedAmount - history[i].undelegatedAmount
			}
		}
	}

	return total
}

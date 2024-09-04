package staker

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

	en "gno.land/r/gnoswap/v2/emission"
)

// GetDelegatedCumulativeDuration gets the cumulative delegated amount * seconds for an address at a certain timestamp.
func GetDelegatedCumulativeDuration(_delegator string, timestamp uint64) string {
	en.MintAndDistributeGns()
	calculateReward()

	delegator := std.Address(_delegator)
	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", _delegator))
	}

	if timestamp >= uint64(time.Now().Unix()) {
		panic("FUTURE")
	}

	history, exist := delegationModifiedHistory[delegator]
	if !exist || len(history) == 0 {
		return "0"
	}

	if timestamp < history[0].delegatedTimestamp {
		return "0"
	}

	cumulativeAmount := u256.Zero()

	for _, record := range history {
		if record.delegatedTimestamp > timestamp || record.undelegatedTimestamp > timestamp {
			// continue to next if this record uses future time
			continue
		}

		amount := record.delegatedAmount - record.undelegatedAmount
		if amount == 0 {
			// already undelegated full amount for this record
			continue
		}

		laterTime := maxUint64(record.delegatedTimestamp, record.undelegatedTimestamp)
		duration := timestamp - laterTime
		toAccu := new(u256.Uint).Mul(u256.NewUint(amount), u256.NewUint(duration))
		cumulativeAmount = new(u256.Uint).Add(cumulativeAmount, toAccu)
	}

	return cumulativeAmount.ToString()
}

// GetAverageDelegatedDuration calculates the average delegated amount for a delegate over a given period
func GetAverageDelegatedDuration(_delegator string, start, end uint64) string {
	en.MintAndDistributeGns()
	calculateReward()

	delegator := std.Address(_delegator)
	if !delegator.IsValid() {
		panic(ufmt.Sprintf("invalid delegator address: %s", _delegator))
	}

	if start > end {
		panic("start > end")
	}

	history, exist := delegationModifiedHistory[delegator]
	if !exist || len(history) == 0 {
		return "0"
	}

	if end <= history[0].delegatedTimestamp {
		return "0"
	}

	cumulativeAmount := u256.Zero()

	for _, record := range history {
		if record.delegatedTimestamp > end || record.undelegatedTimestamp > end {
			// continue to next if this record uses future time
			continue
		}

		amount := record.delegatedAmount - record.undelegatedAmount
		if amount == 0 {
			// already undelegated full amount for this record
			continue
		}

		duration := end - maxUint64(maxUint64(record.delegatedTimestamp, record.undelegatedTimestamp), start)
		toAccu := new(u256.Uint).Mul(u256.NewUint(amount), u256.NewUint(duration))

		cumulativeAmount = new(u256.Uint).Add(cumulativeAmount, toAccu)
	}

	res := u256.Zero()
	totalDuration := end - start
	if totalDuration == 0 {
		res = cumulativeAmount.Clone()
		return res.ToString()
	}

	res = u256.Zero().Div(cumulativeAmount, u256.NewUint(totalDuration))
	return res.ToString()
}

// GetAverageDelegatedDurationOverLastDuration gets the average amount delegated over the last period seconds.
func GetAverageDelegatedDurationOverLastDuration(_delegator string, period uint64) string {
	en.MintAndDistributeGns()
	calculateReward()

	now := uint64(time.Now().Unix())
	return GetAverageDelegatedDuration(_delegator, now-period, now)
}

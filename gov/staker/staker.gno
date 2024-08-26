package staker

import (
	"std"
	"time"

	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/v2/gns"
	"gno.land/r/gnoswap/v2/gov/xgns"
)

type lockedXGNS struct {
	amount uint64
	unlock uint64
}

const TIMESTAMP_7_DAYS = uint64(604800) // 7 days in seconds

var (
	addrLockedXGns = make(map[string][]lockedXGNS)
)

func Delegate(to std.Address, amount uint64) {
	if !to.IsValid() {
		panic(ufmt.Sprintf("invalid address %s to Delegate", to.String()))
	}

	caller := std.GetOrigCaller()

	// GNS // caller -> GovStaker
	gns.TransferFrom(a2u(caller), a2u(std.CurrentRealm().Addr()), amount)

	// xGNS mint to caller
	xgns.Mint(a2u(caller), amount)

	// actual delegate
	delegate(to, amount)

	// TODO:
	// std.Emit()
}

// xGNS from -> xGNS to
func Redelegate(from, to std.Address, amount uint64) {
	if !from.IsValid() {
		panic(ufmt.Sprintf("invalid from address %s to Redelegate", to.String()))
	}

	if !to.IsValid() {
		panic(ufmt.Sprintf("invalid to address %s to Redelegate", to.String()))
	}

	undelegate(from, amount)
	delegate(to, amount)

	// TODO:
	// std.Emit()
}

func Undelegate(from std.Address, amount uint64) {
	if !from.IsValid() {
		panic(ufmt.Sprintf("invalid address %s to Undelegate", from.String()))
	}

	caller := std.GetOrigCaller()

	if xgns.BalanceOf(a2u(caller)) < amount {
		panic("not enough xGNS staked")
	}

	// burn equivalent amount of xGNS
	xgns.Burn(a2u(caller), amount)

	// actual undelegate
	undelegate(from, amount)

	// lock up
	userLocked := lockedXGNS{
		amount: amount,
		unlock: uint64(time.Now().Unix()) + TIMESTAMP_7_DAYS, // after 7 days, call Collect() to receive GNS
	}
	addrLockedXGns[caller.String()] = append(addrLockedXGns[caller.String()], userLocked)

	// TODO:
	// std.Emit()
}

func Collect() uint64 {
	caller := std.GetOrigCaller()

	if len(addrLockedXGns[caller.String()]) == 0 {
		return 0
	}

	// check if caller has any GNS to claim
	for i, locked := range addrLockedXGns[caller.String()] {
		if uint64(time.Now().Unix()) >= locked.unlock { // passed 20 days
			// transfer GNS to caller
			gns.Transfer(a2u(caller), locked.amount)

			// TOOD:
			// std.Emit()

			// remove from locked list
			addrLockedXGns[caller.String()] = append(addrLockedXGns[caller.String()][:i], addrLockedXGns[caller.String()][i+1:]...)
			return locked.amount
		}
	}

	return 0
}

/*

// DelegationHistory represents a single delegation event
type DelegationHistory struct {
	amount    *u256.Uint
	timestamp uint64
}

// staking contract
type Staker struct {
	token             grc20.Token
	delegations       map[std.Address]*u256.Uint
	delegationHistory map[std.Address][]DelegationHistory
	totalStaked       *u256.Uint
}




// GetDelegatedCumulative gets the cumulative delegated amount * seconds for an address at a certain timestamp.
func GetDelegatedCumulative(delegate string, timestamp uint64) (string, error) {
	delegateAddr := std.Address(delegate)
	if !delegateAddr.IsValid() {
		panic(ufmt.Sprintf("invalid address: %s", delegate))
	}

	if timestamp > uint64(time.Now().Unix()) {
		panic("FUTURE")
	}

	history, exists := gStaker.delegationHistory[delegateAddr]
	if !exists || len(history) == 0 {
		return u256.Zero().ToString(), nil
	}

	var lastSnapshot DelegationHistory
	var cumulativeAmount u256.Uint

	for _, snapshot := range history {
		if snapshot.timestamp > timestamp {
			break
		}
		if lastSnapshot.timestamp != 0 {
			duration := snapshot.timestamp - lastSnapshot.timestamp
			cumulativeAmount.Add(&cumulativeAmount, u256.Zero().Mul(lastSnapshot.amount, u256.NewUint(duration)))
		}
		lastSnapshot = snapshot
	}

	if lastSnapshot.timestamp < timestamp {
		duration := timestamp - lastSnapshot.timestamp
		cumulativeAmount.Add(&cumulativeAmount, u256.Zero().Mul(lastSnapshot.amount, u256.NewUint(duration)))
	}

	return cumulativeAmount.ToString(), nil
}

// GetAverageDelegated calculates the average delegated amount for a delegate over a given period
func GetAverageDelegated(delegate string, start, end uint64) (string, error) {
	delegateAddr := std.Address(delegate)
	if !delegateAddr.IsValid() {
		panic(ufmt.Sprintf("invalid address: %s", delegate))
	}

	res := u256.Zero()

	if start > end {
		panic(ErrInvalidTimeRange)
	}

	history, exists := gStaker.delegationHistory[delegateAddr]
	if !exists || len(history) == 0 {
		return res.ToString(), nil
	}

	if start >= history[len(history)-1].timestamp {
		res = history[len(history)-1].amount.Clone()
		return res.ToString(), nil
	}

	if end <= history[0].timestamp {
		return res.ToString(), nil
	}

	var (
		totalAmount   u256.Uint
		lastAmount    *u256.Uint
		lastTimestamp uint64
	)

	for i, record := range history {
		if record.timestamp > end {
			break
		}

		if i == 0 {
			if record.timestamp > start {
				totalAmount.Add(&totalAmount, u256.Zero().Mul(record.amount, u256.NewUint(record.timestamp-start)))
			}
		} else {
			if record.timestamp > start {
				duration := record.timestamp - maxUint64(start, lastTimestamp)
				totalAmount.Add(&totalAmount, u256.Zero().Mul(lastAmount, u256.NewUint(duration)))
			}
		}

		lastAmount = record.amount
		lastTimestamp = record.timestamp
	}

	if lastTimestamp < end {
		duration := end - maxUint64(start, lastTimestamp)
		totalAmount.Add(&totalAmount, u256.Zero().Mul(lastAmount, u256.NewUint(duration)))
	}

	totalDuration := end - start
	if totalDuration == 0 {
		res = lastAmount.Clone()
		return res.ToString(), nil
	}

	res = u256.Zero().Div(&totalAmount, u256.NewUint(totalDuration))
	return res.ToString(), nil
}

// GetAverageDelegatedOverLast gets the average amount delegated over the last period seconds.
func GetAverageDelegatedOverLast(delegate string, period uint64) (string, error) {
	now := uint64(time.Now().Unix())
	return GetAverageDelegated(delegate, now-period, now)
}

// GetCurrentDelegated returns the current delegated amount for a delegate
func GetCurrentDelegated(delegate string) (string, error) {
	res := u256.Zero()
	history, exists := gStaker.delegationHistory[std.Address(delegate)]
	if !exists || len(history) == 0 {
		return res.ToString(), nil
	}

	lastEntry := history[len(history)-1]
	res = lastEntry.amount.Clone()
	return res.ToString(), nil
}

// GetDelegatedAt returns the delegated amount for a delegate at a specific timestamp.
func GetDelegatedAt(delegate string, timestamp uint64) (string, error) {
	delegateAddr := std.Address(delegate)
	if !delegateAddr.IsValid() {
		panic(ufmt.Sprintf("invalid address: %s", delegate))
	}

	res := u256.Zero()
	history, exists := gStaker.delegationHistory[delegateAddr]
	if !exists || len(history) == 0 {
		return res.ToString(), nil
	}

	for i := len(history) - 1; i >= 0; i-- {
		if history[i].timestamp <= timestamp {
			res = history[i].amount.Clone()
			return res.ToString(), nil
		}
	}

	return res.ToString(), nil
}

func maxUint64(a, b uint64) uint64 {
	if a > b {
		return a
	}
	return b
}
*/

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func checkErr(err error) {
	if err != nil {
		panic(err.Error())
	}
}

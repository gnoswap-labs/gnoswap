package launchpad

import "gno.land/r/gnoswap/launchpad"

// withdrawDeposit marks a deposit withdrawn, clears its remaining amount, and returns
// the amount that was previously staked.
//
// Parameters:
//   - d: deposit to mark withdrawn.
//   - currentHeight: block height at which withdrawal occurs.
//   - currentTime: Unix timestamp at which withdrawal occurs.
//
// Returns:
//   - deposit: updated deposit with withdrawal metadata and zero remaining amount.
//   - amount: GNS amount held before it was cleared.
func withdrawDeposit(d launchpad.Deposit, currentHeight, currentTime int64) (launchpad.Deposit, int64) {
	d.SetWithdrawn(currentHeight, currentTime)

	previousDepositAmount := d.DepositAmount()
	d.SetDepositAmount(0)

	return d, previousDepositAmount
}

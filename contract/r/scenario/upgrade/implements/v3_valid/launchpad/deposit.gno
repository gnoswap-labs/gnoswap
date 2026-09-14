package v3_valid

import "gno.land/r/gnoswap/launchpad"

func withdrawDeposit(d launchpad.Deposit, currentHeight, currentTime int64) (launchpad.Deposit, int64) {
	d.SetWithdrawn(currentHeight, currentTime)

	previousDepositAmount := d.DepositAmount()
	d.SetDepositAmount(0)

	return d, previousDepositAmount
}

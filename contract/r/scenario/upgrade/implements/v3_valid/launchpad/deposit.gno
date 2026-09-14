package v3_valid

import "gno.land/r/gnoswap/launchpad"

func withdrawDeposit(d *launchpad.Deposit, currentHeight, currentTime int64) int64 {
	d.SetWithdrawn(currentHeight, currentTime)

	previousDepositAmount := d.DepositAmount()
	d.SetDepositAmount(0)

	return previousDepositAmount
}

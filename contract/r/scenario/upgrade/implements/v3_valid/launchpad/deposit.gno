package v3

import "gno.land/r/gnoswap/launchpad"

func withdrawDeposit(d *launchpad.Deposit, currentHeight, currentTime int64) int64 {
	d.SetWithdrawn(currentHeight, currentTime)

	previousDepositAmount := d.DepositAmount()
	d.SetDepositAmount(0)

	return previousDepositAmount
}

func newDeposit(
	depositID string,
	projectID string,
	tier int64,
	depositor address,
	depositAmount int64,
	createdHeight int64,
	createdTime int64,
	endTime int64,
) *launchpad.Deposit {
	return launchpad.NewDeposit(
		depositID,
		projectID,
		tier,
		depositor,
		depositAmount,
		createdHeight,
		createdTime,
		endTime,
	)
}

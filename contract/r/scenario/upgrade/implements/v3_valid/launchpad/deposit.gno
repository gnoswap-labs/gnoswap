package v3

import (
	"chain/runtime"

	"gno.land/r/gnoswap/launchpad"
)

func withdrawDeposit(d *launchpad.Deposit, currentTime int64) int64 {
	d.SetWithdrawn(runtime.ChainHeight(), currentTime)

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

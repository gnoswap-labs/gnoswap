package v1

import "gno.land/r/gnoswap/launchpad"

// ApiGetDepositByDepositId retrieves deposit information by deposit ID.
func (lp *launchpadV1) ApiGetDepositByDepositId(depositId string) string {
	deposits := lp.store.GetDeposits()
	deposit, exist := deposits.Get(depositId)
	if !exist {
		return ""
	}

	builder := metaBuilder()
	d, ok := deposit.(*launchpad.Deposit)
	if !ok {
		panic("failed to cast deposit to *launchpad.Deposit")
	}
	depositBuilder(builder, d)

	return marshal(builder.Node())
}

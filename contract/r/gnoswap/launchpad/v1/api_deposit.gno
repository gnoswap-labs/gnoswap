package v1

// ApiGetDepositByDepositId retrieves deposit information by deposit ID.
func (lp *launchpadV1) ApiGetDepositByDepositId(depositId string) string {
	deposits := lp.store.GetDeposits()
	deposit, exist := deposits.Get(depositId)
	if !exist {
		return ""
	}

	builder := metaBuilder()
	d, ok := deposit.(*Deposit)
	if !ok {
		panic("failed to cast deposit to *Deposit")
	}
	depositBuilder(builder, d)

	return marshal(builder.Node())
}

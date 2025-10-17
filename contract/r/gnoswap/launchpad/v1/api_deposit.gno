package v1

// ApiGetDepositByDepositId retrieves deposit information by deposit ID.
func (lp *launchpadV1) ApiGetDepositByDepositId(depositId string) string {
	state := lp.getLaunchpadState()
	deposit, exist := state.deposits.Get(depositId)
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

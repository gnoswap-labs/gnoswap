package launchpad

// ApiGetDepositByDepositId retrieves deposit information by deposit ID.
func ApiGetDepositByDepositId(depositId string) string {
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

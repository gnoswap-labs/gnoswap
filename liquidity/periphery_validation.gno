package liquidity

func checkDeadline(deadline bigint) {
	require(GetTimestamp() <= deadline, "Transaction too old")
}
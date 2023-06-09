package position

func checkDeadline(deadline bigint) {
	require(GetTimestamp() <= deadline, "Transaction too old")
}
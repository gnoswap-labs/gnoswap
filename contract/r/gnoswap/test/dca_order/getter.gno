package dca_order

// GetOrderJSON returns an order as a JSON object, or "" when it does not exist.
// The object includes the currently claimable output and executed rounds.
func GetOrderJSON(orderID uint64) string {
	return getImplementation().GetOrderJSON(orderID)
}

// GetGroupJSON returns a group as a JSON object, or "" when it does not exist.
func GetGroupJSON(groupID string) string {
	return getImplementation().GetGroupJSON(groupID)
}

// GetConfigJSON returns the DCA configuration as a JSON object.
func GetConfigJSON() string {
	return getImplementation().GetConfigJSON()
}

// GetClaimable returns the output currently claimable by an order.
func GetClaimable(orderID uint64) int64 {
	return getImplementation().GetClaimable(orderID)
}

// GetPendingFee returns prepaid creation fees held for a token.
func GetPendingFee(tokenPath string) int64 {
	return getImplementation().GetPendingFee(tokenPath)
}

// GetGroupIDs returns comma-separated group IDs in key order.
func GetGroupIDs(offset int, count int) string {
	return getImplementation().GetGroupIDs(offset, count)
}

// GetExecutableGroups returns up to count groups whose next round can execute
// at the current block time, oldest due first, as comma-separated
// "<nextExecutionAt>|<groupID>" entries. Pass the last entry back as cursor
// ("" starts from the oldest) until fewer than count entries come back. The
// cursor is a fixed schedule position, so groups executed between pages do
// not shift it.
func GetExecutableGroups(cursor string, count int) string {
	return getImplementation().GetExecutableGroups(cursor, count)
}

// GetOrderIDsByOwner returns up to count comma-separated order IDs owned by
// an address, ascending and strictly greater than startAfterID (0 = from the
// first order). Page by passing the last returned ID.
func GetOrderIDsByOwner(owner address, startAfterID uint64, count int) string {
	return getImplementation().GetOrderIDsByOwner(owner, startAfterID, count)
}

package referral

// gReferralKeeper is the global instance of the referral keeper
var gReferralKeeper ReferralKeeper

func init() {
	gReferralKeeper = NewKeeper()
}

// GetKeeper returns the global instance of the referral keeper
//
// Example:
//
//	// In other packages:
//	keeper := referral.GetKeeper()
//	keeper.register(addr, refAddr)
func GetKeeper() ReferralKeeper {
	return gReferralKeeper
}

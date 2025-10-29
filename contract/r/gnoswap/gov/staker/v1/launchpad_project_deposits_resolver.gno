package v1

import (
	"gno.land/r/gnoswap/gov/staker"
)

type LaunchpadProjectDepositsResolver struct {
	*staker.LaunchpadProjectDeposits
}

func NewLaunchpadProjectDepositsResolver(launchpadProjectDeposits *staker.LaunchpadProjectDeposits) *LaunchpadProjectDepositsResolver {
	return &LaunchpadProjectDepositsResolver{launchpadProjectDeposits}
}

// getLaunchpadProjectDeposit retrieves the deposit amount for a launchpad project.
//
// Parameters:
//   - ownerAddress: project owner's address identifier
//
// Returns:
//   - int64: deposit amount
//   - bool: true if project exists, false otherwise
func (lpdr *LaunchpadProjectDepositsResolver) getLaunchpadProjectDeposit(ownerAddress string) (int64, bool) {
	return lpdr.GetDeposit(ownerAddress)
}

// setLaunchpadProjectDeposit sets the deposit amount for a launchpad project.
//
// Parameters:
//   - ownerAddress: project owner's address identifier
//   - deposit: deposit amount to set
//
// Returns:
//   - bool: true if successfully set
func (lpdr *LaunchpadProjectDepositsResolver) setLaunchpadProjectDeposit(ownerAddress string, deposit int64) bool {
	lpdr.SetDeposit(ownerAddress, deposit)
	return true
}

// addDeposit adds to the deposit amount for a launchpad project.
// This method ensures the deposit doesn't go negative.
//
// Parameters:
//   - ownerAddress: project owner's address identifier
//   - amount: amount to add to the deposit
func (lpdr *LaunchpadProjectDepositsResolver) addDeposit(ownerAddress string, amount int64) {
	currentDeposit, _ := lpdr.GetDeposit(ownerAddress)
	newDeposit := currentDeposit + amount
	if newDeposit < 0 {
		newDeposit = 0
	}
	lpdr.SetDeposit(ownerAddress, newDeposit)
}

// removeDeposit removes from the deposit amount for a launchpad project.
// This method ensures the deposit doesn't go negative.
//
// Parameters:
//   - ownerAddress: project owner's address identifier
//   - amount: amount to remove from the deposit
func (lpdr *LaunchpadProjectDepositsResolver) removeDeposit(ownerAddress string, amount int64) {
	currentDeposit, _ := lpdr.GetDeposit(ownerAddress)
	newDeposit := currentDeposit - amount
	if newDeposit < 0 {
		newDeposit = 0
	}
	lpdr.SetDeposit(ownerAddress, newDeposit)
}
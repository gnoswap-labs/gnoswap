package xgns

import (
	"errors"

	"gno.land/p/demo/tokens/grc20"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
)

func GetAdmin() address               { return admin.Owner() }
func GetToken() *grc20.Token          { return token }
func GetTotalSupply() int64           { return TotalSupply() }
func GetBalanceOf(addr address) int64 { return token.BalanceOf(addr) }

func GetVotingSupply() (int64, error) {
	launchpad, err := getLaunchpadAddress()
	if err != nil {
		return 0, err
	}

	return token.TotalSupply() - token.BalanceOf(launchpad), nil
}

func getLaunchpadAddress() (address, error) {
	launchpad, ok := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	if !ok {
		return "", errors.New("launchpad address not found")
	}
	return launchpad, nil
}

// SupplyInfo returns supply breakdown information.
//
// Returns:
//   - totalIssued: total xGNS tokens issued
//   - issuedByDelegate: tokens issued through governance delegation
//   - issuedByDepositGns: tokens issued through launchpad deposit
//   - error: error if launchpad address not found
func SupplyInfo() (totalIssued, issuedByDelegate, issuedByDepositGns int64, err error) {
	launchpad, err := getLaunchpadAddress()
	if err != nil {
		return 0, 0, 0, err
	}

	totalIssued = token.TotalSupply()
	issuedByDepositGns = token.BalanceOf(launchpad)
	issuedByDelegate = totalIssued - issuedByDepositGns

	return totalIssued, issuedByDelegate, issuedByDepositGns, nil
}

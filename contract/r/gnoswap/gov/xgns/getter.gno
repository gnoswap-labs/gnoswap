package xgns

import (
    "errors"

    "gno.land/p/demo/tokens/grc20"

    prbac "gno.land/p/gnoswap/rbac"

    "gno.land/r/gnoswap/access"
)

func GetAdmin() address {
    return admin.Owner()
}

func GetToken() *grc20.Token {
    return token
}

func GetTotalSupply() int64 {
    return TotalSupply()
}

func GetBalanceOf(addr address) int64 {
    return token.BalanceOf(addr)
}

func GetVotingSupply() (int64, error) {
	launchpad, ok := access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	if !ok {
		return 0, errors.New("launchpad address not found")
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

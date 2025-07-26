package staker

import (
	"std"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/v1/gnft"
)

func assertIsDepositor(caller std.Address, positionId uint64) {
	deposit := deposits.get(positionId)
	if deposit == nil {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("positionId(%d) not found", positionId),
		))
	}

	if caller != deposit.owner {
		panic(makeErrorWithDetails(
			errNoPermission,
			ufmt.Sprintf("caller(%s) is not depositor(%s)", caller.String(), deposit.owner.String()),
		))
	}
}

func assertIsNotStaked(positionId uint64) {
	if deposits.Has(positionId) {
		panic(makeErrorWithDetails(
			errAlreadyStaked,
			ufmt.Sprintf("positionId(%d) already staked", positionId),	
		))
	}
}

func assertIsPositionOwner(positionId uint64, caller std.Address) {
	owner := gnft.MustOwnerOf(positionIdFrom(positionId))
	if owner != caller {
		panic(makeErrorWithDetails(
			errNoPermission,
			ufmt.Sprintf("caller(%s) is not owner(%s)", caller.String(), owner.String()),
		))
	}
}
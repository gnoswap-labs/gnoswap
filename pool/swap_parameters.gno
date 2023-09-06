package gnoswap

import (
	gov "gno.land/r/gov"
)

func SubmitProposalParameterProtocolFees(
	title string,
	summary string,
	metadata string,
	initialDeposit uint64,

	newFee0 bigint,
	newFee1 bigint,
) uint64 {
	require(
		(newFee0 == 0 || (newFee0 >= 4 && newFee0 <= 10)) && (newFee1 == 0 || (newFee1 >= 4 && newFee1 <= 10)),
		"Invalid fee protocol",
	)

	changes := []gov.ParameterChange{
		{
			Key:   "protocol_fees",
			Value: newFee0 + (newFee1 << 4),
		},
	}

	return gov.SubmitProposalParameterChanges(
		title,
		summary,
		metadata,
		initialDeposit,
		changes,
	)
}

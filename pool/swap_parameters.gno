package pool

import (
	"gno.land/p/demo/ufmt"

	gov "gno.land/r/demo/gov"
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
		ufmt.Sprintf(
			"[POOL] pool.gno__SubmitProposalParameterProtocolFees() || expected (newFee0(%d) == 0 || (newFee0(%d) >= 4 && newFee0(%d) <= 10)) && (newFee1(%d) == 0 || (newFee1(%d) >= 4 && newFee1(%d) <= 10))",
			newFee0, newFee0, newFee0, newFee1, newFee1, newFee1,
		),
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

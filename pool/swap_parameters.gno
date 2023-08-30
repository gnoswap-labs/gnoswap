package gnoswap

import (
	"gno.land/r/gov"
)

func getProtocolFees() ProtocolFees {
	param, ok := gov.GetParameter("protocol_fees")
	require(ok, "[POOL] swap_parameters.gno__getProtocolFees() || protocol fees not set")

	return param.(ProtocolFees)
}

/*
// @mconcat
func setProtocolFees(newFees ProtocolFees) {
	gov.SetParameter("protocol_fees", newFees)
}

func SubmitProposalParameterProtocolFees(
	title string,
	summary string,
	newFees ProtocolFees,
) uint64 {
	return gov.SubmitProposalParameterChange(
		title,
		summary,
		"protocol_fees",
		newFees,
	)
}
*/

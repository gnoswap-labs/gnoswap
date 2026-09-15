package emission

import (
	"strings"
	"time"

	"gno.land/p/gnoswap/utils/v1"
	"gno.land/p/moul/md/v0"
	"gno.land/p/moul/mdtable/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

const gnsDisplayScale uint64 = 1_000_000

// Render returns the current GNS emission and distribution state.
func Render(path string) string {
	if path != "" {
		return "404\n"
	}

	out := md.H1("GNS Emission") +
		"\n" +
		md.Paragraph("All GNS amounts use exactly six decimal places. Schedule timestamps are UTC.")

	scheduleTable := mdtable.Table{
		Headers: []string{"Field", "Value"},
		Rows: [][]string{
			{"Distribution start", formatEmissionTimestamp(GetDistributionStartTimestamp(), "Not started")},
			{"Distribution end", formatEmissionTimestamp(GetDistributionEndTimestamp(), "Not scheduled")},
			{"Last execution", formatEmissionTimestamp(GetLastExecutedTimestamp(), "Not yet executed")},
		},
	}
	out += md.H2("Distribution schedule") +
		"\n" +
		scheduleTable.String() +
		"\n"

	accountingTable := mdtable.Table{
		Headers: []string{"Metric", "Amount"},
		Rows: [][]string{
			{"Undistributed GNS", formatGnsAmount(GetLeftGNSAmount())},
			{"Total cumulative distributed", formatGnsAmount(GetTotalAccuDistributed())},
		},
	}
	out += md.H2("Distribution accounting") +
		"\n" +
		accountingTable.String() +
		"\n" +
		md.Paragraph(
			"The cumulative total includes allocations sent to all four recipients;\n"+
				"DevOps and community-pool rows represent completed direct-transfer accounting.",
		)

	recipientsTable := mdtable.Table{
		Headers: []string{"Recipient", "Allocation", "Cumulative distributed"},
		Rows: [][]string{
			{"Liquidity stakers", formatDistributionPercent(distributionBpsPct[LIQUIDITY_STAKER]), formatGnsAmount(GetAccuDistributedToStaker())},
			{"DevOps", formatDistributionPercent(distributionBpsPct[DEVOPS]), formatGnsAmount(GetAccuDistributedToDevOps())},
			{"Community pool", formatDistributionPercent(distributionBpsPct[COMMUNITY_POOL]), formatGnsAmount(GetAccuDistributedToCommunityPool())},
			{"Governance stakers", formatDistributionPercent(distributionBpsPct[GOV_STAKER]), formatGnsAmount(GetAccuDistributedToGovStaker())},
		},
	}
	out += md.H2("Recipients") +
		"\n" +
		recipientsTable.String() +
		"\n"

	stakingTable := mdtable.Table{
		Headers: []string{"Recipient", "Since last accounting clear"},
		Rows: [][]string{
			{"Liquidity stakers", formatGnsAmount(GetDistributedToStaker())},
			{"Governance stakers", formatGnsAmount(GetDistributedToGovStaker())},
		},
	}
	out += md.H2("Staking accounting") +
		"\n" +
		md.Paragraph(
			"These allocations have already been transferred to the recipients.\n"+
				"The counters below show amounts since each accounting contract's last clear; they\n"+
				"are not wallet balances or claimable amounts.",
		) +
		stakingTable.String()

	return out
}

func formatEmissionTimestamp(timestamp int64, zeroLabel string) string {
	if timestamp == 0 {
		return zeroLabel
	}

	return time.Unix(timestamp, 0).UTC().Format(time.RFC3339)
}

func formatGnsAmount(amount int64) string {
	sign := ""
	magnitude := uint64(amount)
	if amount < 0 {
		sign = "-"
		// Avoid overflowing when formatting the smallest int64 value.
		magnitude = uint64(-(amount + 1)) + 1
	}

	whole := magnitude / gnsDisplayScale
	fraction := magnitude % gnsDisplayScale
	return ufmt.Sprintf("%s%d.%s GNS", sign, whole, zeroPadUnsigned(fraction, 6))
}

func formatDistributionPercent(bps int64) string {
	sign := ""
	magnitude := uint64(bps)
	if bps < 0 {
		sign = "-"
		magnitude = uint64(-(bps + 1)) + 1
	}

	whole := magnitude / 100
	fraction := magnitude % 100
	return ufmt.Sprintf("%s%d.%s%%", sign, whole, zeroPadUnsigned(fraction, 2))
}

func zeroPadUnsigned(value uint64, width int) string {
	valueString := utils.FormatUint(value)
	padding := width - len(valueString)
	if padding <= 0 {
		return valueString
	}

	return strings.Repeat("0", padding) + valueString
}

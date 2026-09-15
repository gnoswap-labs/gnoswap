package emission

import (
	"strings"
	"time"

	"gno.land/p/gnoswap/utils"
	ufmt "gno.land/p/nt/ufmt/v0"
)

const gnsDisplayScale uint64 = 1_000_000

// Render returns the current GNS emission and distribution state.
func Render(path string) string {
	if path != "" {
		return "404\n"
	}

	return ufmt.Sprintf(`# GNS Emission

All GNS amounts use exactly six decimal places. Schedule timestamps are UTC.

## Distribution schedule

| Field | Value |
| --- | --- |
| Distribution start | %s |
| Distribution end | %s |
| Last execution | %s |

## Distribution accounting

| Metric | Amount |
| --- | ---: |
| Undistributed GNS | %s |
| Total cumulative distributed | %s |

The cumulative total includes allocations sent to all four recipients;
DevOps and community-pool rows represent completed direct-transfer accounting.

## Recipients

| Recipient | Allocation | Cumulative distributed |
| --- | ---: | ---: |
| Liquidity stakers | %s | %s |
| DevOps | %s | %s |
| Community pool | %s | %s |
| Governance stakers | %s | %s |

## Staking accounting

These allocations have already been transferred to the recipients.
The counters below show amounts since each accounting contract's last clear; they
are not wallet balances or claimable amounts.

| Recipient | Since last accounting clear |
| --- | ---: |
| Liquidity stakers | %s |
| Governance stakers | %s |
`,
		formatEmissionTimestamp(GetDistributionStartTimestamp(), "Not started"),
		formatEmissionTimestamp(GetDistributionEndTimestamp(), "Not scheduled"),
		formatEmissionTimestamp(GetLastExecutedTimestamp(), "Not yet executed"),
		formatGnsAmount(GetLeftGNSAmount()),
		formatGnsAmount(GetTotalAccuDistributed()),
		formatDistributionPercent(distributionBpsPct[LIQUIDITY_STAKER]),
		formatGnsAmount(GetAccuDistributedToStaker()),
		formatDistributionPercent(distributionBpsPct[DEVOPS]),
		formatGnsAmount(GetAccuDistributedToDevOps()),
		formatDistributionPercent(distributionBpsPct[COMMUNITY_POOL]),
		formatGnsAmount(GetAccuDistributedToCommunityPool()),
		formatDistributionPercent(distributionBpsPct[GOV_STAKER]),
		formatGnsAmount(GetAccuDistributedToGovStaker()),
		formatGnsAmount(GetDistributedToStaker()),
		formatGnsAmount(GetDistributedToGovStaker()),
	)
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

package referral

import (
	"strings"
	"time"

	"gno.land/p/moul/md/v0"
	"gno.land/p/moul/mdtable/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

// Render describes referral registration or shows the referral for an address.
func Render(path string) string {
	if path == "" {
		table := mdtable.Table{
			Headers: []string{"Rule", "Value"},
			Rows: [][]string{
				{"Minimum interval between registrations or updates", ufmt.Sprintf("%d hours", MinTimeBetweenUpdates/3600)},
			},
		}

		return md.H1("Gnoswap Referrals") +
			"\n" +
			md.Paragraph("Authorized protocol contracts register a referrer for each address.") +
			md.H2("Registration") +
			"\n" +
			table.String() +
			"\n" +
			md.Paragraph(
				"Removing a referral bypasses the interval but does not reset the last registration time.\n"+
					"Address-specific records are available at "+md.InlineCode("address/<address>")+".",
			)
	}

	parts := strings.Split(path, "/")
	if len(parts) != 2 || parts[0] != "address" || parts[1] == "" {
		return "404\n"
	}

	addr := parts[1]
	if !HasReferral(addr) {
		return "404\n"
	}

	lastOpTimestamp, err := GetLastOpTimestamp(addr)
	if err != nil {
		return "404\n"
	}

	table := mdtable.Table{
		Headers: []string{"Field", "Value"},
		Rows: [][]string{
			{"Address", addr},
			{"Referrer", GetReferral(addr)},
			{"Last registration or update (UTC)", time.Unix(lastOpTimestamp, 0).UTC().Format("2006-01-02 15:04:05")},
		},
	}

	return md.H1("Gnoswap Referral") +
		"\n" +
		md.H2("Referral record") +
		"\n" +
		table.String()
}

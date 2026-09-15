package referral

import (
	"strings"
	"time"

	ufmt "gno.land/p/nt/ufmt/v0"
)

// Render describes referral registration or shows the referral for an address.
func Render(path string) string {
	if path == "" {
		return ufmt.Sprintf(`# Gnoswap Referrals

Authorized protocol contracts register a referrer for each address.

## Registration

| Rule | Value |
| --- | --- |
| Minimum interval between registrations or updates | %d hours |

Removing a referral bypasses the interval but does not reset the last registration time.
Address-specific records are available at `+"`referral/<address>`"+`.
`, MinTimeBetweenUpdates/3600)
	}

	parts := strings.Split(path, "/")
	if len(parts) != 2 || parts[0] != "referral" || parts[1] == "" {
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

	return ufmt.Sprintf(`# Gnoswap Referral

## Referral record

| Field | Value |
| --- | --- |
| Address | %s |
| Referrer | %s |
| Last registration or update (UTC) | %s |
`, addr, GetReferral(addr), time.Unix(lastOpTimestamp, 0).UTC().Format("2006-01-02 15:04:05"))
}

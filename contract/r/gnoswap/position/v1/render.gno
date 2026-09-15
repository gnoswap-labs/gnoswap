package position

import (
	"chain"
	"strconv"
	"strings"

	"gno.land/p/moul/md/v0"
	"gno.land/p/moul/mdtable/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/halt/v1"
	positionRoot "gno.land/r/gnoswap/position"
)

func (p *positionV1) Render(path string) string {
	if path == "" {
		return p.renderSummary()
	}

	positionID, ok := parsePositionRenderPath(path)
	if !ok {
		return "404\n"
	}

	storedPosition, exists := p.store.GetPosition(positionID)
	if !exists {
		return "404\n"
	}

	return p.renderPositionDetail(positionID, storedPosition)
}

func (p *positionV1) renderSummary() string {
	out := md.H1("Gnoswap Position")
	out += md.Paragraph(
		"Position records remain stored after burning. The record count includes burned " +
			"positions and is not a count of active liquidity positions. Use " +
			md.InlineCode("position/<id>") + " for one stored record, for example " +
			md.Link("position/1", "/r/gnoswap/position:position/1") +
			". The detail route performs one keyed lookup and does not enumerate positions or recompute claimable values.",
	)
	runtimeTable := mdtable.Table{
		Headers: []string{"Field", "Value"},
		Rows: [][]string{
			{"Realm address", md.InlineCode(chain.PackageAddress("gno.land/r/gnoswap/position").String())},
			{"Active implementation", renderPackageLink(positionRoot.GetImplementationPackagePath())},
			{"Position operations halted", ufmt.Sprintf("%t", halt.IsHaltedPosition())},
			{"Withdrawals halted", ufmt.Sprintf("%t", halt.IsHaltedWithdraw())},
		},
	}
	out += md.H2("Runtime") + runtimeTable.String()

	records := mdtable.Table{
		Headers: []string{"Field", "Value"},
		Rows: [][]string{
			{"Stored position records (including burned)", ufmt.Sprintf("%d", p.store.GetPositions().Size())},
			{"Next position ID", ufmt.Sprintf("%d", p.store.GetPositionNextID())},
		},
	}
	return out + md.H2("Stored records") + records.String()
}

func (p *positionV1) renderPositionDetail(positionID uint64, stored positionRoot.Position) string {
	status := "Active"
	if stored.Burned() {
		status = "Burned (record retained)"
	}

	owner := "unavailable"
	ownerAddress, err := p.nftAccessor.OwnerOf(positionIdFrom(positionID))
	if err == nil && ownerAddress != "" {
		owner = ownerAddress.String()
	}

	token0, token1, poolFee, validPoolKey := splitPoolKeyForRender(stored.PoolKey())
	token0Reference := "unavailable (stored pool key is not token0:token1:fee)"
	token1Reference := token0Reference
	if validPoolKey {
		token0Reference = renderPackageLink(token0)
		token1Reference = renderPackageLink(token1)
	}

	out := md.H1(ufmt.Sprintf("Gnoswap Position %d", positionID))
	out += md.Paragraph(
		"This page reads one persisted position record. Stored accounting fields are " +
			"shown as stored; claimable fees and current token balances are recomputed " +
			"values and are intentionally not queried here.",
	)
	identity := mdtable.Table{
		Headers: []string{"Field", "Value"},
		Rows: [][]string{
			{"Position ID", ufmt.Sprintf("%d", positionID)},
			{"Status", status},
			{"Owner", owner},
		},
	}
	out += md.H2("Identity") + identity.String()

	poolAndRange := mdtable.Table{
		Headers: []string{"Field", "Value"},
		Rows: [][]string{
			{"Pool key", md.InlineCode(stored.PoolKey())},
			{"Token 0 reference", token0Reference},
			{"Token 1 reference", token1Reference},
			{"Pool fee (from stored key)", poolFee},
			{"Lower tick (stored)", ufmt.Sprintf("%d", stored.TickLower())},
			{"Upper tick (stored)", ufmt.Sprintf("%d", stored.TickUpper())},
		},
	}
	out += md.H2("Pool and range") + poolAndRange.String()

	accounting := mdtable.Table{
		Headers: []string{"Field", "Value"},
		Rows: [][]string{
			{"Liquidity (stored)", stored.Liquidity()},
			{"Fee growth token 0 inside, last X128 (stored)", stored.FeeGrowthInside0LastX128()},
			{"Fee growth token 1 inside, last X128 (stored)", stored.FeeGrowthInside1LastX128()},
			{"Token 0 owed (stored accounting)", ufmt.Sprintf("%d", stored.TokensOwed0())},
			{"Token 1 owed (stored accounting)", ufmt.Sprintf("%d", stored.TokensOwed1())},
			{"Claimable fees / current token balances", "Not rendered; would require recomputation"},
		},
	}
	return out + md.H2("Stored accounting") + accounting.String()
}

func parsePositionRenderPath(path string) (uint64, bool) {
	const prefix = "position/"
	if len(path) <= len(prefix) || path[:len(prefix)] != prefix {
		return 0, false
	}

	id := path[len(prefix):]
	for i := 0; i < len(id); i++ {
		if id[i] < '0' || id[i] > '9' {
			return 0, false
		}
	}

	positionID, err := strconv.ParseUint(id, 10, 64)
	if err != nil {
		return 0, false
	}

	return positionID, true
}

func splitPoolKeyForRender(poolKey string) (string, string, string, bool) {
	parts := strings.Split(poolKey, ":")
	if len(parts) != 3 || parts[0] == "" || parts[1] == "" || parts[2] == "" {
		return "", "", "", false
	}

	return parts[0], parts[1], parts[2], true
}

func renderPackageLink(path string) string {
	if strings.HasPrefix(path, "gno.land/") {
		destination := strings.TrimPrefix(path, "gno.land")
		// Token references append .SYMBOL; link to the defining realm.
		if separator := strings.Index(destination, "."); separator >= 0 {
			destination = destination[:separator]
		}
		return md.Link(path, destination)
	}

	return md.InlineCode(path)
}

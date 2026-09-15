package position

import (
	"chain"
	"strconv"
	"strings"

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
	return ufmt.Sprintf(
		`# Gnoswap Position

Position records remain stored after burning. The record count includes burned
positions and is not a count of active liquidity positions. Use
`+"`position/<id>`"+` for one stored record, for example
[`+"`position/1`"+`](/r/gnoswap/position:position/1). The detail route performs one keyed
lookup and does not enumerate positions or recompute claimable values.

## Runtime

| Field | Value |
| --- | --- |
| Realm address | `+"`%s`"+` |
| Active implementation | %s |
| Position operations halted | %t |
| Withdrawals halted | %t |

## Stored records

| Field | Value |
| --- | --- |
| Stored position records (including burned) | %d |
| Next position ID | %d |
`,
		chain.PackageAddress("gno.land/r/gnoswap/position"),
		renderPackageLink(positionRoot.GetImplementationPackagePath()),
		halt.IsHaltedPosition(),
		halt.IsHaltedWithdraw(),
		p.store.GetPositions().Size(),
		p.store.GetPositionNextID(),
	)
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

	return ufmt.Sprintf(
		`# Gnoswap Position %d

This page reads one persisted position record. Stored accounting fields are
shown as stored; claimable fees and current token balances are recomputed
values and are intentionally not queried here.

## Identity

| Field | Value |
| --- | --- |
| Position ID | %d |
| Status | %s |
| Owner | %s |

## Pool and range

| Field | Value |
| --- | --- |
| Pool key | `+"`%s`"+` |
| Token 0 reference | %s |
| Token 1 reference | %s |
| Pool fee (from stored key) | %s |
| Lower tick (stored) | %d |
| Upper tick (stored) | %d |

## Stored accounting

| Field | Value |
| --- | --- |
| Liquidity (stored) | %s |
| Fee growth token 0 inside, last X128 (stored) | %s |
| Fee growth token 1 inside, last X128 (stored) | %s |
| Token 0 owed (stored accounting) | %d |
| Token 1 owed (stored accounting) | %d |
| Claimable fees / current token balances | Not rendered; would require recomputation |
`,
		positionID,
		positionID,
		status,
		owner,
		stored.PoolKey(),
		token0Reference,
		token1Reference,
		poolFee,
		stored.TickLower(),
		stored.TickUpper(),
		stored.Liquidity(),
		stored.FeeGrowthInside0LastX128(),
		stored.FeeGrowthInside1LastX128(),
		stored.TokensOwed0(),
		stored.TokensOwed1(),
	)
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
		return ufmt.Sprintf("[%s](%s)", path, destination)
	}

	return "`" + path + "`"
}

package position

import (
	"strconv"
	"strings"

	prabc "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/grc721/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/access"
	pl "gno.land/r/gnoswap/pool"
)

const MAX_UINT256 string = "115792089237316195423570985008687907853269984665640564039457584007913129639935"

func mustGetStakerAddress() address {
	return access.MustGetAddress(prabc.ROLE_STAKER.String())
}

// mustGetPool returns the read-only snapshot for poolPath.
// It panics when poolPath does not identify a pool.
//
// Parameters:
//   - poolPath: pool identifier whose stored pool snapshot is requested
//
// Returns:
//   - pool: read-only pool snapshot associated with poolPath
func mustGetPool(poolPath string) *pl.Pool {
	pool, ok := pl.GetPools().Get(poolPath).(*pl.Pool)
	if !ok || pool == nil {
		panic(ufmt.Sprintf("expected poolPath(%s) to exist", poolPath))
	}
	return pool
}

// positionIdFrom converts a numeric position ID to the decimal token ID used
// by the position NFT ledger.
//
// Parameters:
//   - positionId: numeric position identifier to encode
//
// Returns:
//   - tid: decimal-string GRC721 token ID corresponding to positionId
func positionIdFrom(positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.FormatUint(positionId, 10))
}

// exists reports whether the position NFT ledger contains positionId.
//
// Parameters:
//   - positionId: numeric position identifier to test
//
// Returns:
//   - exists: true when the corresponding position NFT exists
func (p *positionV1) exists(positionId uint64) bool {
	return p.nftAccessor.Exists(positionIdFrom(positionId))
}

// isOwner reports whether addr owns the position NFT for positionId.
//
// Parameters:
//   - positionId: numeric position identifier whose NFT ownership is checked
//   - addr: address compared with the NFT ledger's owner
//
// Returns:
//   - owner: true when addr is the current owner; false when ownership lookup fails or the addresses differ
func (p *positionV1) isOwner(positionId uint64, addr address) bool {
	owner, err := p.nftAccessor.OwnerOf(positionIdFrom(positionId))
	if err != nil {
		return false
	}
	return owner == addr
}

// isOperator reports whether addr is the approved operator for positionId.
//
// Parameters:
//   - positionId: numeric position identifier whose operator is checked
//   - addr: address compared with the position's stored operator
//
// Returns:
//   - operator: true when the stored operator equals addr and the lookup succeeds; false on lookup error or mismatch
func (p *positionV1) isOperator(positionId uint64, addr address) bool {
	operator, err := p.GetPositionOperator(positionId)
	return err == nil && operator == addr
}

// isStaked reports whether the position NFT is currently owned by the staker contract.
//
// Parameters:
//   - positionId: GRC721 token ID whose existence and owner are checked
//
// Returns:
//   - staked: true when the token exists and its owner is the configured staker address
func (p *positionV1) isStaked(positionId grc721.TokenID) bool {
	exist := p.nftAccessor.Exists(positionId)
	if !exist {
		return false
	}
	owner, err := p.nftAccessor.OwnerOf(positionId)
	if err == nil && owner == mustGetStakerAddress() {
		return true
	}
	return false
}

// isOwnerOrOperator reports whether addr may operate on positionId.
// Staked positions accept only their configured operator; unstaked positions
// accept their NFT owner.
//
// Parameters:
//   - positionId: numeric position identifier whose authorization is checked
//   - addr: address tested as owner or approved operator
//
// Returns:
//   - authorized: true when addr passes the applicable owner/operator check; false for invalid addresses, missing tokens, lookup errors, or mismatches
func (p *positionV1) isOwnerOrOperator(positionId uint64, addr address) bool {
	if !addr.IsValid() || !p.exists(positionId) {
		return false
	}

	if p.isStaked(positionIdFrom(positionId)) {
		return p.isOperator(positionId, addr)
	}

	return p.isOwner(positionId, addr)
}

// splitOf divides a pool key into token0 path, token1 path, and fee tier.
// It panics when poolKey does not contain exactly three colon-delimited components
// or its fee component is not an integer.
//
// Parameters:
//   - poolKey: colon-delimited pool identifier in token0:token1:fee form
//
// Returns:
//   - token0Path: first token contract path from poolKey
//   - token1Path: second token contract path from poolKey
//   - fee: fee tier parsed from the third poolKey component
func splitOf(poolKey string) (string, string, uint32) {
	res := strings.Split(poolKey, ":")
	if len(res) != 3 {
		panic(newErrorWithDetail(errInvalidInput, ufmt.Sprintf("invalid poolKey(%s)", poolKey)))
	}

	pToken0, pToken1, pFeeStr := res[0], res[1], res[2]

	pFee, err := strconv.Atoi(pFeeStr)
	if err != nil {
		panic(newErrorWithDetail(errInvalidInput, ufmt.Sprintf("invalid fee(%s)", pFeeStr)))
	}

	return pToken0, pToken1, uint32(pFee)
}

func isSlippageExceeded(amount0, amount1, amount0Min, amount1Min *u256.Uint) bool {
	return !(amount0.Gte(amount0Min) && amount1.Gte(amount1Min))
}

// currentPoolObservation derives the latest stored observation from the
// Uniswap-V3-aligned Slot0 and observations surfaces.
//
// Parameters:
//   - poolPath: pool identifier whose current observation is requested
//
// Returns:
//   - tickCumulative: cumulative tick value from the latest observation
//   - secondsPerLiquidityCumulativeX128: Q128 cumulative seconds-per-liquidity value
//   - observationTimestamp: block timestamp recorded on the latest observation
//   - err: nil when the observation is read; otherwise the pool observation lookup error
func currentPoolObservation(poolPath string) (int64, string, int64, error) {
	slot0 := pl.GetSlot0(poolPath)
	observation, err := pl.GetObservationAt(poolPath, slot0.ObservationIndex())
	if err != nil {
		return 0, "", 0, err
	}

	return observation.TickCumulative(), observation.SecondsPerLiquidityCumulativeX128(), observation.BlockTimestamp(), nil
}

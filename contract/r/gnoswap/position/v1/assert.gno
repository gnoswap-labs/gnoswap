package position

import (
	"errors"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/access"
)

// assertIsNotExpired panics when deadline is earlier than the current Unix timestamp.
//
// Parameters:
//   - deadline: transaction expiration timestamp, compared with time.Now().Unix()
func assertIsNotExpired(deadline int64) {
	now := time.Now().Unix()

	if now > deadline {
		panic(makeErrorWithDetails(
			errExpired,
			ufmt.Sprintf("transaction too old, now(%d) > deadline(%d)", now, deadline),
		))
	}
}

// assertValidNumberString panics when input is empty or contains a non-decimal character.
//
// Parameters:
//   - input: signed decimal integer string; a leading minus sign is accepted
func assertValidNumberString(input string) {
	if len(input) == 0 {
		panic(newErrorWithDetail(errInvalidInput, "input is empty"))
	}

	bytes := []byte(input)
	for i, b := range bytes {
		if i == 0 && b == '-' {
			continue // Allow if the first character is a negative sign (-)
		}
		if b < '0' || b > '9' {
			panic(newErrorWithDetail(
				errInvalidInput,
				ufmt.Sprintf("input string : %s", input)))
		}
	}
}

// assertValidLiquidityAmount panics when liquidity is not a positive decimal amount.
//
// Parameters:
//   - liquidity: decimal liquidity string to parse and verify as greater than zero
func assertValidLiquidityAmount(liquidity string) {
	if u256.MustFromDecimal(liquidity).IsZero() {
		panic(newErrorWithDetail(
			errZeroLiquidity,
			ufmt.Sprintf("liquidity amount must be greater than 0, got %s", liquidity),
		))
	}
}

// assertExistsPosition panics when a position NFT ID is not present in storage.
//
// Parameters:
//   - p: position implementation used to query stored positions
//   - positionId: position NFT token ID that must exist
func assertExistsPosition(p *positionV1, positionId uint64) {
	if !p.exists(positionId) {
		panic(newErrorWithDetail(
			errPositionDoesNotExist,
			ufmt.Sprintf("position with position ID(%d) doesn't exist", positionId),
		))
	}
}

// assertIsOwnerForToken panics unless caller owns the position.
//
// Parameters:
//   - p: position implementation used to inspect ownership
//   - positionId: position NFT token ID to authorize
//   - caller: address requesting access; it must be the position owner
func assertIsOwnerForToken(p *positionV1, positionId uint64, caller address) {
	assertExistsPosition(p, positionId)

	if !p.isOwner(positionId, caller) {
		panic(newErrorWithDetail(
			errNoPermission,
			ufmt.Sprintf("caller(%s) is not owner of positionId(%d)", caller, positionId),
		))
	}
}

// assertIsOwnerOrOperatorForToken panics unless caller owns the position or is its approved operator.
//
// Parameters:
//   - p: position implementation used to inspect ownership and operator approval
//   - positionId: position NFT token ID to authorize
//   - caller: address requesting access; it must be the owner or approved operator
func assertIsOwnerOrOperatorForToken(p *positionV1, positionId uint64, caller address) {
	assertExistsPosition(p, positionId)

	if !p.isOwnerOrOperator(positionId, caller) {
		panic(newErrorWithDetail(
			errNoPermission,
			ufmt.Sprintf("caller(%s) is not owner or approved operator of positionId(%d)", caller, positionId),
		))
	}
}

// assertEqualsAddress panics unless both addresses are valid and equal.
//
// Parameters:
//   - prevAddr: first address to validate and compare
//   - otherAddr: second address to validate and compare against prevAddr
func assertEqualsAddress(prevAddr, otherAddr address) {
	access.AssertIsValidAddress(prevAddr)
	access.AssertIsValidAddress(otherAddr)

	if prevAddr != otherAddr {
		panic(newErrorWithDetail(
			errInvalidAddress,
			ufmt.Sprintf("(%s, %s)", prevAddr, otherAddr),
		))
	}
}

// assertValidOperatorAddress validates an operator address.
// Empty address is allowed for operator removal; non-empty addresses must be valid.
//
// Parameters:
//   - operator: address to approve as operator, or the zero address to remove the operator
func assertValidOperatorAddress(operator address) {
	if operator != address("") && !operator.IsValid() {
		panic(newErrorWithDetail(errInvalidAddress, ufmt.Sprintf("operator(%s)", operator)))
	}
}

// assertIsNotMintToStaker panics when mintTo is the staker role address.
//
// Parameters:
//   - mintTo: address that would receive the newly minted position NFT; the staker role address is forbidden
func assertIsNotMintToStaker(mintTo address) {
	stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())
	if mintTo == stakerAddr {
		panic(errors.New(errCannotMintToStaker))
	}
}

package position

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"
	pusers "gno.land/p/demo/users"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
	"gno.land/r/gnoswap/v1/gnft"

	u256 "gno.land/p/gnoswap/uint256"
)

// a2u converts std.Address to pusers.AddressOrName.
// pusers is a package that contains the user-related functions.
//
// Input:
//   - addr: the address to convert
//
// Output:
//   - pusers.AddressOrName: the converted address
func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

// derivePkgAddr derives the Realm address from it's pkgpath parameter
func derivePkgAddr(pkgPath string) std.Address {
	return std.DerivePkgAddr(pkgPath)
}

// getOrigPkgAddr returns the original package address.
// In position contract, original package address is the position address.
func getOrigPkgAddr() std.Address {
	return consts.POSITION_ADDR
}

// getPrevRealm returns object of the previous realm.
func getPrevRealm() std.Realm {
	return std.PrevRealm()
}

// getPrevAddr returns the address of the previous realm.
func getPrevAddr() std.Address {
	return std.PrevRealm().Addr()
}

// getPrev returns the address and package path of the previous realm.
func getPrevAsString() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}

// isUserCall returns true if the caller is a user.
func isUserCall() bool {
	return std.PrevRealm().IsUser()
}

// checkDeadline checks if the deadline is expired.
// If the deadline is expired, it panics.
// The deadline is expired if the current time is greater than the deadline.
// Input:
//   - deadline: the deadline to check
func checkDeadline(deadline int64) {
	now := time.Now().Unix()
	if now > deadline {
		panic(newErrorWithDetail(
			errExpired,
			ufmt.Sprintf("transaction too old, now(%d) > deadline(%d)", now, deadline),
		))
	}
}

func checkPositionHasClear(position Position) {
	if !position.isClear() {
		panic(newErrorWithDetail(
			errNotClear,
			ufmt.Sprintf(
				"position(%d) isn't clear(liquidity:%s, tokensOwed0:%s, tokensOwed1:%s)",
				position.poolKey, position.liquidity.ToString(), position.tokensOwed0.ToString(), position.tokensOwed1.ToString(),
			),
		))
	}
}

func assertTokenOwnership(tokenId uint64) {
	assertTokenExists(tokenId)

	// MUST BE OWNER TO INCREASE LIQUIDITY
	// can not be approved address ≈ staked position can't be modified
	owner := gnft.OwnerOf(tokenIdFrom(tokenId))
	caller := std.PrevRealm().Addr()
	assertCallerIsOwner(tokenId, owner, caller)
}

func assertTokenExists(tokenId uint64) {
	if !exists(tokenId) {
		panic(newErrorWithDetail(
			errDataNotFound,
			ufmt.Sprintf("tokenId(%d) doesn't exist", tokenId),
		))
	}
}

func assertCallerIsOwner(tokenId uint64, owner, caller std.Address) {
	if owner != caller {
		panic(newErrorWithDetail(
			errNoPermission,
			ufmt.Sprintf("only owner(%s) can increase liquidity for tokenId(%d), but called from %s", owner, tokenId, caller),
		))
	}
}

// assertOnlyUserOrStaker panics if the caller is not a user or staker.
func assertOnlyUserOrStaker(caller std.Realm) {
	if !caller.IsUser() {
		if err := common.StakerOnly(caller.Addr()); err != nil {
			panic(newErrorWithDetail(
				errNoPermission,
				ufmt.Sprintf("from (%s)", caller.Addr()),
			))
		}
	}
}

// assertOnlyNotHalted panics if the contract is halted.
func assertOnlyNotHalted() {
	common.IsHalted()
}

// assertOnlyValidAddress panics if the address is invalid.
func assertOnlyValidAddress(addr std.Address) {
	if !addr.IsValid() {
		panic(newErrorWithDetail(
			errInvalidAddress,
			ufmt.Sprintf("(%s)", addr),
		))
	}
}

func assertWrapNativeToken(ugnotSent uint64, prevRealm std.Address) {
	if err := wrap(ugnotSent, prevRealm); err != nil {
		panic(addDetailToError(
			errWrapUnwrap,
			ufmt.Sprintf("wrap error: %s", err.Error()),
		))
	}
}

// assertOnlyValidAddress panics if the address is invalid or previous address is not
// different from the other address.
func assertOnlyValidAddressWith(prevAddr, otherAddr std.Address) {
	assertOnlyValidAddress(prevAddr)
	assertOnlyValidAddress(otherAddr)

	if prevAddr != otherAddr {
		panic(newErrorWithDetail(
			errInvalidAddress,
			ufmt.Sprintf("(%s, %s)", prevAddr, otherAddr),
		))
	}
}

func verifyTokenIdAndOwnership(tokenId uint64) {
	assertTokenExists(tokenId)

	owner := gnft.OwnerOf(tokenIdFrom(tokenId))
	caller := std.PrevRealm().Addr()
	assertCallerIsOwner(tokenId, owner, caller)
}

func verifyBurnedAmounts(burnedAmount0, burnedAmount1, amount0Min, amount1Min *u256.Uint) {
	if !(burnedAmount0.Gte(amount0Min) && burnedAmount1.Gte(amount1Min)) {
		panic(addDetailToError(
			errSlippage,
			ufmt.Sprintf("burnedAmount0(%s) >= amount0Min(%s) && burnedAmount1(%s) >= amount1Min(%s)", burnedAmount0.ToString(), amount0Min.ToString(), burnedAmount1.ToString(), amount1Min.ToString()),
		))
	}
}

// region: helper

func GetOrigPkgAddr() std.Address {
	return consts.POSITION_ADDR
}

// tokenIdFrom converts tokenId to grc721.TokenID type
// NOTE: input parameter tokenId can be string, int, uint64, or grc721.TokenID
// if tokenId is nil or not supported, it will panic
// if tokenId is not found, it will panic
// input: tokenId interface{}
// output: grc721.TokenID
func tokenIdFrom(tokenId interface{}) grc721.TokenID {
	if tokenId == nil {
		panic(newErrorWithDetail(errInvalidInput, "tokenId is nil"))
	}

	switch tokenId.(type) {
	case string:
		return grc721.TokenID(tokenId.(string))
	case int:
		return grc721.TokenID(strconv.Itoa(tokenId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(tokenId.(uint64))))
	case grc721.TokenID:
		return tokenId.(grc721.TokenID)
	default:
		panic(newErrorWithDetail(errInvalidInput, "unsupported tokenId type"))
	}
}

// exists checks whether tokenId exists
// If tokenId doesn't exist, return false, otherwise return true
// input: tokenId uint64
// output: bool
func exists(tokenId uint64) bool {
	return gnft.Exists(tokenIdFrom(tokenId))
}

// isOwner checks whether the caller is the owner of the tokenId
// If the caller is the owner of the tokenId, return true, otherwise return false
// input: tokenId uint64, addr std.Address
// output: bool
func isOwner(tokenId uint64, addr std.Address) bool {
	owner := gnft.OwnerOf(tokenIdFrom(tokenId))
	if owner == addr {
		return true
	}
	return false
}

// isOperator checks whether the caller is the approved operator of the tokenId
// If the caller is the approved operator of the tokenId, return true, otherwise return false
// input: tokenId uint64, addr std.Address
// output: bool
func isOperator(tokenId uint64, addr std.Address) bool {
	operator, ok := gnft.GetApproved(tokenIdFrom(tokenId))
	if ok && operator == addr {
		return true
	}
	return false
}

// isStaked checks whether tokenId is staked
// If tokenId is staked, owner of tokenId is staker contract
// If tokenId is staked, return true, otherwise return false
// input: tokenId grc721.TokenID
// output: bool
func isStaked(tokenId grc721.TokenID) bool {
	exist := gnft.Exists(tokenId)
	if exist {
		owner := gnft.OwnerOf(tokenId)
		if owner == consts.STAKER_ADDR {
			return true
		}
	}
	return false
}

// isOwnerOrOperator checks whether the caller is the owner or approved operator of the tokenId
// If the caller is the owner or approved operator of the tokenId, return true, otherwise return false
// input: addr std.Address, tokenId uint64
// output: bool
func isOwnerOrOperator(addr std.Address, tokenId uint64) bool {
	assertOnlyValidAddress(addr)
	if !exists(tokenId) {
		return false
	}
	if isOwner(tokenId, addr) || isOperator(tokenId, addr) {
		return true
	}
	if isStaked(tokenIdFrom(tokenId)) {
		position, exist := positions[tokenId]
		if exist && addr == position.operator {
			return true
		}
	}
	return false
}

// splitOf divides poolKey into pToken0, pToken1, and pFee
// If poolKey is invalid, it will panic
//
// input: poolKey string
// output:
// - token0Path string
// - token1Path string
// - fee uint32
func splitOf(poolKey string) (string, string, uint32) {
	res, err := common.Split(poolKey, ":", 3)
	if err != nil {
		panic(newErrorWithDetail(errInvalidInput, ufmt.Sprintf("invalid poolKey(%s)", poolKey)))
	}
	pToken0, pToken1, pFeeStr := res[0], res[1], res[2]

	pFee, err := strconv.Atoi(pFeeStr)
	if err != nil {
		panic(newErrorWithDetail(errInvalidInput, ufmt.Sprintf("invalid fee(%s)", pFeeStr)))
	}
	return pToken0, pToken1, uint32(pFee)
}

package protocol_fee

import (
	"std"
	"strings"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"
)

var (
	tokenListWithAmount = make(map[string]uint64) // tokenPath -> amount
)

// TokenList returns only the token path.
// If positive is true, it returns only the token path with amount > 0.
// If positive is false, it returns all the token path.
func TokenList(positive bool) []string {
	tokens := []string{}

	for tokenPath, amount := range tokenListWithAmount {
		if positive && amount == 0 {
			continue
		}

		tokens = append(tokens, tokenPath)
	}

	return tokens
}

// TokenListWithAmount returns the token path and amount.
func TokenListWithAmount() map[string]uint64 {
	return tokenListWithAmount
}

// AddToProtocolFee adds the amount to the tokenListWithAmount
// Only `pool + router + staker` can execute this function.
func AddToProtocolFee(tokenPath string, amount uint64) {
	assertOnlyPoolRouterStaker()
	tokenListWithAmount[tokenPath] += amount
}

// ClearTokenListWithAmount clears the tokenListWithAmount.
// only `gov/staker` can execute this function.
func ClearTokenListWithAmount() {
	assertOnlyGovStaker()
	tokenListWithAmount = map[string]uint64{}
}

// TransferProtocolFee transfers the protocol fee to devOps and gov/staker.
// It returns list of token with amount has been sent to gov/staker.
func TransferProtocolFee() map[string]uint64 {
	assertOnlyGovStaker()

	sentToDevOps := []string{}
	sentToGovStaker := []string{}
	toReturn := map[string]uint64{}

	for token, amount := range tokenListWithAmount {
		balance := common.BalanceOf(token, consts.PROTOCOL_FEE_ADDR)

		// amount in `tokenListWithAmount` is corrupted, it should be equal to balance
		if amount != balance {
			panic(errInvalidAmount.Error())
		}

		if balance > 0 {
			toDevOps := balance * devOpsPct / 10000 // default 0%
			toGovStaker := balance - toDevOps       // default 100%

			tokenTeller := common.GetTokenTeller(token)
			if toDevOps > 0 {
				tokenTeller.Transfer(consts.DEV_OPS, toDevOps)
				sentToDevOps = append(sentToDevOps, makeEventString(token, toDevOps))
			}

			if toGovStaker > 0 {
				tokenTeller.Transfer(consts.GOV_STAKER_ADDR, toGovStaker)
				sentToGovStaker = append(sentToGovStaker, makeEventString(token, toGovStaker))

				toReturn[token] = toGovStaker
			}
		}
	}

	ClearTokenListWithAmount()

	prevAddr, prevRealm := getPrev()
	std.Emit(
		"TransferProtocolFee",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"toDevOps", strings.Join(sentToDevOps, ","),
		"toGovStaker", strings.Join(sentToGovStaker, ","),
	)

	return toReturn
}

// assertOnlyPoolRouterStaker panics if the caller is not the pool, router, or staker contract.
func assertOnlyPoolRouterStaker() {
	caller := std.PrevRealm().Addr()

	poolOnlyErr := common.PoolOnly(caller)
	routerOnlyErr := common.RouterOnly(caller)
	stakerOnlyErr := common.StakerOnly(caller)

	if poolOnlyErr != nil && routerOnlyErr != nil && stakerOnlyErr != nil {
		panic(errNoPermission)
	}
}

// assertOnlyGovStaker panics if the caller is not the gov/staker contract.
func assertOnlyGovStaker() {
	caller := std.PrevRealm().Addr()
	if err := common.GovStakerOnly(caller); err != nil {
		panic(err.Error())
	}
}

func makeEventString(tokenPath string, amount uint64) string {
	return tokenPath + "*FEE*" + ufmt.Sprintf("%d", amount)
}

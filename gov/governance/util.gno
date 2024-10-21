package governance

import (
	b64 "encoding/base64"
	"std"
	"strconv"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	pusers "gno.land/p/demo/users"
)

const (
	MaxUint64 = 1<<64 - 1
	uintSize  = 32 << (^uint(0) >> 63)
)

func strToInt(str string) int {
	res, err := strconv.Atoi(str)
	if err != nil {
		panic(err)
	}

	return res
}

func strToU256U64(str string) uint64 {
	strValue := u256.MustFromDecimal(str)
	return strValue.Uint64()
}

func checkProposalType(proposalType string) {
	if proposalType != "TEXT" &&
		proposalType != "COMMUNITY_POOL_SPEND" &&
		proposalType != "PARAMETER_CHANGE" {
		panic("INVALID_PROPOSAL_TYPE")
	}
}

func voteToString(b bool) string {
	if b {
		return "yes"
	}
	return "no"
}

func contains(slice []string, str string) bool {
	for _, v := range slice {
		if v == str {
			return true
		}
	}
	return false
}

func marshal(data *json.Node) string {
	b, err := json.Marshal(data)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}

func b64Encode(data string) string {
	return string(b64.StdEncoding.EncodeToString([]byte(data)))
}

func prevRealm() string {
	return std.PrevRealm().PkgPath()
}

func a2u(addr std.Address) pusers.AddressOrName {
	return pusers.AddressOrName(addr)
}

func isUserCall() bool {
	return std.PrevRealm().IsUser()
}

func assertUserCall() {
	if !isUserCall() {
		panic("must be called by user")
	}
}

func getPrev() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}

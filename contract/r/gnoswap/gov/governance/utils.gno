package governance

import (
	"encoding/base64"
	"std"
	"strconv"

	"gno.land/p/demo/avl"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
)

func mustGetProposal(proposalId uint64) ProposalInfo {
	result, exists := proposals.Get(formatUint(proposalId))
	if !exists {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("proposalId(%d) not found", proposalId),
		))
	}

	return result.(ProposalInfo)
}

func mustGetVote(key string) bool {
	vote, exists := votes.Get(key)
	if !exists {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("voteKey(%s) not found", key),
		))
	}
	return vote.(bool)
}

// Helper function to validate and get vote information
func getVoteInfoFromKey(voteKey string) (voteWithWeight, bool) {
	mustGetVote(voteKey)

	pid, addr := divideVoteKeyToProposalIdAndUser(voteKey)

	voteInfo, exists := getUserVote(addr, pid)
	if !exists {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("voteKey(%s) not found", voteKey),
		))
	}

	return voteInfo, true
}

func mustGetVoteInfo(voteKey string) voteWithWeight {
	voteInfo, _ := getVoteInfoFromKey(voteKey)
	return voteInfo
}

func iterTree(tree *avl.Tree, cb func(key string, value interface{}) bool) {
	tree.Iterate("", "", cb)
}

func strToInt(str string) int {
	res, err := strconv.Atoi(str)
	if err != nil {
		panic(err.Error())
	}

	return res
}

func voteToString(b bool) string {
	if b {
		return "yes"
	}
	return "no"
}

func marshal(data *json.Node) string {
	b, err := json.Marshal(data)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}

func b64Encode(data string) string {
	return string(base64.StdEncoding.EncodeToString([]byte(data)))
}

func b64Decode(data string) string {
	decoded, err := base64.StdEncoding.DecodeString(data)
	if err != nil {
		panic(err.Error())
	}
	return string(decoded)
}

func prevRealm() string {
	return std.PrevRealm().PkgPath()
}

func getPrev() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}

func formatUint(v interface{}) string {
	switch v := v.(type) {
	case uint8:
		return strconv.FormatUint(uint64(v), 10)
	case uint32:
		return strconv.FormatUint(uint64(v), 10)
	case uint64:
		return strconv.FormatUint(v, 10)
	default:
		panic(ufmt.Sprintf("invalid type: %T", v))
	}
}

func formatBool(v bool) string {
	return strconv.FormatBool(v)
}

func parseInt(s string) int {
	num, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		panic(ufmt.Sprintf("invalid int value: %s", s))
	}
	return int(num)
}

func parseUint64(s string) uint64 {
	num, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		panic(ufmt.Sprintf("invalid uint64 value: %s", s))
	}
	return num
}

func parseBool(s string) bool {
	switch s {
	case "true":
		return true
	case "false":
		return false
	default:
		panic(ufmt.Sprintf("invalid bool value: %s", s))
	}
}

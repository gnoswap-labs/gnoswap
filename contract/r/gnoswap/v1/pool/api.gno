package pool

import (
	b64 "encoding/base64"
	"strconv"
	"strings"

	"gno.land/p/onbloc/json"

	"gno.land/p/nt/ufmt"
)

func ApiGetPool(poolPath string) string {
	if !pools.Has(poolPath) {
		return ""
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     newStatNode().JSON(),
		"response": newRpcPool(poolPath).JSON(),
	})

	return marshal(node)
}

func posKeyDivide(posKey string) (string, int32, int32) {
	kDec, _ := b64.StdEncoding.DecodeString(posKey)
	posKey = string(kDec)

	res := strings.Split(posKey, "__")
	if len(res) != 3 {
		panic(newErrorWithDetail(
			errInvalidPositionKey,
			ufmt.Sprintf("invalid posKey(%s)", posKey),
		))
	}

	owner, _tickLower, _tickUpper := res[0], res[1], res[2]

	tickLower, _ := strconv.Atoi(_tickLower)
	tickUpper, _ := strconv.Atoi(_tickUpper)

	return owner, int32(tickLower), int32(tickUpper)
}

func marshal(node *json.Node) string {
	b, err := json.Marshal(node)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}

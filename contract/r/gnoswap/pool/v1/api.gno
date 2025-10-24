package v1

import (
	"chain/runtime"
	b64 "encoding/base64"
	"strconv"
	"strings"
	"time"

	"gno.land/p/nt/ufmt"
	"gno.land/p/onbloc/json"
	pl "gno.land/r/gnoswap/pool"
)

func (i *poolV1) ApiGetPool(poolPath string) string {
	if !i.store.GetPools().Has(poolPath) {
		return ""
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     newStatNode().JSON(),
		"response": newRpcPool(i, poolPath).JSON(),
	})

	return marshal(node)
}

// ApiGetTWAP returns the time-weighted average price for a pool over a specified period
//
// Parameters:
//   - poolPath: The path of the pool (e.g., "gno.land/r/demo/bar:gno.land/r/demo/foo:500")
//   - secondsAgo: Number of seconds ago to calculate TWAP from
//
// Returns JSON string with TWAP data or error
func (i *poolV1) ApiGetTWAP(poolPath string, secondsAgo uint32) string {
	currentTime := time.Now().Unix()
	currentHeight := runtime.ChainHeight()

	poolI, exist := i.store.GetPools().Get(poolPath)
	if !exist {
		return json.ObjectNode("", map[string]*json.Node{
			"stat": json.ObjectNode("", map[string]*json.Node{
				"height":    json.StringNode("height", strconv.Itoa(int(currentHeight))),
				"timestamp": json.StringNode("timestamp", strconv.FormatInt(currentTime, 10)),
			}),
			"error": json.StringNode("error", "pool not found"),
		}).String()
	}

	pool := poolI.(*pl.Pool)

	twapTick, err := getTWAP(pool, secondsAgo)
	if err != nil {
		return json.ObjectNode("", map[string]*json.Node{
			"stat": json.ObjectNode("", map[string]*json.Node{
				"height":    json.StringNode("height", strconv.Itoa(int(currentHeight))),
				"timestamp": json.StringNode("timestamp", strconv.FormatInt(currentTime, 10)),
			}),
			"error": json.StringNode("error", err.Error()),
		}).String()
	}

	return json.ObjectNode("", map[string]*json.Node{
		"stat": json.ObjectNode("", map[string]*json.Node{
			"height":    json.StringNode("height", strconv.Itoa(int(currentHeight))),
			"timestamp": json.StringNode("timestamp", strconv.FormatInt(currentTime, 10)),
		}),
		"response": json.ObjectNode("", map[string]*json.Node{
			"poolPath":   json.StringNode("poolPath", poolPath),
			"twapTick":   json.StringNode("twapTick", strconv.FormatInt(int64(twapTick), 10)),
			"secondsAgo": json.StringNode("secondsAgo", strconv.FormatUint(uint64(secondsAgo), 10)),
		}),
	}).String()
}

func posKeyDivide(posKey string) (string, int32, int32) {
	kDec, err := b64.StdEncoding.DecodeString(posKey)
	if err != nil {
		panic(errInvalidPositionKey)
	}
	posKey = string(kDec)

	res := strings.Split(posKey, "__")
	if len(res) != 3 {
		panic(newErrorWithDetail(
			errInvalidPositionKey,
			ufmt.Sprintf("invalid posKey(%s)", posKey),
		))
	}

	owner, tl, tu := res[0], res[1], res[2]

	tickLower, err := strconv.Atoi(tl)
	if err != nil {
		panic(errTickLowerInvalid)
	}
	tickUpper, err := strconv.Atoi(tu)
	if err != nil {
		panic(errTickUpperInvalid)
	}

	return owner, int32(tickLower), int32(tickUpper)
}

func marshal(node *json.Node) string {
	b, err := json.Marshal(node)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}

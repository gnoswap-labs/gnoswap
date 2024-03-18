package router

import (
	"encoding/json"
	"std"
	"time"

	"gno.land/p/demo/ufmt"
	"gno.land/r/gnoswap/common"

	pl "gno.land/r/demo/pool"
	"gno.land/r/gnoswap/consts"

	u256 "gno.land/p/big/uint256"
)

type TokenRatio struct {
	Token string `json:"token"`
	Ratio string `json:"ratio"`
}

type ResponseQueryBase struct {
	Height    int64 `json:"height"`
	Timestamp int64 `json:"timestamp"`
}

type ResponseGetRatiosFromBase struct {
	Stat     ResponseQueryBase `json:"stat"`
	Response []TokenRatio      `json:"response"`
}

func ApiGetRatiosFromBase() string {
	qb := ResponseQueryBase{
		Height:    std.GetHeight(),
		Timestamp: time.Now().Unix(),
	}

	ratios := findRatios(3)
	r := ResponseGetRatiosFromBase{
		Stat:     qb,
		Response: ratios,
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[ROUTER] _RPC_api.gno()__ApiGetRatioFromBase || json.Marshal error with %v", err))
	}

	return string(rr)
}

func findRatios(maxHops int) []TokenRatio {
	var tokenRatio = make(map[string]*u256.Uint, 0)
	// WGNOT
	tokenRatio[consts.WRAPPED_WUGNOT] = u256.MustFromDecimal(consts.Q96) // ~= 1

	tokens := getTokenList()

	pools := findCandidatePools()

	for _, token := range tokens {
		if token == consts.WRAPPED_WUGNOT {
			continue
		}

		routes := computeAllRoutes(consts.WRAPPED_WUGNOT, token, maxHops, pools)

		if len(routes) == 0 {
			// NO ROUTES FOUND => SET RATIO TO 0
			tokenRatio[token] = u256.Zero()
		} else {
			numRoutes := uint64(len(routes))

			_tokenRatioX96 := u256.Zero()

			for _, route := range routes {
				numHops := uint64(len(route.route))

				switch numHops {
				case 1, 2, 3:
					priceRatio := calculateTokenRatio(token, route.route, 0, u256.One())
					// _tokenRatioX96 += priceRatio
					_tokenRatioX96 = new(u256.Uint).Add(_tokenRatioX96, priceRatio)
				default:
					_tokenRatioX96 = u256.Zero()
				}
			}
			avgPriceX96 := new(u256.Uint).Div(_tokenRatioX96, u256.NewUint(numRoutes))
			tokenRatio[token] = avgPriceX96
		}
	}
	// LOOP FIN

	var tokenRatios = []TokenRatio{}
	for token, ratio := range tokenRatio {
		tokenRatios = append(tokenRatios, TokenRatio{
			Token: token,
			Ratio: ratio.ToString(),
		})
	}

	return tokenRatios
}

func calculateTokenRatio(currentToken string, routes []PoolWithMeta, proceed int, priceX96 *u256.Uint) *u256.Uint {
	poolPath := routes[len(routes)-proceed-1].poolPath
	pool := pl.GetPoolFromPoolPath(poolPath)

	token0Path := pool.PoolGetToken0Path()
	token1Path := pool.PoolGetToken1Path()

	if token1Path == currentToken {
		poolSqrtPriceX96 := pool.PoolGetSlot0SqrtPriceX96()

		sqrtX96 := new(u256.Uint).Mul(poolSqrtPriceX96, poolSqrtPriceX96)
		priceX96 = new(u256.Uint).Mul(priceX96, sqrtX96)
		currentToken = token0Path
	} else if token0Path == currentToken {
		poolTick := pool.PoolGetSlot0Tick()
		oppositeTick := -poolTick
		oppositeSqrtPriceX96 := common.TickMathGetSqrtRatioAtTick(oppositeTick)

		oppSqrtX96 := new(u256.Uint).Mul(oppositeSqrtPriceX96, oppositeSqrtPriceX96)
		priceX96 = new(u256.Uint).Mul(priceX96, oppSqrtX96)
		currentToken = token1Path
	} else {
		// wrong condition
		panic("[ROUTER] _RPC_api.gno__calculateTokenRatio() || wrong condition")
		return u256.Zero()
	}

	proceed += 1

	for { // remove as much X96 as possible
		tempPriceX96 := priceX96.Clone()
		priceX96 = new(u256.Uint).Div(priceX96, u256.MustFromDecimal(consts.Q96))

		if priceX96.Lt(u256.MustFromDecimal(consts.MIN_PRICE)) {
			if proceed == len(routes) {
				return tempPriceX96
			}
			return calculateTokenRatio(currentToken, routes, proceed, priceX96)
		}
	}
}

func getTokenList() []string {
	seen := make(map[string]bool)
	uniqueTokenList := []string{}
	poolList := pl.PoolGetPoolList()

	for _, poolPath := range poolList {
		token0Path, token1Path, _ := poolPathWithFeeDivide(poolPath)
		if _, exists := seen[token0Path]; !exists {
			seen[token0Path] = true
			uniqueTokenList = append(uniqueTokenList, token0Path)
		}
		if _, exists := seen[token1Path]; !exists {
			seen[token1Path] = true
			uniqueTokenList = append(uniqueTokenList, token1Path)
		}
	}

	return uniqueTokenList
}

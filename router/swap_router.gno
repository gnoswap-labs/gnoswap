package router

import (
	"std"
	"math"

	"gno.land/p/demo/grc/grc20"

	pool "gno.land/p/demo/pool" // XXX
)

var (
	token0 *grc20.AdminToken
	token1 *grc20.AdminToken
  DEFAULT_AMOUNT_IN_CACHED = MAX_UINT32 // 32 or 64 ?
	amountCached = DEFAULT_AMOUNT_IN_CACHED 
)

type ExactInputSingleParams struct {
  TokenIn         std.Address
  TokenOut        std.Address
  Fee             bigint
  Recipient       std.Address
  Deadline        bigint
  AmountIn        bigint
  AmountOutMinimum bigint
  SqrtPriceLimit bigint
  ZeroForOne      bool
}

type ExactInputParams struct {
  Recipient std.Address
  Deadline bigint
  AmountIn bigint
  AmountOutMinimum bigint
  ZeroForOne bool
}

type ExactOutputSingleParams struct {
  ZeroForOne bool
  TokenIn         std.Address
  TokenOut        std.Address
  Fee             bigint
  Recipient       std.Address
  Deadline        bigint
  AmountOut       bigint
  AmountInMaximum bigint
  SqrtPriceLimit bigint
}

type ExactOutputParams struct {
  ZeroForOne bool
  Recipient       std.Address
  Deadline        bigint
  AmountOut       bigint
  AmountInMaximum bigint
}

func Init() {
	// testtoken1.Init()
	// testtoken1.Faucet()
	// testtoken2.Init()
	// testtoken2.Faucet()

	token0 = _.GetGRC20()
	token1 = _.GetGRC20()

	routerAddress := std.GetOrigPkgAddr()
}


func getPool(
	tokenA std.Address,
	tokenB std.Address,
	fee bigint,
) std.Address {
	/// GetPoolAddresss
	return pool.GetPoolAddress(tokenA, tokenB, fee)
}


func exactInputInternal(
	amountIn bigint,
	recipient std.Address,
	sqrtPriceLimit bigint,
	poolAddress std.Address,
) (amountOut bigint) {
	if (recipient == ZeroAddress) {
		recipient = routerAddress
	}

	// XXX
	tokenIn, tokenOut std.Address, fee bigint = poolAddress.DecodeFirstPool()
	var zeroForOne bool = tokenIn < tokenOut

	// XXX	
	var amount0, amount1 bigint = getPool(tokenIn, tokenOut, fee)

	if sqrtPriceLimit == 0 {
		if zeeroForOne {
			sqrtPriceLimit = TickMath.MIN_SQRT_RATIO + 1
		} else {
			sqrtPriceLimit = TickMath.MAX_SQRT_RATIO - 1
		}
	}

	poolAddress.swap(
		recipient,
		zeroForOne,
		bigint(amountIn),
		sqrtPriceLimit,
	)

	if zeroForOne {
		return bigint(-amount1)
	} else {
		return bigint(-amount0)
	}
}


func exactInputSingle(params ExactInputSingleParams) (amountOut bigint) {
  checkDeadline(params.Deadline)

  amountOut = exactInputInternal(e,
    params.amountIn,
    params.recipient,
    params.sqrtPriceLimit,
  )
  require(amountOut >= params.AmountOutMinimum, "Too little received")

  return amountOut
}


func exactInput(params ExactInputParams) (amountOut bigint) {
  checkDeadline(params.Deadline)

  payer := GetOrigCaller()

  
	// XX chaining // eth path
  params.AmountIn = exactInputInternal(
      params.ZeroForOne,
      params.AmountIn,
      params.Recipient, // for intermediate swaps, this contract custodies
      0,
  )

  // decide whether to continue or terminate
  amountOut = params.AmountIn

  require(amountOut >= params.AmountOutMinimum, "Too little received")

  return amountOut
}


func exactOutputInternal(
  amountOut bigint,
  recipient std.Address,
  sqrtPriceLimit bigint,
) (amountIn bigint) {
  // allow swapping to the router address with address 0
  if recipient == zeroAddress {
    recipient = routerAddress
  }

  if sqrtPriceLimit == 0 {
    if zeroForOne {
      sqrtPriceLimit = MIN_SQRT_RATIO + 1
    } else {
      sqrtPriceLimit = MAX_SQRT_RATIO - 1
    }
  }
  amount0Delta, amount1Delta := pool.Swap(
    std.GetOrigCaller(),
    recipient,
    zeroForOne,
    - int (amountOut),
    sqrtPriceLimit,
  )

  var amountOutReceived bigint
  if zeroForOne {
    amountIn = bigint (amount0Delta)
    amountOutReceived = bigint (-amount1Delta)
  } else {
    amountIn = bigint (amount1Delta)
    amountOutReceived = bigint (-amount0Delta)
  }

  if sqrtPriceLimit == 0 {
    require(amountOutReceived == amountOut, "amountOutReceived must equal amountOut")
  }

  return amountIn
}

func exactOutputSingle(params ExactOutputSingleParams) (amountIn uint) {
  checkDeadline(params.Deadline)
  amountIn = exactOutputInternal(
      params.ZeroForOne,
      params.AmountOut,
      params.Recipient,
      params.SqrtPriceLimit,
  )

  require(amountIn <= params.AmountInMaximum, "Too much requested")
  amountInCached = DEFAULT_AMOUNT_IN_CACHED
  return amountIn
}

func exactOutput(params ExactOutputParams) (amountIn uint) {
  checkDeadline(params.Deadline)
  amountIn = exactOutputInternal(
      params.ZeroForOne,
      params.AmountOut,
      params.Recipient,
      0,
  )

  amountIn = amountInCached
  require(amountIn <= params.AmountInMaximum, "Too much requested")
  amountInCached = DEFAULT_AMOUNT_IN_CACHED
  return amountIn
}


// helpers
func require(ok bool, msg string) {
	if !ok {
		panic(msg)
	}
}

func checkDeadline(deadlint uint64) {
  require(BlockTimestamp() <= deadline, "Expired")
}
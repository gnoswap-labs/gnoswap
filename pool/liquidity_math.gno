package pool

import "gno.land/p/demo/ufmt"

func liquidityMathAddDelta(x bigint, y bigint) bigint {
    z := x + y

    if z < 0 {
        panic(ufmt.Sprintf("[POOL] liquidity_math.gno__liquidityMathAddDelta() || Expected z(%d) to be non-negative", z))
    }

    return z
}

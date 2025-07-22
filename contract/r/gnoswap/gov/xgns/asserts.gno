package xgns

import "gno.land/r/gnoswap/v1/halt"

func assertIsNotHaltedAccess() {
	if halt.IsHaltedXGns() {
		panic("xGNS contract operations are currently disabled")
	}
}

func assertIsNotHaltedWithdraw() {
	if halt.IsHaltedWithdraw() {
		panic("xGNS contract withdrawals are currently disabled")
	}
}
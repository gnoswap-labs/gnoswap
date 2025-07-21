package xgns

import "gno.land/r/gnoswap/v1/halt"

func assertIsNotHaltedAccess() {
	if !halt.IsAllowedAccess(halt.OpTypeXGns) {
		panic("xGNS contract operations are currently disabled")
	}
}

func assertIsNotHaltedWithdraw() {
	if !halt.IsAllowedWithdraw(halt.OpTypeXGns) {
		panic("xGNS contract withdrawals are currently disabled")
	}
}
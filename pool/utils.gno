package pool

import (
	"std"

	"gno.land/p/demo/ufmt"

	pusers "gno.land/p/demo/users"

	u256 "gno.land/p/gnoswap/uint256"
)

func safeConvertToUint64(value *u256.Uint) (uint64, error) {
	res, overflow := value.Uint64WithOverflow()
	if overflow {
		return 0, ufmt.Errorf(
			"%v: amount(%s) overflows uint64 range",
			errOutOfRange, value.ToString(),
		)
	}

	return res, nil
}

func a2u(addr std.Address) pusers.AddressOrName {
	if !addr.IsValid() {
		panic(addDetailToError(
			errInvalidAddress,
			addr.String(),
		))
	}
	return pusers.AddressOrName(addr)
}

func u256Min(num1, num2 *u256.Uint) *u256.Uint {
	if num1.Lt(num2) {
		return num1
	}

	return num2
}

func isUserCall() bool {
	return std.PrevRealm().IsUser()
}

func getPrev() (string, string) {
	prev := std.PrevRealm()
	return prev.Addr().String(), prev.PkgPath()
}

func checkTransferError(err error) {
	if err != nil {
		panic(addDetailToError(
			errTransferFailed,
			err.Error(),
		))
	}
}

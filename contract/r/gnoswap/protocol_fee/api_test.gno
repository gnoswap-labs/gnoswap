package protocol_fee

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
)

func TestApiGetAccuTransferToGovStaker(t *testing.T) {
	addAccuToGovStaker("gno.land/r/onbloc/bar", 1000)
	addAccuToGovStaker("gno.land/r/onbloc/qux", 2000)

	result := ApiGetAccuTransferToGovStaker()
	uassert.Equal(t, `{"height":"123","now":"1234567890","gno.land/r/onbloc/bar":"1000","gno.land/r/onbloc/qux":"2000"}`, result)

	testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/gov/staker"))
	func(cur realm) {
		testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
		ClearAccuTransferToGovStaker(cur)
	}(cross)
	result = ApiGetAccuTransferToGovStaker()
	uassert.Equal(t, `{"height":"123","now":"1234567890"}`, result)
}

func TestApiGetHistoryTransferToGovStaker(t *testing.T) {
	testing.SkipHeights(1)
	addAccuToGovStaker("gno.land/r/onbloc/bar", 1000)
	addAccuToGovStaker("gno.land/r/onbloc/qux", 2000)
	updateDistributedToGovStakerHistory("gno.land/r/onbloc/bar", 1000)
	updateDistributedToGovStakerHistory("gno.land/r/onbloc/qux", 2000)
	resultHistory := ApiGetHistoryTransferToGovStaker()
	uassert.Equal(t, `{"height":"124","now":"1234567895","gno.land/r/onbloc/bar":"1000","gno.land/r/onbloc/qux":"2000"}`, resultHistory)
	resultAccu := ApiGetAccuTransferToGovStaker()
	uassert.Equal(t, `{"height":"124","now":"1234567895","gno.land/r/onbloc/bar":"1000","gno.land/r/onbloc/qux":"2000"}`, resultAccu)

	testing.SetRealm(std.NewCodeRealm("gno.land/r/gnoswap/v1/gov/staker"))
	func(cur realm) {
		testing.SetRealm(std.NewCodeRealm("gno.land/r/test/test"))
		ClearAccuTransferToGovStaker(cur)
	}(cross)
	resultHistory = ApiGetHistoryTransferToGovStaker()
	uassert.Equal(t, `{"height":"124","now":"1234567895","gno.land/r/onbloc/bar":"1000","gno.land/r/onbloc/qux":"2000"}`, resultHistory)
	resultAccu = ApiGetAccuTransferToGovStaker()
	uassert.Equal(t, `{"height":"124","now":"1234567895"}`, resultAccu)
}

func TestApiGetAccuTransferToDevOps(t *testing.T) {
	testing.SkipHeights(1)
	addAccuToDevOps("gno.land/r/onbloc/bar", 1000)
	addAccuToDevOps("gno.land/r/onbloc/qux", 2000)

	result := ApiGetAccuTransferToDevOps()
	uassert.Equal(t, `{"height":"124","now":"1234567895","gno.land/r/onbloc/bar":"1000","gno.land/r/onbloc/qux":"2000"}`, result)
}

// This test should be run individually. It may appear as failed when running the full test suite locally,
// but there's no need to fix the test.
// In CI, the `-run` flag is used to ensure isolated execution, so there's no need to add separate skip handling.
func TestApiGetHistoryTransferToDevOps(t *testing.T) {
	testing.SkipHeights(1)
	addAccuToDevOps("gno.land/r/onbloc/bar", 1000)
	addAccuToDevOps("gno.land/r/onbloc/qux", 2000)
	updateDistributedToDevOpsHistory("gno.land/r/onbloc/bar", 1000)
	updateDistributedToDevOpsHistory("gno.land/r/onbloc/qux", 2000)
	resultHistory := ApiGetHistoryTransferToDevOps()
	uassert.Equal(t, `{"height":"124","now":"1234567895","gno.land/r/onbloc/bar":"1000","gno.land/r/onbloc/qux":"2000"}`, resultHistory)
	resultAccu := ApiGetAccuTransferToDevOps()
	uassert.Equal(t, `{"height":"124","now":"1234567895","gno.land/r/onbloc/bar":"1000","gno.land/r/onbloc/qux":"2000"}`, resultAccu)
}

package protocol_fee

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestGetTokenListWithAmountIsolation(t *testing.T) {
	resetTestState(t)
	mockProtocolFee := newMockProtocolFee("v1")
	implementation = mockProtocolFee
	stored := map[string]int64{"foo": 10, "bar": 20}
	mockProtocolFee.Response.Set("GetTokenListWithAmount", stored)

	result := GetTokenListWithAmount()
	result["foo"] = 100
	result["baz"] = 300

	uassert.Equal(t, int64(10), stored["foo"])
	_, ok := stored["baz"]
	uassert.Equal(t, false, ok)
	if len(result) > 0 && &result == &stored {
		t.Fatal("GetTokenListWithAmount() returned aliased map")
	}
}

func TestDistributeProtocolFeeIsolation(t *testing.T) {
	resetTestState(t)
	mockProtocolFee := newMockProtocolFee("v1")
	implementation = mockProtocolFee
	stored := map[string]int64{"foo": 10, "bar": 20}
	mockProtocolFee.Response.Set("DistributeProtocolFee", stored)

	result := DistributeProtocolFee(cross)
	result["foo"] = 100
	result["baz"] = 300

	uassert.Equal(t, int64(10), stored["foo"])
	_, ok := stored["baz"]
	uassert.Equal(t, false, ok)
}

func TestGetTokenListIsolation(t *testing.T) {
	resetTestState(t)
	mockProtocolFee := newMockProtocolFee("v1")
	implementation = mockProtocolFee
	stored := []string{"foo", "bar"}
	mockProtocolFee.Response.Set("GetTokenList", stored)

	result := GetTokenList()
	result[0] = "mutated"
	result = append(result, "baz")

	uassert.Equal(t, "foo", stored[0])
	uassert.Equal(t, 2, len(stored))
	if len(stored) > 0 && len(result) > 0 && &stored[0] == &result[0] {
		t.Fatal("GetTokenList() returned aliased slice backing array")
	}
}

func TestGetAccuTransfersToGovStakerIsolation(t *testing.T) {
	resetTestState(t)
	mockProtocolFee := newMockProtocolFee("v1")
	implementation = mockProtocolFee
	stored := map[string]int64{"foo": 10, "bar": 20}
	mockProtocolFee.Response.Set("GetAccuTransfersToGovStaker", stored)

	result := GetAccuTransfersToGovStaker()
	result["foo"] = 100
	result["baz"] = 300

	uassert.Equal(t, int64(10), stored["foo"])
	_, ok := stored["baz"]
	uassert.Equal(t, false, ok)
}

func TestGetAccuTransfersToDevOpsIsolation(t *testing.T) {
	resetTestState(t)
	mockProtocolFee := newMockProtocolFee("v1")
	implementation = mockProtocolFee
	stored := map[string]int64{"foo": 10, "bar": 20}
	mockProtocolFee.Response.Set("GetAccuTransfersToDevOps", stored)

	result := GetAccuTransfersToDevOps()
	result["foo"] = 100
	result["baz"] = 300

	uassert.Equal(t, int64(10), stored["foo"])
	_, ok := stored["baz"]
	uassert.Equal(t, false, ok)
}

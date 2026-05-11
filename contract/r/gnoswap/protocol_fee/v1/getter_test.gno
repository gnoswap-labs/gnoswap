package v1

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestGetDevOpsPct(t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func() *protocolFeeV1
		expected int64
	}{
		{
			name: "success - get default devOps percentage (0%)",
			setupFn: func() *protocolFeeV1 {
				return createTestProtocolFee(t)
			},
			expected: 0,
		},
		{
			name: "success - get custom devOps percentage (30%)",
			setupFn: func() *protocolFeeV1 {
				pf := createTestProtocolFee(t)
				pf.store.SetDevOpsPct(3000)
				return pf
			},
			expected: 3000,
		},
		{
			name: "success - get 100% devOps percentage",
			setupFn: func() *protocolFeeV1 {
				pf := createTestProtocolFee(t)
				pf.store.SetDevOpsPct(10000)
				return pf
			},
			expected: 10000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pf := tt.setupFn()
			result := pf.GetDevOpsPct()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestGetGovStakerPct(t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func() *protocolFeeV1
		expected int64
	}{
		{
			name: "success - get default govStaker percentage (100%)",
			setupFn: func() *protocolFeeV1 {
				return createTestProtocolFee(t)
			},
			expected: 10000,
		},
		{
			name: "success - get govStaker percentage when devOps is 30%",
			setupFn: func() *protocolFeeV1 {
				pf := createTestProtocolFee(t)
				pf.store.SetDevOpsPct(3000)
				return pf
			},
			expected: 7000,
		},
		{
			name: "success - get 0% govStaker when devOps is 100%",
			setupFn: func() *protocolFeeV1 {
				pf := createTestProtocolFee(t)
				pf.store.SetDevOpsPct(10000)
				return pf
			},
			expected: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pf := tt.setupFn()
			result := pf.GetGovStakerPct()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestGetReservedTokens(t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func() *protocolFeeV1
		expected []string
	}{
		{
			name: "success - get empty reserved tokens",
			setupFn: func() *protocolFeeV1 {
				return createTestProtocolFee(t)
			},
			expected: []string{},
		},
		{
			name: "success - get single reserved token",
			setupFn: func() *protocolFeeV1 {
				pf := createTestProtocolFee(t)
				pf.store.AddReservedToken("gno.land/r/foo")
				return pf
			},
			expected: []string{"gno.land/r/foo"},
		},
		{
			name: "success - get multiple reserved tokens",
			setupFn: func() *protocolFeeV1 {
				pf := createTestProtocolFee(t)
				pf.store.AddReservedToken("gno.land/r/foo")
				pf.store.AddReservedToken("gno.land/r/bar")
				pf.store.AddReservedToken("gno.land/r/baz")
				return pf
			},
			expected: []string{"gno.land/r/foo", "gno.land/r/bar", "gno.land/r/baz"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pf := tt.setupFn()
			result := pf.GetReservedTokens()
			uassert.Equal(t, len(result), len(tt.expected))
			for i, expected := range tt.expected {
				uassert.Equal(t, expected, result[i])
			}
		})
	}
}

func TestGetAccuTransfersToGovStaker(t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func() *protocolFeeV1
		expected map[string]int64
	}{
		{
			name: "success - get empty accumulated transfers",
			setupFn: func() *protocolFeeV1 {
				return createTestProtocolFee(t)
			},
			expected: map[string]int64{},
		},
		{
			name: "success - get accumulated transfers with single token",
			setupFn: func() *protocolFeeV1 {
				pf := createTestProtocolFee(t)
				pf.store.SetAccuToGovStakerItem("gno.land/r/foo", 1000)
				return pf
			},
			expected: map[string]int64{"gno.land/r/foo": 1000},
		},
		{
			name: "success - get accumulated transfers with multiple tokens",
			setupFn: func() *protocolFeeV1 {
				pf := createTestProtocolFee(t)
				pf.store.SetAccuToGovStakerItem("gno.land/r/foo", 1000)
				pf.store.SetAccuToGovStakerItem("gno.land/r/bar", 2000)
				pf.store.SetAccuToGovStakerItem("gno.land/r/baz", 3000)
				return pf
			},
			expected: map[string]int64{
				"gno.land/r/foo": 1000,
				"gno.land/r/bar": 2000,
				"gno.land/r/baz": 3000,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pf := tt.setupFn()
			result := pf.GetAccuTransfersToGovStaker()
			uassert.Equal(t, len(result), len(tt.expected))
			for k, v := range tt.expected {
				uassert.Equal(t, result[k], v)
			}
		})
	}
}

func TestGetAccuTransfersToDevOps(t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func() *protocolFeeV1
		expected map[string]int64
	}{
		{
			name: "success - get empty accumulated transfers",
			setupFn: func() *protocolFeeV1 {
				return createTestProtocolFee(t)
			},
			expected: map[string]int64{},
		},
		{
			name: "success - get accumulated transfers with single token",
			setupFn: func() *protocolFeeV1 {
				pf := createTestProtocolFee(t)
				pf.store.SetAccuToDevOpsItem("gno.land/r/foo", 500)
				return pf
			},
			expected: map[string]int64{"gno.land/r/foo": 500},
		},
		{
			name: "success - get accumulated transfers with multiple tokens",
			setupFn: func() *protocolFeeV1 {
				pf := createTestProtocolFee(t)
				pf.store.SetAccuToDevOpsItem("gno.land/r/foo", 500)
				pf.store.SetAccuToDevOpsItem("gno.land/r/bar", 1000)
				pf.store.SetAccuToDevOpsItem("gno.land/r/baz", 1500)
				return pf
			},
			expected: map[string]int64{
				"gno.land/r/foo": 500,
				"gno.land/r/bar": 1000,
				"gno.land/r/baz": 1500,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pf := tt.setupFn()
			result := pf.GetAccuTransfersToDevOps()
			uassert.Equal(t, len(result), len(tt.expected))
			for k, v := range tt.expected {
				uassert.Equal(t, result[k], v)
			}
		})
	}
}

func TestGetAccuTransferToGovStakerByTokenPath(t *testing.T) {
	tests := []struct {
		name      string
		setupFn   func() *protocolFeeV1
		tokenPath string
		expected  int64
	}{
		{
			name: "success - get accumulated transfer for existing token",
			setupFn: func() *protocolFeeV1 {
				pf := createTestProtocolFee(t)
				pf.store.SetAccuToGovStakerItem("gno.land/r/foo", 3000)
				return pf
			},
			tokenPath: "gno.land/r/foo",
			expected:  3000,
		},
		{
			name: "success - get 0 for non-existent token",
			setupFn: func() *protocolFeeV1 {
				return createTestProtocolFee(t)
			},
			tokenPath: "gno.land/r/nonexistent",
			expected:  0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pf := tt.setupFn()
			result := pf.GetAccuTransferToGovStakerByTokenPath(tt.tokenPath)
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestGetAccuTransferToDevOpsByTokenPath(t *testing.T) {
	tests := []struct {
		name      string
		setupFn   func() *protocolFeeV1
		tokenPath string
		expected  int64
	}{
		{
			name: "success - get accumulated transfer for existing token",
			setupFn: func() *protocolFeeV1 {
				pf := createTestProtocolFee(t)
				pf.store.SetAccuToDevOpsItem("gno.land/r/foo", 1500)
				return pf
			},
			tokenPath: "gno.land/r/foo",
			expected:  1500,
		},
		{
			name: "success - get 0 for non-existent token",
			setupFn: func() *protocolFeeV1 {
				return createTestProtocolFee(t)
			},
			tokenPath: "gno.land/r/nonexistent",
			expected:  0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pf := tt.setupFn()
			result := pf.GetAccuTransferToDevOpsByTokenPath(tt.tokenPath)
			uassert.Equal(t, result, tt.expected)
		})
	}
}

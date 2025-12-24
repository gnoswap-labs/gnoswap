package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
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

func TestGetTokenListWithAmount(t *testing.T) {
	tests := []struct {
		name     string
		setupFn  func() *protocolFeeV1
		expected map[string]int64
	}{
		{
			name: "success - get empty token list",
			setupFn: func() *protocolFeeV1 {
				return createTestProtocolFee(t)
			},
			expected: map[string]int64{},
		},
		{
			name: "success - get token list with single token",
			setupFn: func() *protocolFeeV1 {
				pf := createTestProtocolFee(t)
				pf.store.SetTokenListWithAmountItem("gno.land/r/foo", 1000)
				return pf
			},
			expected: map[string]int64{"gno.land/r/foo": 1000},
		},
		{
			name: "success - get token list with multiple tokens",
			setupFn: func() *protocolFeeV1 {
				pf := createTestProtocolFee(t)
				pf.store.SetTokenListWithAmountItem("gno.land/r/foo", 1000)
				pf.store.SetTokenListWithAmountItem("gno.land/r/bar", 2000)
				pf.store.SetTokenListWithAmountItem("gno.land/r/baz", 3000)
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
			result := pf.GetTokenListWithAmount()
			uassert.Equal(t, result.Size(), len(tt.expected))
			for k, v := range tt.expected {
				value, ok := result.Get(k)
				uassert.True(t, ok)
				uassert.Equal(t, value.(int64), v)
			}
		})
	}
}

func TestGetAmountOfToken(t *testing.T) {
	tests := []struct {
		name      string
		setupFn   func() *protocolFeeV1
		tokenPath string
		expected  int64
	}{
		{
			name: "success - get amount for existing token",
			setupFn: func() *protocolFeeV1 {
				pf := createTestProtocolFee(t)
				pf.store.SetTokenListWithAmountItem("gno.land/r/foo", 5000)
				return pf
			},
			tokenPath: "gno.land/r/foo",
			expected:  5000,
		},
		{
			name: "success - get 0 for non-existent token",
			setupFn: func() *protocolFeeV1 {
				return createTestProtocolFee(t)
			},
			tokenPath: "gno.land/r/nonexistent",
			expected:  0,
		},
		{
			name: "success - get 0 amount for existing token with 0",
			setupFn: func() *protocolFeeV1 {
				pf := createTestProtocolFee(t)
				pf.store.SetTokenListWithAmountItem("gno.land/r/zero", 0)
				return pf
			},
			tokenPath: "gno.land/r/zero",
			expected:  0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			pf := tt.setupFn()
			result := pf.GetAmountOfToken(tt.tokenPath)
			uassert.Equal(t, result, tt.expected)
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

func TestGetHistoryOfDistributedToGovStakerByTokenPath(t *testing.T) {
	tests := []struct {
		name      string
		setupFn   func() *protocolFeeV1
		tokenPath string
		expected  int64
	}{
		{
			name: "success - get history for existing token",
			setupFn: func() *protocolFeeV1 {
				pf := createTestProtocolFee(t)
				pf.store.SetDistributedToGovStakerHistoryItem("gno.land/r/foo", 2000)
				return pf
			},
			tokenPath: "gno.land/r/foo",
			expected:  2000,
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
			result := pf.GetHistoryOfDistributedToGovStakerByTokenPath(tt.tokenPath)
			uassert.Equal(t, result, tt.expected)
		})
	}
}

func TestGetHistoryOfDistributedToDevOpsByTokenPath(t *testing.T) {
	tests := []struct {
		name      string
		setupFn   func() *protocolFeeV1
		tokenPath string
		expected  int64
	}{
		{
			name: "success - get history for existing token",
			setupFn: func() *protocolFeeV1 {
				pf := createTestProtocolFee(t)
				pf.store.SetDistributedToDevOpsHistoryItem("gno.land/r/foo", 800)
				return pf
			},
			tokenPath: "gno.land/r/foo",
			expected:  800,
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
			result := pf.GetHistoryOfDistributedToDevOpsByTokenPath(tt.tokenPath)
			uassert.Equal(t, result, tt.expected)
		})
	}
}

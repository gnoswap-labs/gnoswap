package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/p/onbloc/json"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"

	_ "gno.land/r/gnoswap/rbac" // Initialize contract roles
)

// createTestProtocolFeeV1 creates a fresh protocolFeeV1 instance for testing
func createTestProtocolFeeV1(t *testing.T) *protocolFeeV1 {
	t.Helper()

	return &protocolFeeV1{
		store: newMockProtocolFeeStore(),
	}
}

func TestGetAccuTransferToGovStaker(t *testing.T) {
	tests := []struct {
		name        string
		historyItem []struct {
			token  string
			amount int64
		}
		expectedResultAccu string
	}{
		{
			name: "api get accu transfer to gov staker success",
			historyItem: []struct {
				token  string
				amount int64
			}{
				{token: "gno.land/r/onbloc/bar", amount: 1000},
				{token: "gno.land/r/onbloc/qux", amount: 2000},
			},
			expectedResultAccu: `{"height":"123","now":"1234567890","gno.land/r/onbloc/bar":"1000","gno.land/r/onbloc/qux":"2000"}`,
		},
		{
			name: "api get accu transfer to gov staker success",
			historyItem: []struct {
				token  string
				amount int64
			}{
				{token: "gno.land/r/onbloc/bar", amount: 1000},
				{token: "gno.land/r/onbloc/bar", amount: 2000},
			},
			expectedResultAccu: `{"height":"123","now":"1234567890","gno.land/r/onbloc/bar":"3000"}`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			pf := createTestProtocolFeeV1(t)

			for _, item := range tt.historyItem {
				pf.getProtocolFeeState().addAccuToGovStaker(item.token, item.amount)
			}

			// when
			resultAccu := pf.ApiGetAccuTransferToGovStaker()

			// then
			uassert.Equal(t, tt.expectedResultAccu, resultAccu)
		})
	}
}

func TestGetHistoryTransferToGovStaker(t *testing.T) {
	tests := []struct {
		name        string
		historyItem []struct {
			token  string
			amount int64
		}
		expectedResultHistory string
		expectedResultAccu    string
	}{
		{
			name: "api get history transfer to gov staker success",
			historyItem: []struct {
				token  string
				amount int64
			}{
				{token: "gno.land/r/onbloc/bar", amount: 1000},
				{token: "gno.land/r/onbloc/qux", amount: 2000},
			},
			expectedResultHistory: `{"height":"124","now":"1234567895","gno.land/r/onbloc/bar":"1000","gno.land/r/onbloc/qux":"2000"}`,
			expectedResultAccu:    `{"height":"124","now":"1234567895","gno.land/r/onbloc/bar":"1000","gno.land/r/onbloc/qux":"2000"}`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			pf := createTestProtocolFeeV1(t)
			testing.SkipHeights(1)

			for _, item := range tt.historyItem {
				pf.getProtocolFeeState().addAccuToGovStaker(item.token, item.amount)
				pf.getProtocolFeeState().updateDistributedToGovStakerHistory(item.token, item.amount)
			}

			// when
			resultHistory := pf.ApiGetHistoryTransferToGovStaker()
			resultAccu := pf.ApiGetAccuTransferToGovStaker()

			// then
			uassert.Equal(t, tt.expectedResultHistory, resultHistory)
			uassert.Equal(t, tt.expectedResultAccu, resultAccu)
		})
	}
}

func TestGetAccuTransferToDevOps(t *testing.T) {
	tests := []struct {
		name        string
		historyItem []struct {
			token  string
			amount int64
		}
		expectedResultAccu string
	}{
		{
			name: "api get accu transfer to devOps success",
			historyItem: []struct {
				token  string
				amount int64
			}{
				{token: "gno.land/r/onbloc/bar", amount: 1000},
				{token: "gno.land/r/onbloc/qux", amount: 2000},
			},
			expectedResultAccu: `{"height":"124","now":"1234567895","gno.land/r/onbloc/bar":"1000","gno.land/r/onbloc/qux":"2000"}`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			pf := createTestProtocolFeeV1(t)
			testing.SkipHeights(1)

			for _, item := range tt.historyItem {
				pf.getProtocolFeeState().addAccuToDevOps(item.token, item.amount)
			}

			// when
			resultAccu := pf.ApiGetAccuTransferToDevOps()

			// then
			uassert.Equal(t, tt.expectedResultAccu, resultAccu)
		})
	}
}

// This test should be run individually. It may appear as failed when running the full test suite locally,
// but there's no need to fix the test.
// In CI, the `-run` flag is used to ensure isolated execution, so there's no need to add separate skip handling.
func TestGetHistoryTransferToDevOps(t *testing.T) {
	tests := []struct {
		name        string
		historyItem []struct {
			token  string
			amount int64
		}
		expectedResultHistory string
		expectedResultAccu    string
	}{
		{
			name: "api get history transfer to devOps success",
			historyItem: []struct {
				token  string
				amount int64
			}{
				{token: "gno.land/r/onbloc/bar", amount: 1000},
				{token: "gno.land/r/onbloc/qux", amount: 2000},
			},
			expectedResultHistory: `{"height":"124","now":"1234567895","gno.land/r/onbloc/bar":"1000","gno.land/r/onbloc/qux":"2000"}`,
			expectedResultAccu:    `{"height":"124","now":"1234567895","gno.land/r/onbloc/bar":"1000","gno.land/r/onbloc/qux":"2000"}`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			pf := createTestProtocolFeeV1(t)
			testing.SkipHeights(1)

			for _, item := range tt.historyItem {
				pf.getProtocolFeeState().addAccuToDevOps(item.token, item.amount)
				pf.getProtocolFeeState().updateDistributedToDevOpsHistory(item.token, item.amount)
			}

			// when
			resultHistory := pf.ApiGetHistoryTransferToDevOps()
			resultAccu := pf.ApiGetAccuTransferToDevOps()

			// then
			uassert.Equal(t, tt.expectedResultHistory, resultHistory)
			uassert.Equal(t, tt.expectedResultAccu, resultAccu)
		})
	}
}

func TestGetActualBalance(t *testing.T) {
	tests := []struct {
		name        string
		barTransfer int64
		quxTransfer int64
		barRecorded int64
		quxRecorded int64
		expectedBar string
		expectedQux string
	}{
		{
			name:        "actual balances with partial recording",
			barTransfer: 1500,
			quxTransfer: 2500,
			barRecorded: 1000,
			quxRecorded: 2000,
			expectedBar: "1500",
			expectedQux: "2500",
		},
		{
			name:        "zero balances",
			barTransfer: 0,
			quxTransfer: 0,
			barRecorded: 0,
			quxRecorded: 0,
			expectedBar: "0",
			expectedQux: "0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			pf := createTestProtocolFee(t)

			testing.SetRealm(adminRealm)
			if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
				bar.Burn(cross, protocolFeeAddr, balance)
			}
			if balance := qux.BalanceOf(protocolFeeAddr); balance > 0 {
				qux.Burn(cross, protocolFeeAddr, balance)
			}

			// Transfer tokens if needed
			if tt.barTransfer > 0 {
				bar.Transfer(cross, protocolFeeAddr, tt.barTransfer)
			}
			if tt.quxTransfer > 0 {
				qux.Transfer(cross, protocolFeeAddr, tt.quxTransfer)
			}

			// Record amounts
			if tt.barRecorded > 0 || tt.barTransfer == 0 {
				pf.getProtocolFeeState().TokenListWithAmounts()["gno.land/r/onbloc/bar"] = tt.barRecorded
			}
			if tt.quxRecorded > 0 || tt.quxTransfer == 0 {
				pf.getProtocolFeeState().TokenListWithAmounts()["gno.land/r/onbloc/qux"] = tt.quxRecorded
			}

			// When
			result := pf.ApiGetActualBalance()

			// Then
			node := json.Must(json.Unmarshal([]byte(result)))

			uassert.True(t, node.HasKey("height"))
			uassert.True(t, node.HasKey("now"))

			barBalance, err := node.MustKey("gno.land/r/onbloc/bar").GetString()
			uassert.NoError(t, err)
			uassert.Equal(t, tt.expectedBar, barBalance)

			quxBalance, err := node.MustKey("gno.land/r/onbloc/qux").GetString()
			uassert.NoError(t, err)
			uassert.Equal(t, tt.expectedQux, quxBalance)
		})
	}
}

func TestGetRecordedBalance(t *testing.T) {
	tests := []struct {
		name        string
		barRecorded int64
		quxRecorded int64
		expectedBar string
		expectedQux string
	}{
		{
			name:        "recorded balances with actual transfers",
			barRecorded: 1000,
			quxRecorded: 2000,
			expectedBar: "1000",
			expectedQux: "2000",
		},
		{
			name:        "single token recorded",
			barRecorded: 500,
			quxRecorded: 0,
			expectedBar: "500",
			expectedQux: "0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			pf := createTestProtocolFee(t)

			testing.SetRealm(adminRealm)
			if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
				bar.Burn(cross, protocolFeeAddr, balance)
			}
			if balance := qux.BalanceOf(protocolFeeAddr); balance > 0 {
				qux.Burn(cross, protocolFeeAddr, balance)
			}

			// Set recorded amounts
			pf.getProtocolFeeState().TokenListWithAmounts()["gno.land/r/onbloc/bar"] = tt.barRecorded
			if tt.quxRecorded > 0 {
				pf.getProtocolFeeState().TokenListWithAmounts()["gno.land/r/onbloc/qux"] = tt.quxRecorded
			}

			// When
			result := pf.ApiGetRecordedBalance()

			// Then
			node := json.Must(json.Unmarshal([]byte(result)))

			uassert.True(t, node.HasKey("height"))
			uassert.True(t, node.HasKey("now"))

			barBalance, err := node.MustKey("gno.land/r/onbloc/bar").GetString()
			uassert.NoError(t, err)
			uassert.Equal(t, tt.expectedBar, barBalance)

			if tt.quxRecorded > 0 {
				quxBalance, err := node.MustKey("gno.land/r/onbloc/qux").GetString()
				uassert.NoError(t, err)
				uassert.Equal(t, tt.expectedQux, quxBalance)
			}
		})
	}
}

func TestGetUnrecordedBalance(t *testing.T) {
	tests := []struct {
		name          string
		barTransfer   int64
		quxTransfer   int64
		barRecorded   int64
		quxRecorded   int64
		expectedBar   string
		expectedQux   string
		shouldHaveBar bool
		shouldHaveQux bool
	}{
		{
			name:          "unrecorded amounts exist",
			barTransfer:   1500,
			quxTransfer:   2500,
			barRecorded:   1000,
			quxRecorded:   2000,
			expectedBar:   "500",
			expectedQux:   "500",
			shouldHaveBar: true,
			shouldHaveQux: true,
		},
		{
			name:          "no unrecorded amount",
			barTransfer:   1000,
			quxTransfer:   0,
			barRecorded:   1000,
			quxRecorded:   0,
			expectedBar:   "",
			expectedQux:   "",
			shouldHaveBar: false,
			shouldHaveQux: false,
		},
		{
			name:          "large discrepancy",
			barTransfer:   10000000,
			quxTransfer:   0,
			barRecorded:   1,
			quxRecorded:   0,
			expectedBar:   "9999999",
			expectedQux:   "",
			shouldHaveBar: true,
			shouldHaveQux: false,
		},
		{
			name:          "multiple tokens with mixed discrepancies",
			barTransfer:   5000,
			quxTransfer:   3000,
			barRecorded:   2000,
			quxRecorded:   3000,
			expectedBar:   "3000",
			expectedQux:   "",
			shouldHaveBar: true,
			shouldHaveQux: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			pf := createTestProtocolFee(t)

			testing.SetRealm(adminRealm)
			if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
				bar.Burn(cross, protocolFeeAddr, balance)
			}
			if balance := qux.BalanceOf(protocolFeeAddr); balance > 0 {
				qux.Burn(cross, protocolFeeAddr, balance)
			}

			// Transfer tokens if needed
			if tt.barTransfer > 0 {
				bar.Transfer(cross, protocolFeeAddr, tt.barTransfer)
			}
			if tt.quxTransfer > 0 {
				qux.Transfer(cross, protocolFeeAddr, tt.quxTransfer)
			}

			// Set recorded amounts
			pf.getProtocolFeeState().TokenListWithAmounts()["gno.land/r/onbloc/bar"] = tt.barRecorded
			if tt.quxTransfer > 0 || tt.quxRecorded > 0 {
				pf.getProtocolFeeState().TokenListWithAmounts()["gno.land/r/onbloc/qux"] = tt.quxRecorded
			}

			// When
			result := pf.ApiGetUnrecordedBalance()

			// Then
			node := json.Must(json.Unmarshal([]byte(result)))

			uassert.True(t, node.HasKey("height"))
			uassert.True(t, node.HasKey("now"))

			// Verify bar token
			if tt.shouldHaveBar {
				barBalance, err := node.MustKey("gno.land/r/onbloc/bar").GetString()
				uassert.NoError(t, err)
				uassert.Equal(t, tt.expectedBar, barBalance)
			} else {
				uassert.False(t, node.HasKey("gno.land/r/onbloc/bar"))
			}

			// Verify qux token
			if tt.shouldHaveQux {
				quxBalance, err := node.MustKey("gno.land/r/onbloc/qux").GetString()
				uassert.NoError(t, err)
				uassert.Equal(t, tt.expectedQux, quxBalance)
			} else {
				uassert.False(t, node.HasKey("gno.land/r/onbloc/qux"))
			}
		})
	}
}

func TestGetAccuTransferToGovStaker_SingleToken(t *testing.T) {
	tests := []struct {
		name           string
		token          string
		amount         int64
		expectedResult string
	}{
		{
			name:           "single token with amount",
			token:          "gno.land/r/onbloc/bar",
			amount:         500,
			expectedResult: `{"height":"123","now":"1234567890","gno.land/r/onbloc/bar":"500"}`,
		},
		{
			name:           "single token with zero amount",
			token:          "gno.land/r/onbloc/bar",
			amount:         0,
			expectedResult: `{"height":"123","now":"1234567890","gno.land/r/onbloc/bar":"0"}`,
		},
		{
			name:           "single token with large amount",
			token:          "gno.land/r/onbloc/bar",
			amount:         9223372036854775806,
			expectedResult: `{"height":"123","now":"1234567890","gno.land/r/onbloc/bar":"9223372036854775806"}`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			pf := createTestProtocolFeeV1(t)
			pf.getProtocolFeeState().addAccuToGovStaker(tt.token, tt.amount)

			// When
			result := pf.ApiGetAccuTransferToGovStaker()

			// Then
			uassert.Equal(t, tt.expectedResult, result)
		})
	}
}

func TestGetAccuTransferToDevOps_SingleToken(t *testing.T) {
	tests := []struct {
		name           string
		token          string
		amount         int64
		expectedResult string
	}{
		{
			name:           "single token with amount",
			token:          "gno.land/r/onbloc/bar",
			amount:         750,
			expectedResult: `{"height":"123","now":"1234567890","gno.land/r/onbloc/bar":"750"}`,
		},
		{
			name:           "single token with zero amount",
			token:          "gno.land/r/onbloc/bar",
			amount:         0,
			expectedResult: `{"height":"123","now":"1234567890","gno.land/r/onbloc/bar":"0"}`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given
			pf := createTestProtocolFeeV1(t)
			pf.getProtocolFeeState().addAccuToDevOps(tt.token, tt.amount)

			// When
			result := pf.ApiGetAccuTransferToDevOps()

			// Then
			uassert.Equal(t, tt.expectedResult, result)
		})
	}
}

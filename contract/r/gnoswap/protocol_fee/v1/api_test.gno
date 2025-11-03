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

func TestApiGetAccuTransferToGovStaker(t *testing.T) {
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

func TestApiGetHistoryTransferToGovStaker(t *testing.T) {
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

func TestApiGetAccuTransferToDevOps(t *testing.T) {
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
func TestApiGetHistoryTransferToDevOps(t *testing.T) {
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

func TestApiGetActualBalance(t *testing.T) {
	pf := createTestProtocolFee(t)

	testing.SetRealm(adminRealm)
	if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
		bar.Burn(cross, protocolFeeAddr, balance)
	}
	if balance := qux.BalanceOf(protocolFeeAddr); balance > 0 {
		qux.Burn(cross, protocolFeeAddr, balance)
	}

	// Transfer tokens to protocol fee
	bar.Transfer(cross, protocolFeeAddr, 1500)
	qux.Transfer(cross, protocolFeeAddr, 2500)

	// Record only part of the amounts (use internal state for testing)
	pf.store.SetTokenListWithAmountItem("gno.land/r/onbloc/bar", 1000)
	pf.store.SetTokenListWithAmountItem("gno.land/r/onbloc/qux", 2000)

	result := pf.ApiGetActualBalance()

	node := json.Must(json.Unmarshal([]byte(result)))

	uassert.True(t, node.HasKey("height"))
	uassert.True(t, node.HasKey("now"))

	// Verify actual balances (not recorded amounts)
	barBalance, err := node.MustKey("gno.land/r/onbloc/bar").GetString()
	uassert.NoError(t, err)
	uassert.Equal(t, barBalance, "1500")

	quxBalance, err := node.MustKey("gno.land/r/onbloc/qux").GetString()
	uassert.NoError(t, err)
	uassert.Equal(t, quxBalance, "2500")
}

func TestApiGetRecordedBalance(t *testing.T) {
	pf := createTestProtocolFee(t)

	testing.SetRealm(adminRealm)
	if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
		bar.Burn(cross, protocolFeeAddr, balance)
	}
	if balance := qux.BalanceOf(protocolFeeAddr); balance > 0 {
		qux.Burn(cross, protocolFeeAddr, balance)
	}

	// Transfer tokens to protocol fee
	bar.Transfer(cross, protocolFeeAddr, 1500)
	qux.Transfer(cross, protocolFeeAddr, 2500)

	// Record only part of the amounts (use internal state for testing)
	pf.store.SetTokenListWithAmountItem("gno.land/r/onbloc/bar", 1000)
	pf.store.SetTokenListWithAmountItem("gno.land/r/onbloc/qux", 2000)

	// Call API function
	result := pf.ApiGetRecordedBalance()

	// Parse JSON response
	node := json.Must(json.Unmarshal([]byte(result)))

	// Verify metadata fields
	uassert.True(t, node.HasKey("height"))
	uassert.True(t, node.HasKey("now"))

	// Verify recorded balances (not actual balances)
	barBalance, err := node.MustKey("gno.land/r/onbloc/bar").GetString()
	uassert.NoError(t, err)
	uassert.Equal(t, barBalance, "1000")

	quxBalance, err := node.MustKey("gno.land/r/onbloc/qux").GetString()
	uassert.NoError(t, err)
	uassert.Equal(t, quxBalance, "2000")
}

func TestApiGetUnrecordedBalance(t *testing.T) {
	// Reset protocol fee state
	pf := createTestProtocolFee(t)

	testing.SetRealm(adminRealm)
	if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
		bar.Burn(cross, protocolFeeAddr, balance)
	}
	if balance := qux.BalanceOf(protocolFeeAddr); balance > 0 {
		qux.Burn(cross, protocolFeeAddr, balance)
	}

	// Test case 1: Unrecorded amounts exist
	bar.Transfer(cross, protocolFeeAddr, 1500)
	qux.Transfer(cross, protocolFeeAddr, 2500)

	// Record only part of the amounts (use internal state for testing)
	pf.store.SetTokenListWithAmountItem("gno.land/r/onbloc/bar", 1000)
	pf.store.SetTokenListWithAmountItem("gno.land/r/onbloc/qux", 2000)

	result := pf.ApiGetUnrecordedBalance()

	node := json.Must(json.Unmarshal([]byte(result)))

	// Verify metadata fields
	uassert.True(t, node.HasKey("height"))
	uassert.True(t, node.HasKey("now"))

	// Verify unrecorded balances (actual - recorded)
	barBalance, err := node.MustKey("gno.land/r/onbloc/bar").GetString()
	uassert.NoError(t, err)
	uassert.Equal(t, barBalance, "500") // 1500 - 1000

	quxBalance, err := node.MustKey("gno.land/r/onbloc/qux").GetString()
	uassert.NoError(t, err)
	uassert.Equal(t, quxBalance, "500") // 2500 - 2000
}

func TestApiGetUnrecordedBalance_NoUnrecorded(t *testing.T) {
	pf := createTestProtocolFee(t)

	testing.SetRealm(adminRealm)
	testing.SetOriginCaller(adminAddr)
	if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
		bar.Burn(cross, protocolFeeAddr, balance)
	}

	// Transfer exact amount that will be recorded
	bar.Transfer(cross, protocolFeeAddr, 1000)

	// Record the exact amount (use internal state for testing)
	pf.store.SetTokenListWithAmountItem("gno.land/r/onbloc/bar", 1000)

	// Call API function
	result := pf.ApiGetUnrecordedBalance()

	// Parse JSON response
	node := json.Must(json.Unmarshal([]byte(result)))

	// Verify metadata fields
	uassert.True(t, node.HasKey("height"))
	uassert.True(t, node.HasKey("now"))

	// Should not have bar token as there's no unrecorded amount
	uassert.False(t, node.HasKey("gno.land/r/onbloc/bar"))
}

func TestApi_GetActualBalance_ZeroBalances(t *testing.T) {
	// Given
	pf := createTestProtocolFee(t)

	testing.SetRealm(adminRealm)
	// Ensure zero balances
	if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
		bar.Burn(cross, protocolFeeAddr, balance)
	}
	if balance := qux.BalanceOf(protocolFeeAddr); balance > 0 {
		qux.Burn(cross, protocolFeeAddr, balance)
	}

	// Record tokens but with zero balance
	pf.getProtocolFeeState().TokenListWithAmounts()["gno.land/r/onbloc/bar"] = 0
	pf.getProtocolFeeState().TokenListWithAmounts()["gno.land/r/onbloc/qux"] = 0

	// When
	result := pf.ApiGetActualBalance()

	// Then
	node := json.Must(json.Unmarshal([]byte(result)))

	uassert.True(t, node.HasKey("height"))
	uassert.True(t, node.HasKey("now"))

	// Verify zero balances
	barBalance, err := node.MustKey("gno.land/r/onbloc/bar").GetString()
	uassert.NoError(t, err)
	uassert.Equal(t, barBalance, "0")

	quxBalance, err := node.MustKey("gno.land/r/onbloc/qux").GetString()
	uassert.NoError(t, err)
	uassert.Equal(t, quxBalance, "0")
}

func TestApi_GetUnrecordedBalance_LargeDiscrepancy(t *testing.T) {
	// Given
	pf := createTestProtocolFee(t)

	testing.SetRealm(adminRealm)
	if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
		bar.Burn(cross, protocolFeeAddr, balance)
	}

	// Transfer large amount
	bar.Transfer(cross, protocolFeeAddr, 10000000)

	// Record very small amount
	pf.getProtocolFeeState().TokenListWithAmounts()["gno.land/r/onbloc/bar"] = 1

	// When
	result := pf.ApiGetUnrecordedBalance()

	// Then
	node := json.Must(json.Unmarshal([]byte(result)))

	uassert.True(t, node.HasKey("height"))
	uassert.True(t, node.HasKey("now"))

	// Verify large unrecorded amount
	barBalance, err := node.MustKey("gno.land/r/onbloc/bar").GetString()
	uassert.NoError(t, err)
	uassert.Equal(t, barBalance, "9999999") // 10000000 - 1
}

func TestApi_GetAccuTransferToGovStaker_SingleToken(t *testing.T) {
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

func TestApi_GetAccuTransferToDevOps_SingleToken(t *testing.T) {
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

func TestApi_GetRecordedBalance_SingleToken(t *testing.T) {
	// Given
	pf := createTestProtocolFee(t)
	pf.getProtocolFeeState().TokenListWithAmounts()["gno.land/r/onbloc/bar"] = 500

	// When
	result := pf.ApiGetRecordedBalance()

	// Then
	node := json.Must(json.Unmarshal([]byte(result)))

	uassert.True(t, node.HasKey("height"))
	uassert.True(t, node.HasKey("now"))

	barBalance, err := node.MustKey("gno.land/r/onbloc/bar").GetString()
	uassert.NoError(t, err)
	uassert.Equal(t, barBalance, "500")
}

func TestApi_GetUnrecordedBalance_MultipleTokens_MixedDiscrepancies(t *testing.T) {
	// Given
	pf := createTestProtocolFee(t)

	testing.SetRealm(adminRealm)
	if balance := bar.BalanceOf(protocolFeeAddr); balance > 0 {
		bar.Burn(cross, protocolFeeAddr, balance)
	}
	if balance := qux.BalanceOf(protocolFeeAddr); balance > 0 {
		qux.Burn(cross, protocolFeeAddr, balance)
	}

	// Set up different scenarios
	bar.Transfer(cross, protocolFeeAddr, 5000) // Has unrecorded
	qux.Transfer(cross, protocolFeeAddr, 3000) // Exact match

	pf.getProtocolFeeState().TokenListWithAmounts()["gno.land/r/onbloc/bar"] = 2000
	pf.getProtocolFeeState().TokenListWithAmounts()["gno.land/r/onbloc/qux"] = 3000

	// When
	result := pf.ApiGetUnrecordedBalance()

	// Then
	node := json.Must(json.Unmarshal([]byte(result)))

	uassert.True(t, node.HasKey("height"))
	uassert.True(t, node.HasKey("now"))

	// bar should have unrecorded amount
	barBalance, err := node.MustKey("gno.land/r/onbloc/bar").GetString()
	uassert.NoError(t, err)
	uassert.Equal(t, barBalance, "3000") // 5000 - 2000

	// qux should not appear (no unrecorded amount)
	uassert.False(t, node.HasKey("gno.land/r/onbloc/qux"))
}

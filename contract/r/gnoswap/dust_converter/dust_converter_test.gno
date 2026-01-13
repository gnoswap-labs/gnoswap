package dust_converter

import (
	"chain/runtime"
	"strconv"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/router"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/rbac"
	_ "gno.land/r/onbloc/bar"
	_ "gno.land/r/onbloc/baz"
)

const (
	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
)

var (
	adminAddr  = access.MustGetAddress(prabc.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	userAddr  = testutils.TestAddress("user")
	userRealm = testing.NewCodeRealm("gno.land/r/dust_converter/user")

	dustConverterRealm = testing.NewCodeRealm("gno.land/r/gnoswap/dust_converter")
)

type mockRouter struct {
	dryResultIn  string
	dryResultOut string
	drySuccess   bool
	dryCalls     int

	exactInSingleResultIn  string
	exactInSingleResultOut string
	exactInSingleCalls     int
}

func (m *mockRouter) ExactInSingleSwapRoute(
	inputToken string,
	outputToken string,
	amountIn string,
	routeArr string,
	amountOutMin string,
	sqrtPriceLimitX96 string,
	deadline int64,
	referrer string,
) (string, string) {
	m.exactInSingleCalls++
	return m.exactInSingleResultIn, m.exactInSingleResultOut
}

func (m *mockRouter) DrySwapRoute(
	inputToken string,
	outputToken string,
	specifiedAmount string,
	swapTypeStr string,
	strRouteArr string,
	quoteArr string,
	tokenAmountLimit string,
) (string, string, bool) {
	m.dryCalls++
	return m.dryResultIn, m.dryResultOut, m.drySuccess
}

func (m *mockRouter) ExactInSwapRoute(string, string, string, string, string, string, int64, string) (string, string) {
	panic("unexpected ExactInSwapRoute call")
}

func (m *mockRouter) ExactOutSwapRoute(string, string, string, string, string, string, int64, string) (string, string) {
	panic("unexpected ExactOutSwapRoute call")
}

func (m *mockRouter) ExactOutSingleSwapRoute(string, string, string, string, string, string, int64, string) (string, string) {
	panic("unexpected ExactOutSingleSwapRoute call")
}

func (m *mockRouter) SwapCallback(string, string, int64, int64, address) error {
	panic("unexpected SwapCallback call")
}

func (m *mockRouter) GetSwapFee() uint64 { return 0 }
func (m *mockRouter) SetSwapFee(uint64)  {}

var mockRouterCounter int

func registerMockRouter(t *testing.T, mock router.IRouter) string {
	t.Helper()

	mockRouterCounter++
	mockPath := "gno.land/r/gnoswap/router/mock_test_" + strconv.Itoa(mockRouterCounter)
	mockRealm := testing.NewCodeRealm(mockPath)

	testing.SetRealm(mockRealm)
	router.RegisterInitializer(cross, func(store router.IRouterStore) router.IRouter {
		return mock
	})

	testing.SetRealm(adminRealm)
	router.UpgradeImpl(cross, mockPath)

	return mockPath
}

func resetConfig(t *testing.T) {
	t.Helper()
	resetDefaults()
}

func resetDefaults() {
	dustMinAmount = 1
	dustMaxAmount = 0
	cooldownSeconds = 0
	lastExecutedTimestamp = 0
}

func createPoolIfNeeded(t *testing.T, token0, token1 string) {
	t.Helper()

	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	poolPath := pool.GetPoolPath(token0, token1, feeTier)
	if pool.ExistsPoolPath(poolPath) {
		return
	}

	pool.CreatePool(cross, token0, token1, feeTier, "79228162514264337593543950336")
}

func callConvertDustToGns(
	t *testing.T,
	caller runtime.Realm,
	pairs string,
	deadline int64,
	recipient address,
) int64 {
	t.Helper()
	var result int64
	testing.SetRealm(caller)
	func(cur realm) {
		testing.SetRealm(dustConverterRealm)
		result = ConvertDustToGns(cross, pairs, deadline, recipient)
	}(cross)
	return result
}

func TestConvertDustToGns_Success(t *testing.T) {
	resetConfig(t)
	mock := &mockRouter{
		dryResultIn:            "3",
		dryResultOut:           "-5",
		drySuccess:             true,
		exactInSingleResultIn:  "3",
		exactInSingleResultOut: "5",
	}
	_ = registerMockRouter(t, mock)

	createPoolIfNeeded(t, barPath, gnsTokenPath)

	testing.SetRealm(adminRealm)
	gns.Transfer(cross, dustConverterAddr, 7)
	common.SafeGRC20Transfer(cross, barPath, dustConverterAddr, 3)

	beforeRecipientGns := gns.BalanceOf(userAddr)

	totalGnsOut := callConvertDustToGns(
		t,
		userRealm,
		barPath+":3,"+gnsTokenPath+":2",
		time.Now().Add(time.Hour).Unix(),
		userAddr,
	)

	uassert.Equal(t, int64(7), totalGnsOut, "totalGnsOut mismatch")
	uassert.Equal(t, 1, mock.dryCalls, "dry swap call count mismatch")
	uassert.Equal(t, 1, mock.exactInSingleCalls, "exactInSingle call count mismatch")
	uassert.Equal(t, int64(7), gns.BalanceOf(userAddr)-beforeRecipientGns, "recipient GNS delta mismatch")
}

func TestConvertDustToGns_LengthMismatch(t *testing.T) {
	resetConfig(t)

	uassert.AbortsContains(t, "invalid pair", func() {
		callConvertDustToGns(
			t,
			userRealm,
			barPath+":1:2",
			time.Now().Unix(),
			userAddr,
		)
	})
}

func TestConvertDustToGns_Cooldown(t *testing.T) {
	resetConfig(t)
	cooldownSeconds = 100
	lastExecutedTimestamp = time.Now().Unix()

	uassert.AbortsContains(t, "cooldown not elapsed", func() {
		callConvertDustToGns(
			t,
			userRealm,
			barPath+":1",
			time.Now().Unix(),
			userAddr,
		)
	})
}

func TestConvertDustToGns_AmountExceedsBalance(t *testing.T) {
	resetConfig(t)

	amount := common.BalanceOf(barPath, dustConverterAddr) + 1
	uassert.AbortsContains(t, "should be <= balance", func() {
		callConvertDustToGns(
			t,
			userRealm,
			barPath+":"+strconv.FormatInt(amount, 10),
			time.Now().Unix(),
			userAddr,
		)
	})
}

func TestConvertDustToGns_SkipsMissingPool(t *testing.T) {
	resetConfig(t)
	mock := &mockRouter{
		dryResultIn:            "1",
		dryResultOut:           "1",
		drySuccess:             true,
		exactInSingleResultIn:  "1",
		exactInSingleResultOut: "1",
	}
	_ = registerMockRouter(t, mock)

	testing.SetRealm(adminRealm)
	gns.Transfer(cross, dustConverterAddr, 1)
	common.SafeGRC20Transfer(cross, bazPath, dustConverterAddr, 1)

	totalGnsOut := callConvertDustToGns(
		t,
		userRealm,
		bazPath+":1",
		time.Now().Unix(),
		userAddr,
	)

	uassert.Equal(t, int64(0), totalGnsOut, "totalGnsOut mismatch")
	uassert.Equal(t, 0, mock.dryCalls, "dry swap should not be called")
	uassert.Equal(t, int64(0), lastExecutedTimestamp, "lastExecutedTimestamp should not update")
}

func TestConvertDustToGns_SkipsDrySwapFailure(t *testing.T) {
	resetConfig(t)
	mock := &mockRouter{
		dryResultIn:            "1",
		dryResultOut:           "1",
		drySuccess:             false,
		exactInSingleResultIn:  "1",
		exactInSingleResultOut: "1",
	}
	_ = registerMockRouter(t, mock)

	createPoolIfNeeded(t, barPath, gnsTokenPath)

	testing.SetRealm(adminRealm)
	gns.Transfer(cross, dustConverterAddr, 1)
	common.SafeGRC20Transfer(cross, barPath, dustConverterAddr, 1)

	totalGnsOut := callConvertDustToGns(
		t,
		userRealm,
		barPath+":1",
		time.Now().Unix(),
		userAddr,
	)

	uassert.Equal(t, int64(0), totalGnsOut, "totalGnsOut mismatch")
	uassert.Equal(t, 1, mock.dryCalls, "dry swap should be called once")
	uassert.Equal(t, 0, mock.exactInSingleCalls, "exactInSingle should not be called")
}

func TestConvertDustToGns_InvalidDrySwapOutput(t *testing.T) {
	resetConfig(t)
	mock := &mockRouter{
		dryResultIn:            "1",
		dryResultOut:           "notnum",
		drySuccess:             true,
		exactInSingleResultIn:  "1",
		exactInSingleResultOut: "1",
	}
	_ = registerMockRouter(t, mock)

	createPoolIfNeeded(t, barPath, gnsTokenPath)

	testing.SetRealm(adminRealm)
	gns.Transfer(cross, dustConverterAddr, 1)
	common.SafeGRC20Transfer(cross, barPath, dustConverterAddr, 1)

	uassert.AbortsContains(t, "invalid syntax", func() {
		callConvertDustToGns(
			t,
			userRealm,
			barPath+":1",
			time.Now().Unix(),
			userAddr,
		)
	})
}

func TestConvertDustToGns_GnsOnly(t *testing.T) {
	resetConfig(t)
	mock := &mockRouter{
		dryResultIn:            "1",
		dryResultOut:           "1",
		drySuccess:             true,
		exactInSingleResultIn:  "1",
		exactInSingleResultOut: "1",
	}
	_ = registerMockRouter(t, mock)

	testing.SetRealm(adminRealm)
	gns.Transfer(cross, dustConverterAddr, 2)

	beforeRecipientGns := gns.BalanceOf(userAddr)

	totalGnsOut := callConvertDustToGns(
		t,
		userRealm,
		gnsTokenPath+":2",
		time.Now().Unix(),
		userAddr,
	)

	uassert.Equal(t, int64(2), totalGnsOut, "totalGnsOut mismatch")
	uassert.Equal(t, 0, mock.dryCalls, "dry swap should not be called")
	uassert.Equal(t, int64(2), gns.BalanceOf(userAddr)-beforeRecipientGns, "recipient GNS delta mismatch")
}

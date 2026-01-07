package v1

import (
	"strconv"
	"testing"

	"gno.land/p/nt/testutils"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac" // Initialize contract roles

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/router"
)

var (
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	stakerAddr = access.MustGetAddress(prbac.ROLE_STAKER.String())

	adminRealm = testing.NewUserRealm(adminAddr)
	adminUser  = adminAddr

	dummyRealm = testing.NewCodeRealm("gno.land/r/dummy")
	aliceAddr  = testutils.TestAddress("alice")

	// contract paths
	poolPath        = "gno.land/r/gnoswap/pool"
	positionPath    = "gno.land/r/gnoswap/position"
	routerPath      = "gno.land/r/gnoswap/router"
	stakerPath      = "gno.land/r/gnoswap/staker"
	govStakerPath   = "gno.land/r/gnoswap/gov/staker"
	protocolFeePath = "gno.land/r/gnoswap/protocol_fee"

	stakerRealm    = testing.NewCodeRealm(stakerPath)
	govStakerRealm = testing.NewCodeRealm(govStakerPath)

	protocolFeeRealm = testing.NewCodeRealm(protocolFeePath)
)

// createTestProtocolFee creates a fresh protocolFeeV1 instance for testing
func createTestProtocolFee(t *testing.T) *protocolFeeV1 {
	t.Helper()

	return &protocolFeeV1{
		store: newMockProtocolFeeStore(),
	}
}

type mockRouter struct {
	exactInResultIn  string
	exactInResultOut string
	exactInCalls     int
}

func (m *mockRouter) ExactInSwapRoute(
	inputToken string,
	outputToken string,
	amountIn string,
	routeArr string,
	quoteArr string,
	amountOutMin string,
	deadline int64,
	referrer string,
) (string, string) {
	m.exactInCalls++
	return m.exactInResultIn, m.exactInResultOut
}

func (m *mockRouter) ExactInSingleSwapRoute(string, string, string, string, string, string, int64, string) (string, string) {
	panic("unexpected ExactInSingleSwapRoute call")
}

func (m *mockRouter) ExactOutSwapRoute(string, string, string, string, string, string, int64, string) (string, string) {
	panic("unexpected ExactOutSwapRoute call")
}

func (m *mockRouter) ExactOutSingleSwapRoute(string, string, string, string, string, string, int64, string) (string, string) {
	panic("unexpected ExactOutSingleSwapRoute call")
}

func (m *mockRouter) DrySwapRoute(string, string, string, string, string, string, string) (string, string, bool) {
	panic("unexpected DrySwapRoute call")
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

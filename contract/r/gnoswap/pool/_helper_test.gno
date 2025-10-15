package pool

import (
	"chain/runtime"
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/gnoswap/store"
	u256 "gno.land/p/gnoswap/uint256"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
)

var adminAddr = access.MustGetAddress(prbac.ROLE_ADMIN.String())

// Mock implementation for testing
type mockPoolImpl struct {
	store            IPoolStore
	version          string
	createPoolCalled bool
	mintCalled       bool
	burnCalled       bool
	swapCalled       bool
}

func (m *mockPoolImpl) CreatePool(token0Path, token1Path string, fee uint32, sqrtPriceX96 string) {
	m.createPoolCalled = true
}

func (m *mockPoolImpl) SetPoolCreationFee(poolCreationFee int64)    {}
func (m *mockPoolImpl) SetWithdrawalFeeBPS(withdrawalFeeBPS uint64) {}

func (m *mockPoolImpl) Mint(token0Path, token1Path string, fee uint32, tickLower, tickUpper int32, liquidityAmount string, positionCaller address) (string, string) {
	m.mintCalled = true
	return "0", "0"
}

func (m *mockPoolImpl) Burn(token0Path, token1Path string, fee uint32, tickLower, tickUpper int32, liquidityAmount string, positionCaller address) (string, string) {
	m.burnCalled = true
	return "0", "0"
}

func (m *mockPoolImpl) Collect(token0Path, token1Path string, fee uint32, recipient address, tickLower, tickUpper int32, amount0Requested, amount1Requested string) (string, string) {
	return "0", "0"
}

func (m *mockPoolImpl) Swap(token0Path, token1Path string, fee uint32, recipient address, zeroForOne bool, amountSpecified, sqrtPriceLimitX96 string, caller address) (string, string) {
	m.swapCalled = true
	return "0", "0"
}

func (m *mockPoolImpl) DrySwap(token0Path, token1Path string, fee uint32, zeroForOne bool, amountSpecified, sqrtPriceLimitX96 string) (string, string) {
	return "0", "0"
}

func (m *mockPoolImpl) CollectProtocol(token0Path, token1Path string, fee uint32, recipient address, amount0Requested, amount1Requested string) (string, string) {
	return "0", "0"
}

func (m *mockPoolImpl) SetFeeProtocol(feeProtocol0, feeProtocol1 uint8) {}

func (m *mockPoolImpl) GetPoolPath(token0Path, token1Path string, fee uint32) string {
	return "mock_pool_path"
}

func (m *mockPoolImpl) GetSlot0SqrtPriceX96(poolPath string) *u256.Uint {
	return u256.NewUint(0)
}

func (m *mockPoolImpl) GetSlot0Tick(poolPath string) int32 {
	return 0
}

func (m *mockPoolImpl) GetLiquidity(poolPath string) string {
	return "0"
}

func (m *mockPoolImpl) GetBalanceToken0(poolPath string) string {
	return "0"
}

func (m *mockPoolImpl) GetBalanceToken1(poolPath string) string {
	return "0"
}

func (m *mockPoolImpl) GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint) {
	return u256.NewUint(0), u256.NewUint(0)
}

func (m *mockPoolImpl) GetPositionFeeGrowthInsideLastX128(poolPath, key string) (*u256.Uint, *u256.Uint) {
	return u256.NewUint(0), u256.NewUint(0)
}

func (m *mockPoolImpl) GetObservation(poolPath string, secondsAgo int64) (int64, string, string, int64) {
	return 0, "0", "0", 0
}

func (m *mockPoolImpl) ExistsPoolPath(poolPath string) bool {
	return true
}

func (m *mockPoolImpl) ApiGetPool(poolPath string) string {
	return "{}"
}

func (m *mockPoolImpl) ApiGetTWAP(poolPath string, secondsAgo uint32) string {
	return "0"
}

// Helper functions for testing
func resetTestState(t *testing.T) {
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/pool"))

	kvStore = store.NewKVStore(runtime.CurrentRealm().Address())
	poolImpl = nil
	initializers = make(map[string]func(poolStore IPoolStore) IPool)
}

func makeMockInitializer(version string) func(poolStore IPoolStore) IPool {
	return func(poolStore IPoolStore) IPool {
		return &mockPoolImpl{
			store:   poolStore,
			version: version,
		}
	}
}

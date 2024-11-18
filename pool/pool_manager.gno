package pool

import (
	"std"
	"strings"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"

	en "gno.land/r/gnoswap/v2/emission"

	"gno.land/r/gnoswap/v2/gns"

	u256 "gno.land/p/gnoswap/uint256"
)

type poolMap map[string]*Pool

func (pm *poolMap) Get(poolPath string) (*Pool, bool) {
	pool, exist := (*pm)[poolPath]
	if !exist {
		return nil, false
	}

	return pool, true
}

func (pm *poolMap) Set(poolPath string, pool *Pool) {
	(*pm)[poolPath] = pool
}

type tickSpacingMap map[uint32]int32

func (t *tickSpacingMap) Get(fee uint32) int32 {
	return (*t)[fee]
}

var (
	feeAmountTickSpacing tickSpacingMap = make(tickSpacingMap) // maps fee to tickSpacing || map[feeAmount]tick_spacing
	pools                poolMap = make(poolMap) // maps poolPath to pool || map[poolPath]*Pool

	slot0FeeProtocol uint8 = 0
)

func init() {
	feeAmountTickSpacing[100] = 1     // 0.01%
	feeAmountTickSpacing[500] = 10    // 0.05%
	feeAmountTickSpacing[3000] = 60   // 0.3%
	feeAmountTickSpacing[10000] = 200 // 1%
}

type poolInput struct {
	token0Path, token1Path string
	fee                    uint32
	sqrtPriceX96           *u256.Uint
	tickSpacing            int32
}

func newPoolInput(
	token0Path string,
	token1Path string,
	fee uint32,
	sqrtPriceX96 string,
) *poolInput {
	price := u256.MustFromDecimal(sqrtPriceX96)
	tickSpacing := feeAmountTickSpacing.Get(fee)
	return &poolInput{
		token0Path: token0Path,
		token1Path: token1Path,
		fee:        fee,
		sqrtPriceX96: price,
		tickSpacing: tickSpacing,
	}
}

func (p *poolInput) isSameTokenPath() bool {
	return p.token0Path == p.token1Path
}

func (p *poolInput) isInOrder() bool {
	if strings.Compare(p.token0Path, p.token1Path) > 0 {
		return false
	}

	return true
}

func (p *poolInput) wrap() (string, string) {
	if p.token0Path == consts.GNOT {
		p.token0Path = consts.WRAPPED_WUGNOT
	}
	if p.token1Path == consts.GNOT {
		p.token1Path = consts.WRAPPED_WUGNOT
	}

	return p.token0Path, p.token1Path
}

func (p *poolInput) filterValidTokenPaths() (string, string, error) {
	if p.isSameTokenPath() {
		return "", "", errDuplicateTokenInPool
	}

	token0Path, token1Path := p.wrap()

	if !p.isInOrder() {
		return "", "", errTokenSortOrder
	}

	return token0Path, token1Path, nil
}

func (p *poolInput) Token0Path() string {
	return p.token0Path
}

func (p *poolInput) Token1Path() string {
	return p.token1Path
}

func (p *poolInput) Fee() uint32 {
	return p.fee
}

func (p *poolInput) TickSpacing() int32 {
	return p.tickSpacing
}

func (p *poolInput) SqrtPriceX96() *u256.Uint {
	return p.sqrtPriceX96
}

// CreatePool creates a new concentrated liquidity pool with the given parameters.
// It mints and distributes GNS tokens, validates the input parameters, and creates a new pool.
// If GNOT is used as one of the tokens, it is automatically wrapped to WUGNOT.
// The function ensures that token0Path is lexicographically smaller than token1Path.
// ref: https://docs.gnoswap.io/contracts/pool/pool_manager.gno#createpool
func CreatePool(
	token0Path string,
	token1Path string,
	fee uint32,
	_sqrtPriceX96 string,
) {
	common.IsHalted()
	en.MintAndDistributeGns()

	poolInfo := newPoolInput(token0Path, token1Path, fee, _sqrtPriceX96)

	token0Path, token1Path, err := poolInfo.filterValidTokenPaths()
	if err != nil {
		panic(err)
	}

	poolPath := GetPoolPath(token0Path, token1Path, fee)

	// TODO: make this as a parameter
	prevAddr, prevRealm := getPrev()

	// check whether the pool already exist
	pool, exist := pools.Get(poolPath)
	if exist {
		panic(addDetailToError(
			errPoolAlreadyExists,
			ufmt.Sprintf("pool_manager.gno__CreatePool() || expected poolPath(%s) not to exist", poolPath),
		))
	}

	gns.TransferFrom(a2u(std.PrevRealm().Addr()), a2u(consts.PROTOCOL_FEE_ADDR), poolCreationFee)

	std.Emit(
		"PoolCreationFee",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"internal_poolPath", poolPath,
		"internal_tokenPath", consts.GNS_PATH,
		"internal_amount", ufmt.Sprintf("%d", poolCreationFee),
	)

	pool = newPool(poolInfo)
	pools.Set(poolPath, pool)

	std.Emit(
		"CreatePool",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"token0Path", token0Path,
		"token1Path", token1Path,
		"fee", ufmt.Sprintf("%d", fee),
		"sqrtPriceX96", _sqrtPriceX96,
		"internal_poolPath", poolPath,
	)
}

// DoesPoolPathExist checks if a pool exists for the given poolPath.
// The poolPath is a unique identifier for a pool, combining token paths and fee.
func DoesPoolPathExist(poolPath string) bool {
	_, exist := pools[poolPath]
	return exist
}

// GetPool retrieves the pool for the given token paths and fee.
// It constructs the poolPath from the given parameters and returns the corresponding pool.
// Returns pool struct
func GetPool(token0Path, token1Path string, fee uint32) *Pool {
	poolPath := GetPoolPath(token0Path, token1Path, fee)
	pool, exist := pools[poolPath]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("pool_manager.gno__GetPool() || expected poolPath(%s) to exist", poolPath),
		))
	}

	return pool
}

// GetPoolFromPoolPath retrieves the pool for the given poolPath.
func GetPoolFromPoolPath(poolPath string) *Pool {
	pool, exist := pools[poolPath]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("pool_manager.gno__GetPoolFromPoolPath() || expected poolPath(%s) to exist", poolPath),
		))
	}

	return pool
}

// GetPoolPath generates a poolPath from the given token paths and fee.
// The poolPath is constructed by joining the token paths and fee with colons.
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	// TODO: this check is not unnecessary, if we are sure that
	// all the token paths in the pool are sorted in alphabetical order.
	if strings.Compare(token1Path, token0Path) < 0 {
		token0Path, token1Path = token1Path, token0Path
	}

	return ufmt.Sprintf("%s:%s:%d", token0Path, token1Path, fee)
}

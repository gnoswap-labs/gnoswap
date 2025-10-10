package pool

import (
	"strings"

	"gno.land/p/nt/ufmt"
	u256 "gno.land/p/gnoswap/uint256"
)

var Q192 = u256.Zero().Lsh(u256.One(), 192)

var (
	minSqrtRatio = u256.MustFromDecimal(MIN_SQRT_RATIO)
	maxSqrtRatio = u256.MustFromDecimal(MAX_SQRT_RATIO)
)

const (
	FeeTier100   uint32 = 100
	FeeTier500   uint32 = 500
	FeeTier3000  uint32 = 3000
	FeeTier10000 uint32 = 10000
)

const (
	GNOT           string = "gnot"
	WRAPPED_WUGNOT string = "gno.land/r/gnoland/wugnot"
)

const (
	MIN_SQRT_RATIO string = "4295128739"
	MAX_SQRT_RATIO string = "1461446703485210103287273052203988822378723970342"
)

// poolCreateConfig holds the essential parameters for creating a new pool.
type poolCreateConfig struct {
	token0Path   string
	token1Path   string
	fee          uint32
	sqrtPriceX96 *u256.Uint
	tickSpacing  int32
}

// newPoolParams defines the essential parameters for creating a new pool.
func newPoolParams(
	token0Path string,
	token1Path string,
	fee uint32,
	sqrtPriceX96 string,
	tickSpacing int32,
) *poolCreateConfig {
	price := u256.MustFromDecimal(sqrtPriceX96)
	return &poolCreateConfig{
		token0Path:   token0Path,
		token1Path:   token1Path,
		fee:          fee,
		sqrtPriceX96: price,
		tickSpacing:  tickSpacing,
	}
}

func (p *poolCreateConfig) SqrtPriceX96() *u256.Uint { return p.sqrtPriceX96 }
func (p *poolCreateConfig) TickSpacing() int32       { return p.tickSpacing }
func (p *poolCreateConfig) Token0Path() string       { return p.token0Path }
func (p *poolCreateConfig) Token1Path() string       { return p.token1Path }
func (p *poolCreateConfig) Fee() uint32              { return p.fee }

func (p *poolCreateConfig) updateWithWrapping() (*poolCreateConfig, error) {
	token0Path, token1Path := p.wrap()

	// Always validate that the price is within valid range
	if err := validateSqrtPriceX96(p.sqrtPriceX96); err != nil {
		return nil, err
	}

	if !p.isInOrder() {
		token0Path, token1Path = token1Path, token0Path

		// newPrice = 2^192 / oldPrice
		newPrice := u256.Zero().Div(Q192, p.sqrtPriceX96)

		// Check if calculated price is within valid range
		if err := validateSqrtPriceX96(newPrice); err != nil {
			return nil, err
		}

		p.sqrtPriceX96 = newPrice
	}
	return newPoolParams(token0Path, token1Path, p.fee, p.sqrtPriceX96.ToString(), GetFeeAmountTickSpacing(p.fee)), nil
}

func (p *poolCreateConfig) isSameTokenPath() bool {
	return p.token0Path == p.token1Path
}

// isInOrder checks if token paths are in lexicographical (or, alphabetical) order
func (p *poolCreateConfig) isInOrder() bool {
	if strings.Compare(p.token0Path, p.token1Path) < 0 {
		return true
	}
	return false
}

func (p *poolCreateConfig) wrap() (string, string) {
	if p.token0Path == GNOT {
		p.token0Path = WRAPPED_WUGNOT
	}
	if p.token1Path == GNOT {
		p.token1Path = WRAPPED_WUGNOT
	}
	return p.token0Path, p.token1Path
}

func (p *poolCreateConfig) poolPath() string {
	return GetPoolPath(p.token0Path, p.token1Path, p.fee)
}

func (p *poolCreateConfig) isSupportedFee(feeTier uint32) bool {
	switch feeTier {
	case FeeTier100, FeeTier500, FeeTier3000, FeeTier10000:
		return true
	}
	return false
}

// validateSqrtPriceX96 validates that the given sqrtPriceX96 is within valid range
func validateSqrtPriceX96(sqrtPriceX96 *u256.Uint) error {
	if sqrtPriceX96.Lt(minSqrtRatio) || sqrtPriceX96.Gt(maxSqrtRatio) {
		return makeErrorWithDetails(
			errOutOfRange,
			ufmt.Sprintf("sqrtPriceX96(%s) is out of range", sqrtPriceX96.ToString()),
		)
	}
	return nil
}

func isValidFeeTier(feeTier uint32) bool {
	switch feeTier {
	case FeeTier100, FeeTier500, FeeTier3000, FeeTier10000:
		return true
	}

	return false
}

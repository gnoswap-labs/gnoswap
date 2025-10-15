package v1

import (
	"strings"

	u256 "gno.land/p/gnoswap/uint256"
)

// poolCreateConfig holds the essential parameters for creating a new pool.
type poolCreateConfig struct {
	token0Path       string
	token1Path       string
	fee              uint32
	sqrtPriceX96     *u256.Uint
	tickSpacing      int32
	slot0FeeProtocol uint8
}

// newPoolParams defines the essential parameters for creating a new pool.
func newPoolParams(
	token0Path string,
	token1Path string,
	fee uint32,
	sqrtPriceX96 string,
	tickSpacing int32,
	slot0FeeProtocol uint8,
) *poolCreateConfig {
	price := u256.MustFromDecimal(sqrtPriceX96)
	return &poolCreateConfig{
		token0Path:       token0Path,
		token1Path:       token1Path,
		fee:              fee,
		sqrtPriceX96:     price,
		tickSpacing:      tickSpacing,
		slot0FeeProtocol: slot0FeeProtocol,
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

	return newPoolParams(token0Path, token1Path, p.fee, p.sqrtPriceX96.ToString(), p.tickSpacing, p.slot0FeeProtocol), nil
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
	return MakePoolPath(p.token0Path, p.token1Path, p.fee)
}

func (p *poolCreateConfig) isSupportedFee(feeTier uint32) bool {
	switch feeTier {
	case FeeTier100, FeeTier500, FeeTier3000, FeeTier10000:
		return true
	}
	return false
}

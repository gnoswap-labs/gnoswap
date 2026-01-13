package orderbook

import (
	u256 "gno.land/p/gnoswap/uint256"
)

// tickToPrice converts a tick index to a price using geometric + additive model
// price(tick) = 10^(tick / 9_000_000) + additive_component
//
// This supports a massive price range from 10^-55 to 10^61
func tickToPrice(tickId int64) *u256.Uint {
	if tickId < MIN_TICK || tickId > MAX_TICK {
		panic(ErrInvalidTickId)
	}

	// For simplicity, we use a power-of-10 approximation
	// Real implementation would need fixed-point math for precision

	exponent := tickId / GEOMETRIC_EXPONENT_INCREMENT_DISTANCE
	remainder := tickId % GEOMETRIC_EXPONENT_INCREMENT_DISTANCE

	// Base price = 10^exponent (scaled by 1e18 for fixed point)
	basePrice := powerOfTen(exponent)

	// Add additive component for fine-grained pricing within exponent band
	if remainder != 0 {
		increment := new(u256.Uint).Mul(basePrice, u256.NewUint(uint64(remainder)))
		increment = new(u256.Uint).Div(increment, u256.NewUint(GEOMETRIC_EXPONENT_INCREMENT_DISTANCE))
		basePrice = new(u256.Uint).Add(basePrice, increment)
	}

	return basePrice
}

// powerOfTen returns 10^exp scaled by 1e18 for fixed-point representation
func powerOfTen(exp int64) *u256.Uint {
	base := u256.NewUint(10)
	result := u256.NewUint(1)

	// Scale by 1e18 for fixed point
	scale := u256.NewUint(1000000000000000000) // 1e18
	result = new(u256.Uint).Mul(result, scale)

	if exp == 0 {
		return result
	}

	if exp > 0 {
		for i := int64(0); i < exp; i++ {
			result = new(u256.Uint).Mul(result, base)
		}
	} else {
		for i := int64(0); i < -exp; i++ {
			result = new(u256.Uint).Div(result, base)
		}
	}

	return result
}

// amountToValue converts an amount to its value using tick price
// value = amount * price
func amountToValue(amount *u256.Uint, tickId int64) *u256.Uint {
	price := tickToPrice(tickId)
	value := new(u256.Uint).Mul(amount, price)

	// Divide by 1e18 to remove fixed-point scaling
	scale := u256.NewUint(1000000000000000000)
	return new(u256.Uint).Div(value, scale)
}

// valueToAmount converts a value to an amount using tick price
// amount = value / price
func valueToAmount(value *u256.Uint, tickId int64) *u256.Uint {
	price := tickToPrice(tickId)

	// Multiply by 1e18 before division to maintain precision
	scale := u256.NewUint(1000000000000000000)
	scaledValue := new(u256.Uint).Mul(value, scale)

	return new(u256.Uint).Div(scaledValue, price)
}

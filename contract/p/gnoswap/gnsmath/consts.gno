package gnsmath

const (
	// minTick is the minimum valid tick index in the concentrated liquidity model.
	// Represents the lowest possible price: 1.0001^(-887272) ≈ 0
	minTick = -887272

	// maxTick is the maximum valid tick index in the concentrated liquidity model.
	// Represents the highest possible price: 1.0001^887272 ≈ infinity
	maxTick = 887272

	Q96_RESOLUTION  uint = 96
	Q160_RESOLUTION uint = 160

	MAX_UINT128 = "340282366920938463463374607431768211455" // 2^128 - 1
	Q96         = "79228162514264337593543950336"           // 2^96
)

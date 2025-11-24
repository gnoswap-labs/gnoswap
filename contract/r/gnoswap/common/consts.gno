package common

const (
	// minTick is the minimum valid tick index in the concentrated liquidity model.
	// Represents the lowest possible price: 1.0001^(-887272) ≈ 0
	minTick = -887272

	// maxTick is the maximum valid tick index in the concentrated liquidity model.
	// Represents the highest possible price: 1.0001^887272 ≈ infinity
	maxTick = 887272

	// GNOT_DENOM is the denomination for native GNOT tokens.
	// ugnot is the smallest unit of GNOT (1 GNOT = 1,000,000 ugnot).
	// Used in banker operations, pool pairs, and swap paths.
	GNOT_DENOM = "ugnot"

	// WUGNOT_PATH is the package path for wrapped GNOT (wugnot) token.
	// Wrapped GNOT is an GRC20 representation of native GNOT for DeFi operations.
	WUGNOT_PATH = "gno.land/r/gnoland/wugnot"
)

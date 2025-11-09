package common

const (
	// minTick is the minimum valid tick index in the concentrated liquidity model.
	// Represents the lowest possible price: 1.0001^(-887272) ≈ 0
	minTick = -887272

	// maxTick is the maximum valid tick index in the concentrated liquidity model.
	// Represents the highest possible price: 1.0001^887272 ≈ infinity
	maxTick = 887272

	// GNOT_DENOM is the denomination for native GNOT tokens in the blockchain.
	// Used in banker operations for native coin transfers.
	GNOT_DENOM = "ugnot"

	// GNOT_PATH is the path identifier for native GNOT in GnoSwap.
	// Used to identify native GNOT in pool pairs and swap paths.
	GNOT_PATH = "gnot"

	// WUGNOT_PATH is the package path for wrapped GNOT (wugnot) token.
	// Wrapped GNOT is an GRC20 representation of native GNOT for DeFi operations.
	WUGNOT_PATH = "gno.land/r/gnoland/wugnot"
)

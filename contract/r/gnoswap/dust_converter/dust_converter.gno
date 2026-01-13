package dust_converter

import (
	"chain"
	"chain/runtime"
	"strconv"
	"strings"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/router"

	prabc "gno.land/p/gnoswap/rbac"
)

const (
	gnsTokenPath   = "gno.land/r/gnoswap/gns"
	feeBps         = uint64(0)
	feeDenominator = int64(10_000)
)

var (
	dustConverterAddr = chain.PackageAddress("gno.land/r/gnoswap/dust_converter")
	feeTierCandidates = []uint32{100, 500, 3000, 10000}

	// targetAssets is a map of tokens that can be converted.
	// This map can be updated through governance or admin.
	//
	// Note: Since dust conversion operation only require existence checks and
	// add/remove operations, we use a map data structure instead of AVL.
	targetAssets map[string]bool

	// Setting the minimum amount to 1(≈ 0.000001) cause dryswap to fail
	// in most cases. To avoid unnecessary checks and iterations, `dustMinAmount`
	// should be set to a value greater than 1.
	//
	// If a more effective value is discovered, it can be also changed later
	// through governance or admin.
	dustMinAmount int64 = 10
	dustMaxAmount int64 = 10

	cooldownSeconds       int64
	lastExecutedTimestamp int64
)

func init() {
	targetAssets = map[string]bool{gnsTokenPath: true}
}

// SetDustMinAmount sets the minimum amount eligible for conversion.
// Only callable by admin or governance.
func SetDustMinAmount(cur realm, amount int64) {
	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	if amount < 0 {
		panic(makeErrorWithDetail(
			errInvalidAmount, "min amount must be non-negative"))
	}

	if dustMaxAmount > 0 && amount > dustMaxAmount {
		panic(makeErrorWithDetail(
			errInvalidAmount, ufmt.Sprintf("min(%d) should be <= max(%d)", amount, dustMaxAmount)))
	}

	dustMinAmount = amount
}

// SetDustMaxAmount sets the maximum amount eligible for conversion.
// Only callable by admin or governance.
func SetDustMaxAmount(cur realm, amount int64) {
	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	if amount < 0 {
		panic(makeErrorWithDetail(errInvalidAmount, "max amount must be non-negative"))
	}

	if amount > 0 && amount < dustMinAmount {
		panic(makeErrorWithDetail(errInvalidAmount,
			ufmt.Sprintf("max(%d) should be >= min(%d)", amount, dustMinAmount)))
	}

	dustMaxAmount = amount
}

// SetCooldownSeconds sets the cooldown window for conversions.
// Only callable by admin or governance.
func SetCooldownSeconds(cur realm, seconds int64) {
	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	if seconds < 0 {
		panic(makeErrorWithDetail(errInvalidInput, "cooldown must be non-negative"))
	}

	cooldownSeconds = seconds
}

func GetDustMinAmount() int64         { return dustMinAmount }
func GetDustMaxAmount() int64         { return dustMaxAmount }
func GetCooldownSeconds() int64       { return cooldownSeconds }
func GetLastExecutedTimestamp() int64 { return lastExecutedTimestamp }
func GetFeeBps() uint64               { return feeBps }

// AddTargetAsset registers a token path as a conversion target.
// Only callable by admin or governance.
func AddTargetAsset(cur realm, tokenPath string) {
	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	tokenPath = strings.TrimSpace(tokenPath)
	if tokenPath == "" {
		panic(makeErrorWithDetail(errInvalidInput, "target asset path is required"))
	}

	targetAssets[tokenPath] = true
}

// RemoveTargetAsset unregisters a token path as a conversion target.
// Only callable by admin or governance.
func RemoveTargetAsset(cur realm, tokenPath string) {
	caller := runtime.PreviousRealm().Address()
	access.AssertIsAdminOrGovernance(caller)

	tokenPath = strings.TrimSpace(tokenPath)
	if tokenPath == "" {
		panic(makeErrorWithDetail(errInvalidInput, "target asset path is required"))
	}

	if !targetAssets[tokenPath] {
		panic(makeErrorWithDetail(errInvalidInput, "target asset not found"))
	}

	delete(targetAssets, tokenPath)
}

// IsTargetAsset checks if the token path is registered as a conversion target.
func IsTargetAsset(tokenPath string) bool {
	tokenPath = strings.TrimSpace(tokenPath)
	return targetAssets[tokenPath]
}

// GetTargetAssets returns the list of registered target assets.
func GetTargetAssets() []string {
	assets := make([]string, 0, len(targetAssets))
	for tokenPath := range targetAssets {
		assets = append(assets, tokenPath)
	}
	return assets
}

// ConvertDustToGns swaps eligible dust tokens into target asset and transfers the total to recipient.
// Pairs format: "tokenA:100,tokenB:200".
func ConvertDustToGns(
	cur realm,
	targetPath string,
	pairs string,
	deadline int64,
	recipient address,
) int64 {
	targetPath = strings.TrimSpace(targetPath)
	if targetPath == "" {
		panic(makeErrorWithDetail(errInvalidInput, "target asset path is required"))
	}
	if !IsTargetAsset(targetPath) {
		panic(makeErrorWithDetail(errInvalidInput, "target asset not allowed"))
	}

	pairs = strings.TrimSpace(pairs)
	if pairs == "" {
		panic(makeErrorWithDetail(errInvalidInput, "pairs should not be empty"))
	}

	if cooldownSeconds > 0 {
		now := time.Now().Unix()
		if lastExecutedTimestamp > 0 && now < lastExecutedTimestamp+cooldownSeconds {
			panic(makeErrorWithDetail(
				errInvalidCooldown,
				ufmt.Sprintf("cooldown not elapsed: last=%d, now=%d", lastExecutedTimestamp, now),
			))
		}
	}

	totalGnsOut := int64(0)
	processedCount := 0

	for _, entry := range strings.Split(pairs, ",") {
		entry = strings.TrimSpace(entry)
		if entry == "" {
			panic(makeErrorWithDetail(errInvalidInput, "invalid pair: empty"))
		}

		parts := strings.Split(entry, ":")
		if len(parts) != 2 {
			panic(makeErrorWithDetail(errInvalidInput, ufmt.Sprintf("invalid pair(%s)", entry)))
		}

		tokenPath := strings.TrimSpace(parts[0])
		if tokenPath == "" {
			panic(makeErrorWithDetail(errInvalidInput, ufmt.Sprintf("invalid token in pair(%s)", entry)))
		}

		amount, err := strconv.ParseInt(strings.TrimSpace(parts[1]), 10, 64)
		if err != nil {
			panic(makeErrorWithDetail(errInvalidAmount, ufmt.Sprintf("invalid amount(%s)", parts[1])))
		}
		if amount < 0 {
			panic(makeErrorWithDetail(errInvalidAmount, ufmt.Sprintf("amount(%d) should be >= 0", amount)))
		}

		if amount <= 0 {
			continue
		}

		if amount < dustMinAmount {
			continue
		}

		if dustMaxAmount > 0 && amount > dustMaxAmount {
			continue
		}

		balance := common.BalanceOf(tokenPath, dustConverterAddr)
		if amount > balance {
			panic(makeErrorWithDetail(
				errInvalidAmount,
				ufmt.Sprintf("amount(%d) should be <= balance(%d)", amount, balance),
			))
		}

		if tokenPath == targetPath {
			net, _ := applyFee(amount)
			if net > 0 {
				totalGnsOut = safeAddInt64(totalGnsOut, net)
			}
			processedCount++
			continue
		}

		// Selects a pool with most largest liquidity for the token pair.
		feeTier, ok := selectBestFeeTier(tokenPath, targetPath)
		if !ok {
			continue
		}

		routeArr := tokenPath + ":" + targetPath + ":" + strconv.FormatUint(uint64(feeTier), 10)

		routerAddr := access.MustGetAddress(prabc.ROLE_ROUTER.String())
		common.SafeGRC20Approve(cross, tokenPath, routerAddr, amount)

		_, dryOutStr, success := router.DrySwapRoute(
			tokenPath,
			targetPath,
			strconv.FormatInt(amount, 10),
			"EXACT_IN",
			routeArr,
			"100",
			"1",
		)
		if !success {
			continue
		}

		dryOut, err := strconv.ParseInt(dryOutStr, 10, 64)
		if err != nil {
			panic(err)
		}
		if dryOut < 0 {
			dryOut = -dryOut
		}
		if dryOut <= 0 {
			continue
		}

		_, actualOutStr := router.ExactInSingleSwapRoute(
			cross,
			tokenPath,
			targetPath,
			strconv.FormatInt(amount, 10),
			routeArr,
			strconv.FormatInt(dryOut, 10),
			"0",
			deadline,
			"",
		)

		actualOut, err := strconv.ParseInt(actualOutStr, 10, 64)
		if err != nil {
			panic(err)
		}
		if actualOut < 0 {
			actualOut = -actualOut
		}

		net, _ := applyFee(actualOut)
		if net > 0 {
			totalGnsOut = safeAddInt64(totalGnsOut, net)
		}
		processedCount++
	}

	if totalGnsOut > 0 {
		common.SafeGRC20Transfer(cross, targetPath, recipient, totalGnsOut)
	}

	if processedCount > 0 {
		lastExecutedTimestamp = time.Now().Unix()
	}

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"ConvertDustToGns",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"recipient", recipient.String(),
		"targetPath", targetPath,
		"totalGnsOut", strconv.FormatInt(totalGnsOut, 10),
		"lastExecutedTimestamp", strconv.FormatInt(lastExecutedTimestamp, 10),
	)

	return totalGnsOut
}

func selectBestFeeTier(tokenPath, targetPath string) (uint32, bool) {
	var bestTier uint32
	var bestLiquidity *u256.Uint

	// The lookup cost itself is just a pool existence check
	// in a fixed-size array of fee tiers.
	for _, fee := range feeTierCandidates {
		poolPath := pool.GetPoolPath(tokenPath, targetPath, fee)
		if !pool.ExistsPoolPath(poolPath) {
			continue
		}

		liquidityStr := pool.GetLiquidity(poolPath)
		liquidity := u256.MustFromDecimal(liquidityStr)
		if bestLiquidity == nil || liquidity.Cmp(bestLiquidity) > 0 {
			bestTier = fee
			bestLiquidity = liquidity
		}
	}

	if bestLiquidity == nil {
		return 0, false
	}

	return bestTier, true
}

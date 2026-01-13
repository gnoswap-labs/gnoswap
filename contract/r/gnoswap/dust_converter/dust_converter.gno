package dust_converter

import (
	"chain"
	"chain/runtime"
	"strconv"
	"strings"
	"time"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/router"

	prabc "gno.land/p/gnoswap/rbac"
)

const (
	gnsTokenPath   = "gno.land/r/gnoswap/gns"
	feeTier        = uint32(500)
	feeBps         = uint64(0)
	feeDenominator = int64(10_000)
)

var (
	dustConverterAddr = chain.PackageAddress("gno.land/r/gnoswap/dust_converter")

	dustMinAmount         int64 = 1
	dustMaxAmount         int64 = 0
	cooldownSeconds       int64
	lastExecutedTimestamp int64
)

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

// ConvertDustToGns swaps eligible dust tokens into GNS and transfers the total to recipient.
// Pairs format: "tokenA:100,tokenB:200".
func ConvertDustToGns(
    cur realm,
	pairs string,
	deadline int64,
	recipient address,
) int64 {
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

		if tokenPath == gnsTokenPath {
			net, _ := applyFee(amount)
			if net > 0 {
				totalGnsOut = safeAddInt64(totalGnsOut, net)
			}
			processedCount++
			continue
		}

		poolPath := pool.GetPoolPath(tokenPath, gnsTokenPath, feeTier)
		if !pool.ExistsPoolPath(poolPath) {
			continue
		}

		routeArr := tokenPath + ":" + gnsTokenPath + ":" + strconv.FormatUint(uint64(feeTier), 10)

		routerAddr := access.MustGetAddress(prabc.ROLE_ROUTER.String())
		common.SafeGRC20Approve(cross, tokenPath, routerAddr, amount)

		_, dryOutStr, success := router.DrySwapRoute(
			tokenPath,
			gnsTokenPath,
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
			gnsTokenPath,
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
		common.SafeGRC20Transfer(cross, gnsTokenPath, recipient, totalGnsOut)
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
		"totalGnsOut", strconv.FormatInt(totalGnsOut, 10),
		"lastExecutedTimestamp", strconv.FormatInt(lastExecutedTimestamp, 10),
	)

	return totalGnsOut
}

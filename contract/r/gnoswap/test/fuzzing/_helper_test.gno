package fuzzing

import (
	"strings"
	"testing"

	"gno.land/p/gnoswap/fuzzing"
	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	pool_v1 "gno.land/r/gnoswap/pool/v1"
	position_v1 "gno.land/r/gnoswap/position/v1"
	router_v1 "gno.land/r/gnoswap/router/v1"

	_ "gno.land/r/onbloc/bar"
	_ "gno.land/r/onbloc/foo"
)

var (
	adminAddr = access.MustGetAddress(prabc.ROLE_ADMIN.String())

	initializedPool     = false
	initializedPosition = false
	initializedRouter   = false
)

func runFuzzTest(t *testing.T, iterations int, fn func(*fuzzing.T, *Result, int)) {
	fuzzingConfig := &fuzzing.Config{
		BaseSeed:   fuzzing.BASE_SEED,
		Iterations: iterations,
		Verbose:    true,
	}

	result := NewFuzzingResult(fuzzingConfig.BaseSeed)
	index := 0

	fuzzing.CheckWithConfig(t, fuzzingConfig, func(ft *fuzzing.T) {
		index++

		isAborted := false

		r := revive(func() {
			fn(ft, result, index)
		})

		if r != nil {
			isAborted = true

			abortStr := strings.TrimSpace(ufmt.Sprintf("%v", r))
			result.AddErrorMessage(index, abortStr)
		}

		if result.IsValidState(index) == isAborted {
			result.AddUnexpectedResult(index)
		}
	})

	result.PrintLog(t)

	if result.UnexpectedResultsCount() > 0 {
		panic(ufmt.Sprintf("Fuzzing test failed with %d unexpected results", result.UnexpectedResultsCount()))
	} else {
		t.Logf("\n=== RESULT: Fuzzing test passed %d iterations (success: %d, errors: %d)", iterations, result.SuccessCount(), result.ErrorMessagesCount())
	}
}

// initStates initializes the states for the fuzzing test
func initStates(t *testing.T) {
	initPoolState(t)
	initPositionState(t)
	initRouterState(t)
}

func initPoolState(t *testing.T) {
	t.Helper()
	const mockPoolPath = "gno.land/r/gnoswap/pool/mock"

	if !initializedPool {
		initializedPool = true

		testing.SetRealm(testing.NewCodeRealm(mockPoolPath))
		pool.RegisterInitializer(cross, func(_ pool.IPoolStore) pool.IPool {
			return pool_v1.NewPoolV1(newMockPoolStore())
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	pool.UpgradeImpl(cross, mockPoolPath)
}

func initPositionState(t *testing.T) {
	t.Helper()
	const mockPositionPath = "gno.land/r/gnoswap/position/mock"

	if !initializedPosition {
		initializedPosition = true

		testing.SetRealm(testing.NewCodeRealm(mockPositionPath))
		position.RegisterInitializer(cross, func(_ position.IPositionStore) position.IPosition {
			return position_v1.NewPositionV1(newMockPositionStore(), newMockNFTAccessor())
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	position.UpgradeImpl(cross, mockPositionPath)
}

func initRouterState(t *testing.T) {
	t.Helper()
	const mockRouterPath = "gno.land/r/gnoswap/router/mock"

	if !initializedRouter {
		initializedRouter = true

		testing.SetRealm(testing.NewCodeRealm(mockRouterPath))
		router.RegisterInitializer(cross, func(_ router.IRouterStore) router.IRouter {
			return router_v1.NewRouterV1(newMockRouterStore())
		})
	}

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	router.UpgradeImpl(cross, mockRouterPath)
}

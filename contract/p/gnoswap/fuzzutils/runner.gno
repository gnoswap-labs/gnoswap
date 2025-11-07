package fuzzutils

import (
	"strings"
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/nt/ufmt"
)

func RunFuzzTestWithPanic(t *testing.T, iterations int, fn func(*fuzz.T, *Result, int)) {
	result := NewFuzzResult(fuzz.BASE_SEED)
	index := 0

	// Use CheckN instead of CheckWithConfig
	fuzz.CheckN(t, iterations, func(ft *fuzz.T) {
		index++

		errorMessage, isPanic := handlePanic(func() {
			fn(ft, result, index)
		})

		if isPanic {
			message := strings.TrimSpace(errorMessage)
			result.AddErrorMessage(index, message)
		}

		if result.IsValidState(index) == isPanic {
			result.AddUnexpectedResult(index)
		}
	})

	printResultLog(t, iterations, result)
}

func RunFuzzTestWithCrossPanic(t *testing.T, iterations int, fn func(*fuzz.T, *Result, int)) {
	result := NewFuzzResult(fuzz.BASE_SEED)
	index := 0

	// Use CheckN instead of CheckWithConfig
	fuzz.CheckN(t, iterations, func(ft *fuzz.T) {
		index++

		errorMessage, isCrossPanic := handleCrossPanic(func() {
			fn(ft, result, index)
		})

		if isCrossPanic {
			message := strings.TrimSpace(errorMessage)
			result.AddErrorMessage(index, message)
		}

		if result.IsValidState(index) == isCrossPanic {
			result.AddUnexpectedResult(index)
		}
	})

	printResultLog(t, iterations, result)
}

func printResultLog(t *testing.T, iterations int, result *Result) {
	result.PrintLog(t)

	if result.UnexpectedResultsCount() > 0 {
		panic(ufmt.Sprintf("Fuzz test failed with %d unexpected results", result.UnexpectedResultsCount()))
	} else {
		t.Logf("\n=== RESULT: Fuzz test passed %d iterations (success: %d, errors: %d)", iterations, result.SuccessCount(), result.ErrorMessagesCount())
	}
}

func handlePanic(fn func()) (msg string, panicked bool) {
	defer func() {
		r := recover()
		if r == nil {
			return
		}

		panicked = true

		if err, ok := r.(error); ok {
			msg = err.Error()
			return
		}

		if s, ok := r.(string); ok {
			msg = s
			return
		}

		msg = "unsupported panic type"
	}()

	fn()
	return
}

func handleCrossPanic(fn func()) (string, bool) {
	r := revive(fn)
	if r == nil {
		return "", false
	}

	if err, ok := r.(error); ok {
		return err.Error(), true
	}

	if s, ok := r.(string); ok {
		return s, true
	}

	return "unsupported panic type", true
}

package fuzzutils

import (
	"strings"
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/nt/ufmt"
)

func RunFuzzTest(t *testing.T, iterations int, fn func(*fuzz.T, *Result, int), options ...any) {
	result := NewFuzzResult(fuzz.BASE_SEED)
	isHandlePanic := true
	index := 0

	if len(options) > 0 {
		handledPanic, ok := options[0].(bool)
		if ok {
			isHandlePanic = handledPanic
		}
	}

	// Use CheckN instead of CheckWithConfig
	fuzz.CheckN(t, iterations, func(ft *fuzz.T) {
		index++

		errorMessage := ""
		isError := false

		if isHandlePanic {
			panicMessage, panicked := handlePanic(func() {
				crossPanicMessage, crossPanicked := handleCrossPanic(func() {
					fn(ft, result, index)
				})

				errorMessage = crossPanicMessage
				isError = crossPanicked
			})

			if panicked && isError != panicked {
				errorMessage = panicMessage
				isError = true
			}
		} else {
			fn(ft, result, index)
		}

		if isError {
			message := strings.TrimSpace(errorMessage)
			result.AddErrorMessage(index, message)
		}

		if result.IsValidState(index) == isError {
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

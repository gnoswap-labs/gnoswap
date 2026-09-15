package fuzzutils

import (
	"strings"

	"gno.land/p/gnoswap/fuzz"
	ufmt "gno.land/p/nt/ufmt/v0"
)

// RunFuzzTest executes a fuzz property for the requested number of iterations and records its outcomes.
//
// Parameters:
//   - t: Test logger used by the fuzz engine and final result report.
//   - iterations: Number of valid fuzz cases requested from the engine.
//   - fn: Callback invoked once per generated case with its fuzz state, result accumulator, and one-based iteration number.
//   - options: Optional settings in positional order: options[0] bool enables panic handling (default true), and options[1] bool enables per-iteration logging (default false); other values are ignored.
func RunFuzzTest(t fuzz.TestingT, iterations int, fn func(*fuzz.T, *Result, int), options ...any) {
	result := NewFuzzResult(fuzz.BASE_SEED)
	isHandlePanic := true
	isPrintLog := false
	index := 0

	if len(options) > 0 {
		handledPanic, ok := options[0].(bool)
		if ok {
			isHandlePanic = handledPanic
		}
	}

	if len(options) > 1 {
		isPrintLogOption, ok := options[1].(bool)
		if ok {
			isPrintLog = isPrintLogOption
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

		if isPrintLog {
			if isError {
				ufmt.Printf("[LOG-%d] %s (error: %s)\n", index, result.params[index].ToString(), errorMessage)
			} else {
				ufmt.Printf("[LOG-%d] %s (valid)\n", index, result.params[index].ToString())
			}
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

// printResultLog writes the accumulated fuzz report and reports whether unexpected outcomes occurred.
//
// Parameters:
//   - t: Test logger receiving the aggregate and per-iteration report.
//   - iterations: Number of valid iterations requested, used in the success summary.
//   - result: Accumulator containing parameters, errors, and unexpected-result markers.
func printResultLog(t fuzz.TestingT, iterations int, result *Result) {
	result.PrintLog(t)

	if result.UnexpectedResultsCount() > 0 {
		panic(ufmt.Sprintf("Fuzz test failed with %d unexpected results", result.UnexpectedResultsCount()))
	} else {
		t.Logf("\n=== RESULT: Fuzz test passed %d iterations (success: %d, errors: %d)", iterations, result.SuccessCount(), result.ErrorMessagesCount())
	}
}

// handlePanic invokes fn and converts a recovered panic into a message and status.
//
// Parameters:
//   - fn: Callback whose panic, if any, should be recovered.
//
// Returns:
//   - msg: Panic text when the recovered value is an error or string, "unsupported panic type" for other values, or empty when fn returns normally.
//   - panicked: True when fn panicked and recovery handled it; false when fn returned normally.
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

// handleCrossPanic invokes fn through Gno's cross-call panic recovery mechanism.
//
// Parameters:
//   - fn: Callback whose cross-call panic, if any, should be recovered.
//
// Returns:
//   - msg: Panic text when the recovered value is an error or string, "unsupported panic type" for other values, or empty when fn returns normally.
//   - panicked: True when revive reports a panic value; false when fn returns normally.
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

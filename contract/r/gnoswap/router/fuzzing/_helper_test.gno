package fuzzing

import (
	"strings"
	"testing"

	"gno.land/p/gnoswap/fuzzing"
	"gno.land/p/nt/ufmt"

	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/router/v1"

	_ "gno.land/r/onbloc/bar"
	_ "gno.land/r/onbloc/foo"
)

type Params interface {
	IsValid() bool
	ToString() string
}

type Result struct {
	seed              uint64
	params            map[int]Params
	paramsValidStates map[int]bool
	errorMessages     map[int]string
	unexpectedResults map[int]bool
}

func (r *Result) SuccessCount() int {
	return r.TotalCount() - r.UnexpectedResultsCount()
}

func (r *Result) UnexpectedResultsCount() int {
	return len(r.unexpectedResults)
}

func (r *Result) TotalCount() int {
	return len(r.params)
}

func (r *Result) ErrorMessagesCount() int {
	return len(r.errorMessages)
}

func (r *Result) ErrorMessages() map[int]string {
	return r.errorMessages
}

func (r *Result) IsValidState(iteration int) bool {
	return r.paramsValidStates[iteration]
}

func (r *Result) AddParams(iteration int, params Params) {
	r.params[iteration] = params
	r.paramsValidStates[iteration] = params.IsValid()
}

func (r *Result) AddErrorMessage(iteration int, message string) {
	r.errorMessages[iteration] = message
}

func (r *Result) AddUnexpectedResult(iteration int) {
	r.unexpectedResults[iteration] = true
}

func (r *Result) PrintLog(t *testing.T) {
	t.Logf("Total Count: %d", r.TotalCount())
	t.Logf("Success: %d", r.SuccessCount())
	t.Logf("Unexpected Results: %d", r.UnexpectedResultsCount())

	if r.UnexpectedResultsCount() > 0 {
		t.Logf("\nUnexpected Result Logs:")
		for i, _ := range r.unexpectedResults {
			if r.paramsValidStates[i] {
				t.Logf("Iteration %d: %s\n - params: %s", i, r.errorMessages[i], r.params[i].ToString())
			} else {
				t.Logf("Iteration %d: %s\n - params: %s", i, "should be failed but passed", r.params[i].ToString())
			}
		}
	} else {
		t.Logf("No unexpected results")
	}
}

func NewFuzzingResult(seed uint64) *Result {
	return &Result{
		seed:              seed,
		params:            make(map[int]Params),
		paramsValidStates: make(map[int]bool),
		errorMessages:     make(map[int]string),
		unexpectedResults: make(map[int]bool),
	}
}

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
		panic("unexpected fuzzing test results")
	} else {
		t.Logf("Fuzzing test successfully passed %d iterations", iterations)
	}
}

// Copyright 2019 Gregory Petrosyan <gregory.petrosyan@gmail.com>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package fuzz

import (
	ufmt "gno.land/p/nt/ufmt/v0"
)

const (
	small             = 5
	defaultChecks     = 1
	invalidChecksMult = 10
)

// TestingT abstracts the subset of *testing.T used by the fuzz engine so the
// package can be type-checked and deployed without importing the test-only
// "testing" stdlib. *testing.T satisfies it structurally, so callers pass
// their *testing.T unchanged.
type TestingT interface {
	// Errorf records a formatted test error and marks the test as failed.
	//
	// Parameters:
	//   - format: Format string used to render the diagnostic message.
	//   - args: Values substituted into format.
	Errorf(format string, args ...any)
	// Fatalf records a formatted test error and stops the current test immediately.
	//
	// Parameters:
	//   - format: Format string used to render the diagnostic message.
	//   - args: Values substituted into format.
	Fatalf(format string, args ...any)
	// Logf formats a diagnostic message for the test log.
	//
	// Parameters:
	//   - format: Format string used to render the diagnostic message.
	//   - args: Values substituted into format.
	Logf(format string, args ...any)
}

// assert panics with an assertion failure when ok is false.
//
// Parameters:
//   - ok: Condition that must be true for execution to continue.
func assert(ok bool) {
	if !ok {
		panic("assertion failed")
	}
}

// assertf panics with a formatted assertion failure when ok is false.
//
// Parameters:
//   - ok: Condition that must be true for execution to continue.
//   - format: Format string for the assertion failure message.
//   - args: Values substituted into format when the assertion fails.
func assertf(ok bool, format string, args ...any) {
	if !ok {
		panic(ufmt.Sprintf(format, args...))
	}
}

type (
	invalidData string
	stopTest    string
)

// T is similar to testing.T, but with extra bookkeeping for property-based tests.
type T struct {
	s        bitStream
	draws    int
	refDraws []any
	failed   stopTest
}

// newT creates a property-test state around the supplied bit stream.
//
// Parameters:
//   - s: Bit stream used to generate values for this test state.
//   - refDraws: Optional reference values retained for draw bookkeeping; the current Gno implementation does not compare them.
//
// Returns:
//   - *T: A test state initialized with s, refDraws, and no draws or failure.
func newT(s bitStream, refDraws ...any) *T {
	return &T{
		s:        s,
		draws:    0,
		refDraws: refDraws,
		failed:   "",
	}
}

// Logf logs a formatted message.
//
// Parameters:
//   - format: Format string for the message.
//   - args: Values substituted into format.
func (t *T) Logf(format string, args ...any) {
	// In Gno, we can't use log.Logger, so we just format the message
	_ = ufmt.Sprintf(format, args...)
}

// Log logs a message.
//
// Parameters:
//   - args: Values rendered as one log message.
func (t *T) Log(args ...any) {
	// In Gno, we can't use log.Logger
	_ = ufmt.Sprint(args...)
}

// Skipf is equivalent to Logf followed by SkipNow.
//
// Parameters:
//   - format: Format string for the skip message.
//   - args: Values substituted into format before the test is marked invalid.
func (t *T) Skipf(format string, args ...any) {
	t.Logf(format, args...)
	t.skip(ufmt.Sprintf(format, args...))
}

// Skip is equivalent to Log followed by SkipNow.
//
// Parameters:
//   - args: Values rendered as the skip message before the test is marked invalid.
func (t *T) Skip(args ...any) {
	t.Log(args...)
	t.skip(ufmt.Sprint(args...))
}

// SkipNow marks the current test case as invalid.
// If too many test cases are skipped, the test will fail due to
// inability to generate enough valid test cases.
//
// The test case or action will be treated like it had never been drawn
// and will not be shown in test logs.
// Therefore, to avoid confusing test failures later on,
// SkipNow must not be called after the action has already mutated shared state.
//
// Prefer Generator.Filter to SkipNow, and prefer generators that always produce
// valid test cases to Filter.
func (t *T) SkipNow() {
	t.skip("(*T).SkipNow() called")
}

// Errorf is equivalent to Logf followed by Fail.
//
// Parameters:
//   - format: Format string for the error message.
//   - args: Values substituted into format.
func (t *T) Errorf(format string, args ...any) {
	t.Logf(format, args...)
	t.fail(false, ufmt.Sprintf(format, args...))
}

// Error is equivalent to Log followed by Fail.
//
// Parameters:
//   - args: Values rendered as the error message.
func (t *T) Error(args ...any) {
	t.Log(args...)
	t.fail(false, ufmt.Sprint(args...))
}

// Fatalf is equivalent to Logf followed by FailNow.
//
// Parameters:
//   - format: Format string for the fatal message.
//   - args: Values substituted into format before execution stops.
func (t *T) Fatalf(format string, args ...any) {
	t.Logf(format, args...)
	t.fail(true, ufmt.Sprintf(format, args...))
}

// Fatal is equivalent to Log followed by FailNow.
//
// Parameters:
//   - args: Values rendered as the fatal message before execution stops.
func (t *T) Fatal(args ...any) {
	t.Log(args...)
	t.fail(true, ufmt.Sprint(args...))
}

// FailNow marks the test as failed and stops execution immediately.
func (t *T) FailNow() {
	t.fail(true, "(*T).FailNow() called")
}

// Fail marks the test as failed but continues execution.
func (t *T) Fail() {
	t.fail(false, "(*T).Fail() called")
}

// Failed returns whether the test has failed.
//
// Returns:
//   - bool: True when a failure has been recorded on t; false when the test state is still successful.
func (t *T) Failed() bool {
	return t.failed != ""
}

// skip marks the current test case as invalid by panicking with invalidData.
//
// Parameters:
//   - msg: Explanation attached to the invalid-data panic.
func (t *T) skip(msg string) {
	panic(invalidData(msg))
}

// fail records msg as a test failure and optionally stops execution.
//
// Parameters:
//   - now: Whether to panic immediately after recording the failure; false leaves execution running.
//   - msg: Failure message recorded on the test state and, when now is true, propagated by the panic.
func (t *T) fail(now bool, msg string) {
	t.failed = stopTest(msg)
	if now {
		panic(t.failed)
	}
}

// failOnError panics with the recorded failure when t has been marked failed.
func (t *T) failOnError() {
	if t.failed != "" {
		panic(t.failed)
	}
}

// Check runs one property-based test case by default. It fails the test if it
// finds a test case that falsifies the property; use CheckN to request more
// valid cases.
//
// The property function receives a *T which provides generator methods via
// Draw() and can be used to mark the test as failed.
//
// Example:
//
//	func TestProperty(t *testing.T) {
//	    fuzz.Check(t, func(ft *fuzz.T) {
//	        x := fuzz.Int64Range(0, 100).Draw(ft, "x").(int64)
//	        y := fuzz.Int64Range(0, 100).Draw(ft, "y").(int64)
//
//	        // Property: x + y should equal y + x (commutative)
//	        if x + y != y + x {
//	            ft.Fatalf("commutativity failed: %d + %d != %d + %d", x, y, y, x)
//	        }
//	    })
//	}
//
// Parameters:
//   - t: Test sink receiving failure and progress messages.
//   - prop: Property callback invoked with a newly seeded *T for each generated test case.
func Check(t TestingT, prop func(*T)) {
	CheckN(t, defaultChecks, prop)
}

// CheckN runs property-based tests with a specific number of checks.
// It's like Check but allows you to specify how many random test cases to generate.
//
// Parameters:
//   - t: Test sink receiving failure and progress messages.
//   - checks: Number of valid property cases requested; invalid cases are retried up to the configured limit.
//   - prop: Property callback invoked for each generated test state.
func CheckN(t TestingT, checks int, prop func(*T)) {
	seed := baseSeed()

	valid := 0
	invalid := 0

	for valid < checks && invalid < checks*invalidChecksMult {
		iter := valid + invalid
		testSeed := seed + uint64(iter)

		s := newRandomBitStream(testSeed, false)
		ft := newT(s)

		err := checkOnce(ft, prop)

		if err == nil {
			valid++
		} else if isInvalidData(err) {
			invalid++
		} else {
			// Test failed
			t.Fatalf("[fuzz] failed after %d valid tests (seed %d): %v", valid, testSeed, err)
			return
		}
	}

	if valid == checks {
		t.Logf("[fuzz] OK, passed %d tests", valid)
	} else {
		t.Errorf("[fuzz] only generated %d valid tests from %d total", valid, valid+invalid)
	}
}

// checkOnce runs the property function once and catches panics
//
// Parameters:
//   - ft: Test state supplied to the property callback.
//   - prop: Property callback to execute once.
//
// Returns:
//   - err: nil when the callback completes without a recorded failure; otherwise the recovered panic value, including invalidData or a failure panic.
func checkOnce(ft *T, prop func(*T)) (err any) {
	defer func() {
		if r := recover(); r != nil {
			err = r
		}
	}()

	prop(ft)
	ft.failOnError()

	return nil
}

// isInvalidData checks if the error is an invalidData type
//
// Parameters:
//   - err: Value returned from a recovered property panic, or nil when no panic occurred.
//
// Returns:
//   - bool: True only when err has the package's invalidData type, indicating an intentionally invalid generated case; false for nil and all other values.
func isInvalidData(err any) bool {
	_, ok := err.(invalidData)
	return ok
}

package store

import (
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

// castToInt64 safely casts an any value to int64.
//
// Parameters:
//   - result: Value to type-assert as int64.
//
// Returns:
//   - int64: Asserted value when result has dynamic type int64, or 0 on a failed assertion.
//   - error: nil on a successful assertion; otherwise ErrFailedCast describing the actual dynamic type.
func castToInt64(result any) (int64, error) {
	v, ok := result.(int64)
	if !ok {
		return 0, ufmt.Errorf("%s: %s", ErrFailedCast, ufmt.Sprintf("cast %T to int64", result))
	}

	return v, nil
}

// castToUint64 safely casts an any value to uint64.
//
// Parameters:
//   - result: Value to type-assert as uint64.
//
// Returns:
//   - uint64: Asserted value when result has dynamic type uint64, or 0 on a failed assertion.
//   - error: nil on a successful assertion; otherwise ErrFailedCast describing the actual dynamic type.
func castToUint64(result any) (uint64, error) {
	v, ok := result.(uint64)
	if !ok {
		return 0, ufmt.Errorf("%s: %s", ErrFailedCast, ufmt.Sprintf("cast %T to uint64", result))
	}

	return v, nil
}

// castToBool safely casts an any value to bool.
//
// Parameters:
//   - result: Value to type-assert as bool.
//
// Returns:
//   - bool: Asserted value when result has dynamic type bool, or false on a failed assertion.
//   - error: nil on a successful assertion; otherwise ErrFailedCast describing the actual dynamic type.
func castToBool(result any) (bool, error) {
	v, ok := result.(bool)
	if !ok {
		return false, ufmt.Errorf("%s: %s", ErrFailedCast, ufmt.Sprintf("cast %T to bool", result))
	}

	return v, nil
}

// castToString safely casts an any value to string.
//
// Parameters:
//   - result: Value to type-assert as string.
//
// Returns:
//   - string: Asserted value when result has dynamic type string, or the empty string on a failed assertion.
//   - error: nil on a successful assertion; otherwise ErrFailedCast describing the actual dynamic type.
func castToString(result any) (string, error) {
	v, ok := result.(string)
	if !ok {
		return "", ufmt.Errorf("%s: %s", ErrFailedCast, ufmt.Sprintf("cast %T to string", result))
	}

	return v, nil
}

// castToBPTree safely casts an any value to *bptree.BPTree.
//
// Parameters:
//   - result: Value to type-assert as a *bptree.BPTree.
//
// Returns:
//   - *bptree.BPTree: Asserted tree pointer when result has that dynamic type, or nil on a failed assertion.
//   - error: nil on a successful assertion; otherwise ErrFailedCast describing the actual dynamic type.
func castToBPTree(result any) (*bptree.BPTree, error) {
	tree, ok := result.(*bptree.BPTree)
	if !ok {
		return nil, ufmt.Errorf("%s: %s", ErrFailedCast, ufmt.Sprintf("cast %T to *bptree.BPTree", result))
	}

	return tree, nil
}

// castToAddress safely casts an any value to address.
//
// Parameters:
//   - result: Value to type-assert as address.
//
// Returns:
//   - address: Asserted address when result has dynamic type address, or the empty address on a failed assertion.
//   - error: nil on a successful assertion; otherwise ErrFailedCast describing the actual dynamic type.
func castToAddress(result any) (address, error) {
	v, ok := result.(address)
	if !ok {
		return address(""), ufmt.Errorf("%s: %s", ErrFailedCast, ufmt.Sprintf("cast %T to address", result))
	}

	return v, nil
}

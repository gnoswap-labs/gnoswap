package store

import (
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
)

// castToInt64 safely casts an any value to int64
// Returns ErrFailedCast if the value is not of type int64
func castToInt64(result any) (int64, error) {
	v, ok := result.(int64)
	if !ok {
		return 0, ufmt.Errorf("%s: %s", ErrFailedCast.Error(), ufmt.Sprintf("cast %T to int64", result))
	}

	return v, nil
}

// castToUint64 safely casts an any value to uint64
// Returns ErrFailedCast if the value is not of type uint64
func castToUint64(result any) (uint64, error) {
	v, ok := result.(uint64)
	if !ok {
		return 0, ufmt.Errorf("%s: %s", ErrFailedCast.Error(), ufmt.Sprintf("cast %T to uint64", result))
	}

	return v, nil
}

// castToBool safely casts an any value to bool
// Returns ErrFailedCast if the value is not of type bool
func castToBool(result any) (bool, error) {
	v, ok := result.(bool)
	if !ok {
		return false, ufmt.Errorf("%s: %s", ErrFailedCast.Error(), ufmt.Sprintf("cast %T to bool", result))
	}

	return v, nil
}

// castToString safely casts an any value to string
// Returns ErrFailedCast if the value is not of type string
func castToString(result any) (string, error) {
	v, ok := result.(string)
	if !ok {
		return "", ufmt.Errorf("%s: %s", ErrFailedCast.Error(), ufmt.Sprintf("cast %T to string", result))
	}

	return v, nil
}

// castToTree safely casts an any value to *bptree.BPTree
// Returns ErrFailedCast if the value is not of type *bptree.BPTree
func castToTree(result any) (*bptree.BPTree, error) {
	tree, ok := result.(*bptree.BPTree)
	if !ok {
		return nil, ufmt.Errorf("%s: %s", ErrFailedCast.Error(), ufmt.Sprintf("cast %T to *bptree.BPTree", result))
	}

	return tree, nil
}

// castToAddress safely casts an any value to address
// Returns ErrFailedCast if the value is not of type address
func castToAddress(result any) (address, error) {
	v, ok := result.(address)
	if !ok {
		return address(""), ufmt.Errorf("%s: %s", ErrFailedCast.Error(), ufmt.Sprintf("cast %T to address", result))
	}

	return v, nil
}

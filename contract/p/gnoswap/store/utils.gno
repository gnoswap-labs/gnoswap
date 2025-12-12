package store

import (
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
)

// CastToInt64 safely casts an any value to int64
// Returns ErrFailedCast if the value is not of type int64
func CastToInt64(result any) (int64, error) {
	v, ok := result.(int64)
	if !ok {
		return 0, ufmt.Errorf("%s: %s", ErrFailedCast.Error(), ufmt.Sprintf("cast %T to int64", result))
	}

	return v, nil
}

// CastToUint64 safely casts an any value to uint64
// Returns ErrFailedCast if the value is not of type uint64
func CastToUint64(result any) (uint64, error) {
	v, ok := result.(uint64)
	if !ok {
		return 0, ufmt.Errorf("%s: %s", ErrFailedCast.Error(), ufmt.Sprintf("cast %T to uint64", result))
	}

	return v, nil
}

// CastToBool safely casts an any value to bool
// Returns ErrFailedCast if the value is not of type bool
func CastToBool(result any) (bool, error) {
	v, ok := result.(bool)
	if !ok {
		return false, ufmt.Errorf("%s: %s", ErrFailedCast.Error(), ufmt.Sprintf("cast %T to bool", result))
	}

	return v, nil
}

// CastToString safely casts an any value to string
// Returns ErrFailedCast if the value is not of type string
func CastToString(result any) (string, error) {
	v, ok := result.(string)
	if !ok {
		return "", ufmt.Errorf("%s: %s", ErrFailedCast.Error(), ufmt.Sprintf("cast %T to string", result))
	}

	return v, nil
}

// CastToTree safely casts an any value to *avl.Tree
// Returns ErrFailedCast if the value is not of type *avl.Tree
func CastToTree(result any) (*avl.Tree, error) {
	tree, ok := result.(*avl.Tree)
	if !ok {
		return nil, ufmt.Errorf("%s: %s", ErrFailedCast.Error(), ufmt.Sprintf("cast %T to *avl.Tree", result))
	}

	return tree, nil
}

// CastToAddress safely casts an any value to address
// Returns ErrFailedCast if the value is not of type address
func CastToAddress(result any) (address, error) {
	v, ok := result.(address)
	if !ok {
		return address(""), ufmt.Errorf("%s: %s", ErrFailedCast.Error(), ufmt.Sprintf("cast %T to address", result))
	}

	return v, nil
}

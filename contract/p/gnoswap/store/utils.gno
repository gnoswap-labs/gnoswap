package store

import (
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"
)

func CastToInt64(result any) (int64, error) {
	v, ok := result.(int64)
	if !ok {
		return 0, ufmt.Errorf("%s: %s", ErrFailedCast.Error(), ufmt.Sprintf("cast int64 to %T", result))
	}

	return v, nil
}

func CastToUint64(result any) (uint64, error) {
	v, ok := result.(uint64)
	if !ok {
		return 0, ufmt.Errorf("%s: %s", ErrFailedCast.Error(), ufmt.Sprintf("cast uint64 to %T", result))
	}

	return v, nil
}

func CastToBool(result any) (bool, error) {
	v, ok := result.(bool)
	if !ok {
		return false, ufmt.Errorf("%s: %s", ErrFailedCast.Error(), ufmt.Sprintf("cast bool to %T", result))
	}

	return v, nil
}

func CastToString(result any) (string, error) {
	v, ok := result.(string)
	if !ok {
		return "", ufmt.Errorf("%s: %s", ErrFailedCast.Error(), ufmt.Sprintf("cast string to %T", result))
	}

	return v, nil
}

func CastToTree(result any) (*avl.Tree, error) {
	tree, ok := result.(*avl.Tree)
	if !ok {
		return nil, ufmt.Errorf("%s: %s", ErrFailedCast.Error(), ufmt.Sprintf("cast *avl.Tree to %T", result))
	}

	return tree, nil
}

func CastToAddress(result any) (address, error) {
	v, ok := result.(address)
	if !ok {
		return address(""), ufmt.Errorf("%s: %s", ErrFailedCast.Error(), ufmt.Sprintf("cast address to %T", result))
	}

	return v, nil
}

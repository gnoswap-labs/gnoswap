package common

import (
	"strings"

	"gno.land/p/demo/ufmt"
)

func Split(input string, sep string, length int) ([]string, error) {
	result := strings.Split(input, sep)
	if len(result) != length {
		return nil, ufmt.Errorf("invalid length: %d", len(result))
	}

	return result, nil
}

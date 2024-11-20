package common

import (
	"strings"

	"gno.land/p/demo/ufmt"
)

func Split(tierId string, sep string, length int) ([]string, error) {
	result := strings.Split(tierId, sep)
	if len(result) != length {
		return nil, ufmt.Errorf("invalid length: %d", len(result))
	}

	return result, nil
}

package access

import (
	"std"

	"gno.land/p/demo/ufmt"
)

func GetAddressForRole(role string) (std.Address, error) {
	var result std.Address
	addressRegistry.Iterate("", "", func(key string, value interface{}) bool {
		if value == role {
			result = std.Address(key)
			return false
		}
		return true
	})

	if result == "" {
		return result, ufmt.Errorf("no address found for role: %s", role)
	}

	return result, nil
}

func GetAddressForPath(path string) (std.Address, error) {
	addr, exists := pathRegistry.Get(path)
	if !exists {
		return std.Address(""), ufmt.Errorf("no address registered for path: %s", path)
	}
	return std.Address(addr.(string)), nil
}

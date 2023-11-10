package tc

import (
	"std"
	"time"
)

func GetHeight() int64 {
	return std.GetHeight()
}

func GetTimestamp() int64 {
	return time.Now().Unix()
}

func GetChainID() string {
	return std.GetChainID()
}

func GetOrigCaller() std.Address {
	return std.GetOrigCaller()
}

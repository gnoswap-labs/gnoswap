package gnoswap

import (
	"encoding/base64"
	"sort"
	"std"
	"strings"
	"testing"

	"gno.land/p/demo/grc/grc20"
	"gno.land/r/demo/users"
)

func TestGetPoolInfo(t *testing.T) {
	pi := GetPoolInfo()
	println(pi)
}


func TestGetTokenInfo(t *testing.T) {
	ti0 := GetTokenInfo(token0)
	// println(ti0)
	shouldEQ(t, ti0.Name, "Foo")

	ti1 := GetTokenInfo(token1)
	// println(ti1)
	shouldEQ(t, ti1.Name, "Bar")
}


func TestGetUserInfo(t *testing.T) {
	ui := GetUserInfo("g1d3crqv2lta047h6lta047h6lta047h6lnjw069")
	println(ui)
}
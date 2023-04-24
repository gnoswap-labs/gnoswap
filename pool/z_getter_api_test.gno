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
	tapi := ApiGetPoolInfo()
	println(tapi)
}

func TestGetTokenInfo(t *testing.T) {
	tati0 := ApiGetTokenInfo(token0)
	println(tati0)
	println()

	tati1 := ApiGetTokenInfo(token1)
	println(tati1)
}

func TestGetUserInfo(t *testing.T) {
	taui := ApiGetUserInfo("g1d3crqv2lta047h6lta047h6lta047h6lnjw069")
	println(taui)
}
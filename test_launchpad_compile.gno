package main

import (
	"fmt"
	"gno.land/r/gnoswap/v1/launchpad"
)

func main() {
	fmt.Println("Testing launchpad compilation")
	// Just import to test compilation
	_ = launchpad.NewRewardManager
}
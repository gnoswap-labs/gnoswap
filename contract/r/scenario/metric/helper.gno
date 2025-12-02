package metric

import (
	"testing"

	"gno.land/p/nt/ufmt"
)

func PrintMetricsBy(name string, fn func()) {
	beforeCycles := testing.GetCycles()
	beforeGas := testing.GetGas()
	beforeRealmStorageDiff := testing.GetRealmStorageDiffs()

	fn()

	afterCycles := testing.GetCycles()
	afterGas := testing.GetGas()
	afterRealmStorageDiff := testing.GetRealmStorageDiffs()

	totalRealmStorageDiff := int64(0)

	for _, diff := range afterRealmStorageDiff {
		totalRealmStorageDiff += diff
	}

	for _, diff := range beforeRealmStorageDiff {
		totalRealmStorageDiff -= diff
	}

	println(name)
	ufmt.Printf("- Gas Used: %d\n", afterGas-beforeGas)
	ufmt.Printf("- Storage Diff: %d\n", totalRealmStorageDiff)
	ufmt.Printf("- CPU Cycles: %d\n", afterCycles-beforeCycles)
}

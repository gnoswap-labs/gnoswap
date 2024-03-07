package uint256

import (
	"testing"
)

func TestFuncs(t *testing.T) {
	x := UnsafeFromDecimal("79188548433007205424747178")
	y := UnsafeFromDecimal("130406999485845074795897568971")

	z := new(Uint).Add(x, y)
	println("z:", z.ToString()) // 130486188034278082001322316149

	if z.ToString() != "130486188034278082001322316149" {
		t.Error("Expected 130486188034278082001322316149, got ", z.ToString())
	}
}

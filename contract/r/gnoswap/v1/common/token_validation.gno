package common

const (
	// WUGNOT_PATH is the path to the wrapped UGNOT token
	WUGNOT_PATH = "gno.land/r/gnoland/wugnot"
)

// IsWUGNOT checks if the given token path is WUGNOT
func IsWUGNOT(tokenPath string) bool {
	return tokenPath == WUGNOT_PATH
}

// AssertIsWUGNOT panics if the given token path is not WUGNOT
func AssertIsWUGNOT(tokenPath string) {
	if !IsWUGNOT(tokenPath) {
		panic("token is not WUGNOT: " + tokenPath)
	}
}

package v1

const (
	WUGNOT_PATH = "gno.land/r/gnoland/wugnot"
	GNOT_DENOM  = "ugnot"
)

// isNative checks whether the given token is a native token.
func isNative(token string) bool {
	return token == GNOT_DENOM
}

// isWrappedToken checks whether the tokenPath is wrapped token.
func isWrappedToken(tokenPath string) bool {
	return tokenPath == WUGNOT_PATH
}

package uint256

// checkNumberS validates that input represents a valid hexadecimal number.
// Requires "0x" or "0X" prefix and disallows leading zeros after the prefix.
func checkNumberS(input string) error {
	const fn = "UnmarshalText"
	l := len(input)
	if l == 0 {
		return errEmptyString(fn, input)
	}
	if l < 2 || input[0] != '0' ||
		(input[1] != 'x' && input[1] != 'X') {
		return errMissingPrefix(fn, input)
	}
	if l == 2 {
		return errEmptyNumber(fn, input)
	}
	if len(input) > 3 && input[2] == '0' {
		return errLeadingZero(fn, input)
	}
	return nil
}

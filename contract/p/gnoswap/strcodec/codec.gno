package strcodec

import (
	"errors"
	"strconv"
	"strings"
)

const stringLengthWidth = 6
const uint32Width = 10

var (
	ErrInvalidLengthPrefix = errors.New("invalid length prefix")
	ErrUnexpectedEOF      = errors.New("unexpected eof")
	ErrInvalidUint32      = errors.New("invalid uint32")
	ErrValueTooLong       = errors.New("value exceeds fixed width")
)

func EncodeString(value string) string {
	return mustLeftPadDecimal(len(value), stringLengthWidth) + value
}

func DecodeString(encoded string, offset int) (string, int, error) {
	if offset < 0 || len(encoded) < offset+stringLengthWidth {
		return "", offset, ErrUnexpectedEOF
	}

	lengthPrefix := encoded[offset : offset+stringLengthWidth]
	if !isDecimalString(lengthPrefix) {
		return "", offset, ErrInvalidLengthPrefix
	}

	length, err := strconv.Atoi(lengthPrefix)
	if err != nil {
		return "", offset, ErrInvalidLengthPrefix
	}

	start := offset + stringLengthWidth
	end := start + length
	if len(encoded) < end {
		return "", offset, ErrUnexpectedEOF
	}

	return encoded[start:end], end, nil
}

func EncodeUint32(value uint32) string {
	return mustLeftPadDecimal(int(value), uint32Width)
}

func DecodeUint32(encoded string, offset int) (uint32, int, error) {
	if offset < 0 || len(encoded) < offset+uint32Width {
		return 0, offset, ErrUnexpectedEOF
	}

	segment := encoded[offset : offset+uint32Width]
	if !isDecimalString(segment) {
		return 0, offset, ErrInvalidUint32
	}

	parsed, err := strconv.ParseUint(segment, 10, 32)
	if err != nil {
		return 0, offset, ErrInvalidUint32
	}

	return uint32(parsed), offset + uint32Width, nil
}

func mustLeftPadDecimal(value, width int) string {
	formatted := strconv.Itoa(value)
	if len(formatted) > width {
		panic(ErrValueTooLong)
	}
	if len(formatted) == width {
		return formatted
	}

	return strings.Repeat("0", width-len(formatted)) + formatted
}

func isDecimalString(value string) bool {
	if value == "" {
		return false
	}

	for i := range value {
		if value[i] < '0' || value[i] > '9' {
			return false
		}
	}

	return true
}

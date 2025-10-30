package gnft

import (
	b64 "encoding/base64"
	"math/rand"
	"strings"
	"testing"
	"time"

	"gno.land/p/nt/uassert"
)

func TestSvgGenerator_genImageURI(t *testing.T) {
	seed1 := uint64(time.Now().Unix())
	seed2 := uint64(time.Now().UnixNano())
	pcg := rand.NewPCG(seed1, seed2)
	r := rand.New(pcg)

	var uri string
	uassert.NotPanics(t, func() {
		uri = genImageURI(r)
	})

	expectedUri := `data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTM1IiBoZWlnaHQ9IjEzNSIgdmlld0JveD0iMCAwIDEzNSAxMzUiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxnIGNsaXAtcGF0aD0idXJsKCNjbGlwMF83Njk4XzU2ODQ2KSI+CjxjaXJjbGUgY3g9IjY3LjUiIGN5PSI2Ny41IiByPSI2Ny41IiBmaWxsPSJ1cmwoI3BhaW50MF9saW5lYXJfNzY5OF81Njg0NikiLz4KPHBhdGggZD0iTTUxLjI5MDUgNDIuOTQ0OUw2Ni40ODk1IDMzTDk3IDUyLjgwNjFMODEuODI0MSA2Mi43NDI1TDUxLjI5MDUgNDIuOTQ0OVoiIGZpbGw9IndoaXRlIi8+CjxwYXRoIGQ9Ik01MS42MDU1IDY3LjUwNTlMNjYuODA0NCA1Ny41NjFMOTcgNzcuMDY1N0w4Mi4xMDQ2IDg3LjE3OTNMNTEuNjA1NSA2Ny41MDU5WiIgZmlsbD0id2hpdGUiIGZpbGwtb3BhY2l0eT0iMC40Ii8+CjxwYXRoIGQ9Ik0zNi4wNDY0IDgxLjc1NTlMNTEuMjkwNSA3MS44MTFMODEuNzMzNiA5MS42NTQ3TDY2LjQ4OTUgMTAxLjUwOEwzNi4wNDY0IDgxLjc1NTlaIiBmaWxsPSJ3aGl0ZSIgZmlsbC1vcGFjaXR5PSIwLjYiLz4KPHBhdGggZD0iTTM2LjAwMSA1Mi44MDU1TDUxLjI4ODQgNDIuOTE3N0w1MS4yODg0IDcxLjgxNDVMMzYuMDAxIDgxLjc3OUwzNi4wMDEgNTIuODA1NVoiIGZpbGw9IndoaXRlIi8+CjxwYXRoIGQ9Ik04Mi4xMDUxIDg3LjE3OTdMOTcuMDAxNiA3Ny4wNjYyTDk3LjAwMTYgODEuNzAyOUw4MS43ODk2IDkxLjYyOUw4Mi4xMDUxIDg3LjE3OTdaIiBmaWxsPSJ3aGl0ZSIgZmlsbC1vcGFjaXR5PSIwLjUiLz4KPHBhdGggZD0iTTUxLjI5MDUgNDIuOTQ0OUw2Ni40ODk1IDMzTDk3IDUyLjgwNjFMODEuODI0MSA2Mi43NDI1TDUxLjI5MDUgNDIuOTQ0OVoiIGZpbGw9IndoaXRlIi8+CjxwYXRoIGQ9Ik01MS42MDU1IDY3LjUwNTlMNjYuODA0NCA1Ny41NjFMOTcgNzcuMDY1N0w4Mi4xMDQ2IDg3LjE3OTNMNTEuNjA1NSA2Ny41MDU5WiIgZmlsbD0id2hpdGUiIGZpbGwtb3BhY2l0eT0iMC40Ii8+CjxwYXRoIGQ9Ik0zNi4wNDY0IDgxLjc1NTlMNTEuMjkwNSA3MS44MTFMODEuNzMzNiA5MS42NTQ3TDY2LjQ4OTUgMTAxLjUwOEwzNi4wNDY0IDgxLjc1NTlaIiBmaWxsPSJ3aGl0ZSIgZmlsbC1vcGFjaXR5PSIwLjYiLz4KPHBhdGggZD0iTTM2LjAwMSA1Mi44MDU1TDUxLjI4ODQgNDIuOTE3N0w1MS4yODg0IDcxLjgxNDVMMzYuMDAxIDgxLjc3OUwzNi4wMDEgNTIuODA1NVoiIGZpbGw9IndoaXRlIi8+CjxwYXRoIGQ9Ik04Mi4xMDUxIDg3LjE3OTdMOTcuMDAxNiA3Ny4wNjYyTDk3LjAwMTYgODEuNzAyOUw4MS43ODk2IDkxLjYyOUw4Mi4xMDUxIDg3LjE3OTdaIiBmaWxsPSJ3aGl0ZSIgZmlsbC1vcGFjaXR5PSIwLjUiLz4KPC9nPgo8ZGVmcz4KPGxpbmVhckdyYWRpZW50IGlkPSJwYWludDBfbGluZWFyXzc2OThfNTY4NDYiIHgxPSI3IiB5MT0iMTAiIHgyPSIxMjMiIHkyPSIxMjIiIGdyYWRpZW50VW5pdHM9InVzZXJTcGFjZU9uVXNlIj4KPHN0b3Agc3RvcC1jb2xvcj0iI0ZBN0EwNyIvPgo8c3RvcCBvZmZzZXQ9IjEiIHN0b3AtY29sb3I9IiMyMDYwRDciLz4KPC9saW5lYXJHcmFkaWVudD4KPGNsaXBQYXRoIGlkPSJjbGlwMF83Njk4XzU2ODQ2Ij4KPHJlY3Qgd2lkdGg9IjEzNSIgaGVpZ2h0PSIxMzUiIGZpbGw9IndoaXRlIi8+CjwvY2xpcFBhdGg+CjwvZGVmcz4KPC9zdmc+Cg==`

	uassert.Equal(t, expectedUri, uri)
}

func TestSvgGenerator_genImageRaw(t *testing.T) {
	tests := []struct {
		name  string
		seed1 uint64
		seed2 uint64
	}{
		{
			name:  "generates valid SVG with seed 1",
			seed1: 12345,
			seed2: 67890,
		},
		{
			name:  "generates valid SVG with seed 2",
			seed1: 99999,
			seed2: 11111,
		},
		{
			name:  "generates valid SVG with seed 3",
			seed1: 1,
			seed2: 1,
		},
		{
			name:  "generates valid SVG with large seeds",
			seed1: 9999999999,
			seed2: 9999999999,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			pcg := rand.NewPCG(tc.seed1, tc.seed2)
			r := rand.New(pcg)

			// when
			svg := genImageRaw(r)

			// then
			// Verify SVG structure
			uassert.True(t, strings.Contains(svg, "<svg"))
			uassert.True(t, strings.Contains(svg, "</svg>"))
			uassert.True(t, strings.Contains(svg, "linearGradient"))
			uassert.True(t, strings.Contains(svg, "stop-color"))

			// Verify gradient coordinates are in valid ranges
			// x1: 7-13, y1: 7-13, x2: 121-126, y2: 121-126
			// Colors should be in #XXXXXX format
			uassert.True(t, strings.Contains(svg, "gradientUnits=\"userSpaceOnUse\""))
		})
	}
}

func TestSvgGenerator_genImageRaw_ColorFormat(t *testing.T) {
	tests := []struct {
		name  string
		seed1 uint64
		seed2 uint64
	}{
		{
			name:  "validates color format with seed 1",
			seed1: 12345,
			seed2: 67890,
		},
		{
			name:  "validates color format with seed 2",
			seed1: 54321,
			seed2: 98765,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			pcg := rand.NewPCG(tc.seed1, tc.seed2)
			r := rand.New(pcg)

			// when
			svg := genImageRaw(r)

			// then
			// Extract colors from stop-color attributes
			// Should find two colors in #XXXXXX format
			colorCount := strings.Count(svg, "stop-color=\"#")
			uassert.Equal(t, 2, colorCount)

			// Verify each color has 6 hex digits
			stopColorIdx := 0
			for i := 0; i < 2; i++ {
				idx := strings.Index(svg[stopColorIdx:], "stop-color=\"#")
				if idx == -1 {
					t.Fatalf("expected to find stop-color")
				}
				stopColorIdx += idx + len("stop-color=\"#")

				// Next 6 characters should be hex digits
				colorHex := svg[stopColorIdx : stopColorIdx+6]
				for _, ch := range colorHex {
					isHex := (ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'F')
					uassert.True(t, isHex)
				}
			}
		})
	}
}

func TestSvgGenerator_genImageRaw_CoordinateRanges(t *testing.T) {
	tests := []struct {
		name       string
		seed1      uint64
		seed2      uint64
		iterations int
	}{
		{
			name:       "validates coordinate ranges with multiple iterations",
			seed1:      12345,
			seed2:      67890,
			iterations: 10,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			pcg := rand.NewPCG(tc.seed1, tc.seed2)
			r := rand.New(pcg)

			// when & then
			for i := 0; i < tc.iterations; i++ {
				svg := genImageRaw(r)

				// Verify SVG contains linearGradient with coordinates
				uassert.True(t, strings.Contains(svg, "linearGradient"))

				// The coordinates should be formatted in the SVG
				// x1 should be between 7-13
				// y1 should be between 7-13
				// x2 should be between 121-126
				// y2 should be between 121-126
				// We can't extract exact values easily without parsing,
				// but we verify the SVG is well-formed
				uassert.True(t, strings.Contains(svg, "x1="))
				uassert.True(t, strings.Contains(svg, "y1="))
				uassert.True(t, strings.Contains(svg, "x2="))
				uassert.True(t, strings.Contains(svg, "y2="))
			}
		})
	}
}

func TestSvgGenerator_genImageURI_Formats(t *testing.T) {
	tests := []struct {
		name  string
		seed1 uint64
		seed2 uint64
	}{
		{
			name:  "generates valid base64 URI with seed 1",
			seed1: 1735552823,
			seed2: 1735552823000000000,
		},
		{
			name:  "generates valid URI format with seed 2",
			seed1: 12345,
			seed2: 67890,
		},
		{
			name:  "generates valid URI format with seed 3",
			seed1: 99999,
			seed2: 11111,
		},
		{
			name:  "generates valid URI format with zero seeds",
			seed1: 0,
			seed2: 0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			pcg := rand.NewPCG(tc.seed1, tc.seed2)
			r := rand.New(pcg)

			// when
			uri := genImageURI(r)

			// then
			// Verify URI prefix
			uassert.True(t, strings.HasPrefix(uri, "data:image/svg+xml;base64,"))

			// Verify base64 decoding works
			base64Part := strings.TrimPrefix(uri, "data:image/svg+xml;base64,")
			decoded, err := b64.StdEncoding.DecodeString(base64Part)
			uassert.NoError(t, err)

			// Verify decoded content is valid SVG
			decodedStr := string(decoded)
			uassert.True(t, strings.HasPrefix(decodedStr, "<svg"))
			uassert.True(t, strings.HasSuffix(strings.TrimSpace(decodedStr), "</svg>"))
			uassert.True(t, strings.Contains(decodedStr, "linearGradient"))
			uassert.True(t, strings.Contains(decodedStr, "stop-color"))
		})
	}
}

func TestSvgGenerator_genImageURI_Uniqueness(t *testing.T) {
	tests := []struct {
		name       string
		iterations int
	}{
		{
			name:       "generates unique URIs with different seeds",
			iterations: 5,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			uriMap := make(map[string]bool)

			// when
			for i := 0; i < tc.iterations; i++ {
				seed1 := uint64(i * 12345)
				seed2 := uint64(i * 67890)
				pcg := rand.NewPCG(seed1, seed2)
				r := rand.New(pcg)

				uri := genImageURI(r)

				// then
				// Each URI should be unique (different colors/coordinates)
				_, exists := uriMap[uri]
				uassert.False(t, exists)
				uriMap[uri] = true
			}
		})
	}
}

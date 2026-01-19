package gnft

import (
	b64 "encoding/base64"
	"math/rand"
	"strings"
	"testing"
	"time"

	"gno.land/p/nt/uassert"
)

func TestSvgGenerator_genImageParamsString(t *testing.T) {
	seed1 := uint64(time.Now().Unix())
	seed2 := uint64(time.Now().UnixNano())
	pcg := rand.NewPCG(seed1, seed2)
	r := rand.New(pcg)

	var params string
	uassert.NotPanics(t, func() {
		params = genImageParamsString(r)
	})

	// Verify params format: "x1,y1,x2,y2,color1,color2"
	parts := strings.Split(params, ",")
	uassert.Equal(t, 6, len(parts))

	// Verify colors have # prefix
	uassert.True(t, strings.HasPrefix(parts[4], "#"))
	uassert.True(t, strings.HasPrefix(parts[5], "#"))
}

func TestSvgGenerator_generateImageURI(t *testing.T) {
	tests := []struct {
		name   string
		params string
	}{
		{
			name:   "valid params 1",
			params: "10,12,125,123,#AABBCC,#DDEEFF",
		},
		{
			name:   "valid params 2",
			params: "7,7,121,121,#000000,#FFFFFF",
		},
		{
			name:   "valid params 3",
			params: "13,13,126,126,#FA7A07,#2060D7",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			params, err := parseImageParams(tc.params)
			uassert.NoError(t, err)

			var uri string
			uassert.NotPanics(t, func() {
				uri = params.generateImageURI()
			})

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

func TestSvgGenerator_generateSVG(t *testing.T) {
	tests := []struct {
		name   string
		params string
	}{
		{
			name:   "generates valid SVG from params 1",
			params: "10,12,125,123,#AABBCC,#DDEEFF",
		},
		{
			name:   "generates valid SVG from params 2",
			params: "7,7,121,121,#000000,#FFFFFF",
		},
		{
			name:   "generates valid SVG from params 3",
			params: "13,13,126,126,#123456,#789ABC",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// Parse params first
			p, err := parseImageParams(tc.params)
			uassert.NoError(t, err)

			// Generate SVG
			svg := p.generateSVG()

			// Verify SVG structure
			uassert.True(t, strings.Contains(svg, "<svg"))
			uassert.True(t, strings.Contains(svg, "</svg>"))
			uassert.True(t, strings.Contains(svg, "linearGradient"))
			uassert.True(t, strings.Contains(svg, "stop-color"))
			uassert.True(t, strings.Contains(svg, "gradientUnits=\"userSpaceOnUse\""))
		})
	}
}

func TestSvgGenerator_paramsToImageRaw_ColorFormat(t *testing.T) {
	params := "10,12,125,123,#AABBCC,#DDEEFF"
	p, err := parseImageParams(params)
	uassert.NoError(t, err)
	svg := p.generateSVG()

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
}

func TestSvgGenerator_paramsToImageRaw_CoordinateRanges(t *testing.T) {
	tests := []struct {
		name   string
		params string
		x1     int
		y1     int
		x2     int
		y2     int
	}{
		{
			name:   "min coordinates",
			params: "7,7,121,121,#AABBCC,#DDEEFF",
			x1:     7,
			y1:     7,
			x2:     121,
			y2:     121,
		},
		{
			name:   "max coordinates",
			params: "13,13,126,126,#AABBCC,#DDEEFF",
			x1:     13,
			y1:     13,
			x2:     126,
			y2:     126,
		},
		{
			name:   "mid coordinates",
			params: "10,10,123,123,#AABBCC,#DDEEFF",
			x1:     10,
			y1:     10,
			x2:     123,
			y2:     123,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			p, err := parseImageParams(tc.params)
			uassert.NoError(t, err)
			svg := p.generateSVG()

			// Verify SVG contains linearGradient with coordinates
			uassert.True(t, strings.Contains(svg, "linearGradient"))

			// Extract and validate coordinate values
			x1, y1, x2, y2 := extractCoordinates(t, svg)

			uassert.Equal(t, tc.x1, x1)
			uassert.Equal(t, tc.y1, y1)
			uassert.Equal(t, tc.x2, x2)
			uassert.Equal(t, tc.y2, y2)
		})
	}
}

func TestSvgGenerator_genImageParamsString_CoordinateRanges(t *testing.T) {
	tests := []struct {
		name  string
		seed1 uint64
		seed2 uint64
	}{
		{
			name:  "validates coordinate ranges with seed 1",
			seed1: 12345,
			seed2: 67890,
		},
		{
			name:  "validates coordinate ranges with seed 2",
			seed1: 99999,
			seed2: 11111,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			pcg := rand.NewPCG(tc.seed1, tc.seed2)
			r := rand.New(pcg)

			for i := 0; i < 10; i++ {
				params := genImageParamsString(r)
				p, err := parseImageParams(params)
				uassert.NoError(t, err)
				svg := p.generateSVG()

				// Extract and validate coordinate values
				x1, y1, x2, y2 := extractCoordinates(t, svg)

				// x1 should be between 7-13
				uassert.True(t, x1 >= 7 && x1 <= 13)

				// y1 should be between 7-13
				uassert.True(t, y1 >= 7 && y1 <= 13)

				// x2 should be between 121-126
				uassert.True(t, x2 >= 121 && x2 <= 126)

				// y2 should be between 121-126
				uassert.True(t, y2 >= 121 && y2 <= 126)
			}
		})
	}
}

func TestSvgGenerator_roundTrip(t *testing.T) {
	tests := []struct {
		name  string
		seed1 uint64
		seed2 uint64
	}{
		{
			name:  "round trip with seed 1",
			seed1: 12345,
			seed2: 67890,
		},
		{
			name:  "round trip with seed 2",
			seed1: 1735552823,
			seed2: 1735552823000000000,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			pcg := rand.NewPCG(tc.seed1, tc.seed2)
			r := rand.New(pcg)

			// Generate params
			paramsStr := genImageParamsString(r)

			// Parse params
			params, err := parseImageParams(paramsStr)
			uassert.NoError(t, err)

			// Convert to URI
			uri := params.generateImageURI()

			// Verify URI is valid base64-encoded SVG
			uassert.True(t, strings.HasPrefix(uri, "data:image/svg+xml;base64,"))

			base64Part := strings.TrimPrefix(uri, "data:image/svg+xml;base64,")
			decoded, err := b64.StdEncoding.DecodeString(base64Part)
			uassert.NoError(t, err)

			decodedStr := string(decoded)
			uassert.True(t, strings.HasPrefix(decodedStr, "<svg"))
			uassert.True(t, strings.HasSuffix(strings.TrimSpace(decodedStr), "</svg>"))
		})
	}
}

func TestSvgGenerator_paramsToImageRaw_InvalidParams(t *testing.T) {
	tests := []struct {
		name   string
		params string
	}{
		{
			name:   "too few parts",
			params: "10,12,125",
		},
		{
			name:   "too many parts",
			params: "10,12,125,123,#AABBCC,#DDEEFF,extra",
		},
		{
			name:   "invalid x1",
			params: "abc,12,125,123,#AABBCC,#DDEEFF",
		},
		{
			name:   "invalid y1",
			params: "10,abc,125,123,#AABBCC,#DDEEFF",
		},
		{
			name:   "invalid x2",
			params: "10,12,abc,123,#AABBCC,#DDEEFF",
		},
		{
			name:   "invalid y2",
			params: "10,12,125,abc,#AABBCC,#DDEEFF",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			_, err := parseImageParams(tc.params)
			uassert.Error(t, err)
			uassert.Equal(t, errInvalidTokenParams.Error(), err.Error())
		})
	}
}

func TestSvgGenerator_uniqueness(t *testing.T) {
	paramsMap := make(map[string]bool)

	for i := 0; i < 5; i++ {
		seed1 := uint64(i * 12345)
		seed2 := uint64(i * 67890)
		pcg := rand.NewPCG(seed1, seed2)
		r := rand.New(pcg)

		params := genImageParamsString(r)

		// Each params should be unique (different colors/coordinates)
		_, exists := paramsMap[params]
		uassert.False(t, exists)
		paramsMap[params] = true
	}
}

// TestSvgGenerator_outputConsistency verifies that the new param-based approach
// produces identical SVG output as the old direct generation approach.
func TestSvgGenerator_outputConsistency(t *testing.T) {
	tests := []struct {
		name  string
		seed1 uint64
		seed2 uint64
	}{
		{
			name:  "consistency check with seed 1",
			seed1: 12345,
			seed2: 67890,
		},
		{
			name:  "consistency check with seed 2",
			seed1: 1735552823,
			seed2: 1735552823000000000,
		},
		{
			name:  "consistency check with seed 3",
			seed1: 99999,
			seed2: 11111,
		},
		{
			name:  "consistency check with zero seeds",
			seed1: 0,
			seed2: 0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// Generate using old method (simulated)
			pcg1 := rand.NewPCG(tc.seed1, tc.seed2)
			r1 := rand.New(pcg1)
			oldSVG := genImageRawDirect(r1)

			// Generate using new method (params -> SVG)
			pcg2 := rand.NewPCG(tc.seed1, tc.seed2)
			r2 := rand.New(pcg2)
			params := genImageParamsString(r2)
			p, err := parseImageParams(params)
			uassert.NoError(t, err)
			newSVG := p.generateSVG()

			// Both should produce identical output
			uassert.Equal(t, oldSVG, newSVG)
		})
	}
}

// genImageRawDirect simulates the old direct SVG generation for comparison.
// This is the original logic before optimization, using the same concatenation approach.
func genImageRawDirect(r *rand.Rand) string {
	x1 := x1Min + r.Uint64N(x1Max-x1Min+1)
	y1 := y1Min + r.Uint64N(y1Max-y1Min+1)
	x2 := x2Min + r.Uint64N(x2Max-x2Min+1)
	y2 := y2Min + r.Uint64N(y2Max-y2Min+1)

	var color1, color2 strings.Builder
	color1.Grow(7)
	color2.Grow(7)
	color1.WriteByte('#')
	color2.WriteByte('#')

	for i := 0; i < 6; i++ {
		color1.WriteByte(charset[r.IntN(16)])
		color2.WriteByte(charset[r.IntN(16)])
	}

	return svgTemplate[0] + itoa(int(x1)) + svgTemplate[1] + itoa(int(y1)) +
		svgTemplate[2] + itoa(int(x2)) + svgTemplate[3] + itoa(int(y2)) +
		svgTemplate[4] + color1.String() + svgTemplate[5] + color2.String() + svgTemplate[6]
}

// itoa converts int to string (simple implementation for test)
func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var buf [20]byte
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	return string(buf[i:])
}

// TestSvgGenerator_boundaryValues tests all boundary values for coordinates.
func TestSvgGenerator_boundaryValues(t *testing.T) {
	tests := []struct {
		name   string
		params string
		valid  bool
	}{
		// Valid boundary cases
		{
			name:   "x1 min boundary",
			params: "7,10,123,123,#AABBCC,#DDEEFF",
			valid:  true,
		},
		{
			name:   "x1 max boundary",
			params: "13,10,123,123,#AABBCC,#DDEEFF",
			valid:  true,
		},
		{
			name:   "y1 min boundary",
			params: "10,7,123,123,#AABBCC,#DDEEFF",
			valid:  true,
		},
		{
			name:   "y1 max boundary",
			params: "10,13,123,123,#AABBCC,#DDEEFF",
			valid:  true,
		},
		{
			name:   "x2 min boundary",
			params: "10,10,121,123,#AABBCC,#DDEEFF",
			valid:  true,
		},
		{
			name:   "x2 max boundary",
			params: "10,10,126,123,#AABBCC,#DDEEFF",
			valid:  true,
		},
		{
			name:   "y2 min boundary",
			params: "10,10,123,121,#AABBCC,#DDEEFF",
			valid:  true,
		},
		{
			name:   "y2 max boundary",
			params: "10,10,123,126,#AABBCC,#DDEEFF",
			valid:  true,
		},
		{
			name:   "all min boundaries",
			params: "7,7,121,121,#000000,#000000",
			valid:  true,
		},
		{
			name:   "all max boundaries",
			params: "13,13,126,126,#FFFFFF,#FFFFFF",
			valid:  true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.valid {
				p, err := parseImageParams(tc.params)
				uassert.NoError(t, err)
				uassert.NotPanics(t, func() {
					p.generateSVG()
				})
			}
		})
	}
}

// TestSvgGenerator_outOfRangeValues tests coordinates outside valid ranges.
func TestSvgGenerator_outOfRangeValues(t *testing.T) {
	tests := []struct {
		name   string
		params string
	}{
		// x1 out of range
		{
			name:   "x1 below min",
			params: "6,10,123,123,#AABBCC,#DDEEFF",
		},
		{
			name:   "x1 above max",
			params: "14,10,123,123,#AABBCC,#DDEEFF",
		},
		// y1 out of range
		{
			name:   "y1 below min",
			params: "10,6,123,123,#AABBCC,#DDEEFF",
		},
		{
			name:   "y1 above max",
			params: "10,14,123,123,#AABBCC,#DDEEFF",
		},
		// x2 out of range
		{
			name:   "x2 below min",
			params: "10,10,120,123,#AABBCC,#DDEEFF",
		},
		{
			name:   "x2 above max",
			params: "10,10,127,123,#AABBCC,#DDEEFF",
		},
		// y2 out of range
		{
			name:   "y2 below min",
			params: "10,10,123,120,#AABBCC,#DDEEFF",
		},
		{
			name:   "y2 above max",
			params: "10,10,123,127,#AABBCC,#DDEEFF",
		},
		// Extreme values
		{
			name:   "x1 negative",
			params: "-1,10,123,123,#AABBCC,#DDEEFF",
		},
		{
			name:   "x1 zero",
			params: "0,10,123,123,#AABBCC,#DDEEFF",
		},
		{
			name:   "x2 very large",
			params: "10,10,999,123,#AABBCC,#DDEEFF",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			_, err := parseImageParams(tc.params)
			uassert.Error(t, err)
			// Error now includes detailed coordinate info, check contains base error
			uassert.True(t, strings.Contains(err.Error(), errInvalidTokenParamsRange.Error()))
		})
	}
}

// TestSvgGenerator_outOfRangeValues_DetailedErrors verifies that error messages
// contain specific coordinate information for easier debugging.
func TestSvgGenerator_outOfRangeValues_DetailedErrors(t *testing.T) {
	tests := []struct {
		name              string
		params            string
		expectedCoordName string
		expectedValue     string
		expectedRange     string
	}{
		{
			name:              "x1 below min shows x1 in error",
			params:            "5,10,123,123,#AABBCC,#DDEEFF",
			expectedCoordName: "x1",
			expectedValue:     "5",
			expectedRange:     "[7, 13]",
		},
		{
			name:              "x1 above max shows x1 in error",
			params:            "15,10,123,123,#AABBCC,#DDEEFF",
			expectedCoordName: "x1",
			expectedValue:     "15",
			expectedRange:     "[7, 13]",
		},
		{
			name:              "y1 below min shows y1 in error",
			params:            "10,5,123,123,#AABBCC,#DDEEFF",
			expectedCoordName: "y1",
			expectedValue:     "5",
			expectedRange:     "[7, 13]",
		},
		{
			name:              "y1 above max shows y1 in error",
			params:            "10,15,123,123,#AABBCC,#DDEEFF",
			expectedCoordName: "y1",
			expectedValue:     "15",
			expectedRange:     "[7, 13]",
		},
		{
			name:              "x2 below min shows x2 in error",
			params:            "10,10,120,123,#AABBCC,#DDEEFF",
			expectedCoordName: "x2",
			expectedValue:     "120",
			expectedRange:     "[121, 126]",
		},
		{
			name:              "x2 above max shows x2 in error",
			params:            "10,10,130,123,#AABBCC,#DDEEFF",
			expectedCoordName: "x2",
			expectedValue:     "130",
			expectedRange:     "[121, 126]",
		},
		{
			name:              "y2 below min shows y2 in error",
			params:            "10,10,123,100,#AABBCC,#DDEEFF",
			expectedCoordName: "y2",
			expectedValue:     "100",
			expectedRange:     "[121, 126]",
		},
		{
			name:              "y2 above max shows y2 in error",
			params:            "10,10,123,130,#AABBCC,#DDEEFF",
			expectedCoordName: "y2",
			expectedValue:     "130",
			expectedRange:     "[121, 126]",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			_, err := parseImageParams(tc.params)
			uassert.Error(t, err)

			errMsg := err.Error()
			// Verify error message contains base error
			uassert.True(t, strings.Contains(errMsg, errInvalidTokenParamsRange.Error()))
			// Verify error message contains coordinate name
			uassert.True(t, strings.Contains(errMsg, tc.expectedCoordName+"="))
			// Verify error message contains the actual value
			uassert.True(t, strings.Contains(errMsg, tc.expectedValue))
			// Verify error message contains expected range
			uassert.True(t, strings.Contains(errMsg, tc.expectedRange))
		})
	}
}

// TestSvgGenerator_invalidColorFormat tests invalid color formats.
func TestSvgGenerator_invalidColorFormat(t *testing.T) {
	tests := []struct {
		name   string
		params string
	}{
		{
			name:   "color1 missing hash",
			params: "10,10,123,123,AABBCC,#DDEEFF",
		},
		{
			name:   "color2 missing hash",
			params: "10,10,123,123,#AABBCC,DDEEFF",
		},
		{
			name:   "color1 too short",
			params: "10,10,123,123,#AABBC,#DDEEFF",
		},
		{
			name:   "color2 too short",
			params: "10,10,123,123,#AABBCC,#DDEE",
		},
		{
			name:   "color1 too long",
			params: "10,10,123,123,#AABBCCD,#DDEEFF",
		},
		{
			name:   "color1 invalid hex char",
			params: "10,10,123,123,#AABBCG,#DDEEFF",
		},
		{
			name:   "color2 invalid hex char",
			params: "10,10,123,123,#AABBCC,#DDEEFZ",
		},
		{
			name:   "color with spaces",
			params: "10,10,123,123,#AAB BCC,#DDEEFF",
		},
		{
			name:   "empty color1",
			params: "10,10,123,123,,#DDEEFF",
		},
		{
			name:   "empty color2",
			params: "10,10,123,123,#AABBCC,",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			_, err := parseImageParams(tc.params)
			uassert.Error(t, err)
			uassert.Equal(t, errInvalidColorFormat.Error(), err.Error())
		})
	}
}

// TestSvgGenerator_isValidHexColor tests the hex color validation function.
func TestSvgGenerator_isValidHexColor(t *testing.T) {
	tests := []struct {
		name     string
		color    string
		expected bool
	}{
		// Valid colors
		{name: "valid uppercase", color: "#AABBCC", expected: true},
		{name: "valid lowercase", color: "#aabbcc", expected: true},
		{name: "valid mixed case", color: "#AaBbCc", expected: true},
		{name: "valid all zeros", color: "#000000", expected: true},
		{name: "valid all F", color: "#FFFFFF", expected: true},
		{name: "valid numbers only", color: "#123456", expected: true},
		// Invalid colors
		{name: "missing hash", color: "AABBCC", expected: false},
		{name: "too short", color: "#AABBC", expected: false},
		{name: "too long", color: "#AABBCCD", expected: false},
		{name: "empty", color: "", expected: false},
		{name: "only hash", color: "#", expected: false},
		{name: "invalid char G", color: "#AABBCG", expected: false},
		{name: "invalid char Z", color: "#ZZZZZZ", expected: false},
		{name: "with space", color: "#AAB BCC", expected: false},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			result := isValidHexColor(tc.color)
			uassert.Equal(t, tc.expected, result)
		})
	}
}

// TestSvgGenerator_genImageParamsString_alwaysProducesValidOutput tests that genImageParamsString
// always produces output that passes validation in paramsToImageRaw.
func TestSvgGenerator_genImageParamsString_alwaysProducesValidOutput(t *testing.T) {
	// Test with many different seeds to ensure robustness
	for i := 0; i < 100; i++ {
		seed1 := uint64(i * 12345)
		seed2 := uint64(i * 67890)
		pcg := rand.NewPCG(seed1, seed2)
		r := rand.New(pcg)

		params := genImageParamsString(r)
		p, err := parseImageParams(params)
		uassert.NoError(t, err)

		// Should never panic
		uassert.NotPanics(t, func() {
			svg := p.generateSVG()
			// Verify basic SVG structure
			uassert.True(t, strings.Contains(svg, "<svg"))
			uassert.True(t, strings.Contains(svg, "</svg>"))
		})
	}
}

// extractCoordinates parses x1, y1, x2, y2 coordinate values from SVG string.
// The SVG format is: <linearGradient ... x1="7" y1="10" x2="123" y2="122" ...>
func extractCoordinates(t *testing.T, svg string) (x1, y1, x2, y2 int) {
	// Find linearGradient tag
	gradientIdx := strings.Index(svg, "linearGradient")
	if gradientIdx == -1 {
		t.Fatal("linearGradient tag not found")
	}

	// Extract the linearGradient tag content (up to closing >)
	gradientStart := gradientIdx
	gradientEnd := strings.Index(svg[gradientStart:], ">")
	if gradientEnd == -1 {
		t.Fatal("linearGradient closing > not found")
	}
	gradientTag := svg[gradientStart : gradientStart+gradientEnd]

	// Extract x1
	x1 = extractIntValue(t, gradientTag, "x1=\"")
	// Extract y1
	y1 = extractIntValue(t, gradientTag, "y1=\"")
	// Extract x2
	x2 = extractIntValue(t, gradientTag, "x2=\"")
	// Extract y2
	y2 = extractIntValue(t, gradientTag, "y2=\"")

	return x1, y1, x2, y2
}

// extractIntValue extracts an integer value after the given prefix.
// For example, extractIntValue(tag, "x1=\"") extracts 7 from "x1=\"7\""
func extractIntValue(t *testing.T, text, prefix string) int {
	idx := strings.Index(text, prefix)
	if idx == -1 {
		t.Fatalf("prefix %s not found in text", prefix)
	}

	// Start after the prefix
	start := idx + len(prefix)
	// Find the closing quote
	end := strings.Index(text[start:], "\"")
	if end == -1 {
		t.Fatal("closing quote not found")
	}

	// Extract the number string
	numStr := text[start : start+end]

	// Parse to integer
	result := 0
	for i := 0; i < len(numStr); i++ {
		ch := numStr[i]
		if ch < '0' || ch > '9' {
			t.Fatalf("invalid digit in number: %c", ch)
		}
		result = result*10 + int(ch-'0')
	}

	return result
}

// TestSvgGenerator_parseImageParams tests the parseImageParams function
// which validates and parses the expected parameter format.
func TestSvgGenerator_parseImageParams(t *testing.T) {
	tests := []struct {
		name          string
		input         string
		expectedError error
	}{
		{
			name:  "valid params - standard format",
			input: "10,12,125,123,#FF0000,#00FF00",
		},
		{
			name:  "valid params - boundary min values",
			input: "7,7,121,121,#000000,#FFFFFF",
		},
		{
			name:  "valid params - boundary max values",
			input: "13,13,126,126,#ABCDEF,#123456",
		},
		{
			name:  "valid params - lowercase hex colors",
			input: "10,10,125,125,#aabbcc,#ddeeff",
		},
		{
			name:  "valid params - mixed case hex colors",
			input: "10,10,125,125,#AaBbCc,#DdEeFf",
		},
		// Invalid cases - wrong comma count
		{
			name:          "invalid - no commas (plain URI)",
			input:         "https://example.com/token/1",
			expectedError: errInvalidTokenParams,
		},
		{
			name:          "invalid - too few commas (4 commas)",
			input:         "10,12,125,123,#FF0000",
			expectedError: errInvalidTokenParams,
		},
		{
			name:          "invalid - too many commas (6 commas)",
			input:         "10,12,125,123,#FF0000,#00FF00,extra",
			expectedError: errInvalidTokenParams,
		},
		// Invalid cases - non-numeric coordinates
		{
			name:          "invalid - first param not numeric",
			input:         "abc,12,125,123,#FF0000,#00FF00",
			expectedError: errInvalidTokenParams,
		},
		{
			name:          "invalid - second param not numeric",
			input:         "10,xyz,125,123,#FF0000,#00FF00",
			expectedError: errInvalidTokenParams,
		},
		{
			name:          "invalid - third param not numeric",
			input:         "10,12,foo,123,#FF0000,#00FF00",
			expectedError: errInvalidTokenParams,
		},
		{
			name:          "invalid - fourth param not numeric",
			input:         "10,12,125,bar,#FF0000,#00FF00",
			expectedError: errInvalidTokenParams,
		},
		{
			name:          "invalid - empty first param",
			input:         ",12,125,123,#FF0000,#00FF00",
			expectedError: errInvalidTokenParams,
		},
		// Invalid cases - invalid color format
		{
			name:          "invalid - color1 missing hash",
			input:         "10,12,125,123,FF0000,#00FF00",
			expectedError: errInvalidColorFormat,
		},
		{
			name:          "invalid - color2 missing hash",
			input:         "10,12,125,123,#FF0000,00FF00",
			expectedError: errInvalidColorFormat,
		},
		{
			name:          "invalid - color1 too short",
			input:         "10,12,125,123,#FF00,#00FF00",
			expectedError: errInvalidColorFormat,
		},
		{
			name:          "invalid - color2 too long",
			input:         "10,12,125,123,#FF0000,#00FF00FF",
			expectedError: errInvalidColorFormat,
		},
		{
			name:          "invalid - color with invalid hex chars",
			input:         "10,12,125,123,#GGGGGG,#00FF00",
			expectedError: errInvalidColorFormat,
		},
		{
			name:          "invalid - empty color",
			input:         "10,12,125,123,,#00FF00",
			expectedError: errInvalidColorFormat,
		},
		// Edge cases
		{
			name:          "invalid - empty string",
			input:         "",
			expectedError: errInvalidTokenParams,
		},
		{
			name:          "invalid - only commas",
			input:         ",,,,,",
			expectedError: errInvalidTokenParams,
		},
		{
			name:          "invalid - spaces in params",
			input:         "10, 12, 125, 123, #FF0000, #00FF00",
			expectedError: errInvalidTokenParams,
		},
		{
			name:          "invalid - negative numbers",
			input:         "-10,12,125,123,#FF0000,#00FF00",
			expectedError: errInvalidTokenParamsRange,
		},
		// Invalid cases - coordinate range validation
		{
			name:          "invalid - x1 below min range (6 < 7)",
			input:         "6,12,125,123,#FF0000,#00FF00",
			expectedError: errInvalidTokenParamsRange,
		},
		{
			name:          "invalid - x1 above max range (14 > 13)",
			input:         "14,12,125,123,#FF0000,#00FF00",
			expectedError: errInvalidTokenParamsRange,
		},
		{
			name:          "invalid - y1 below min range (6 < 7)",
			input:         "10,6,125,123,#FF0000,#00FF00",
			expectedError: errInvalidTokenParamsRange,
		},
		{
			name:          "invalid - y1 above max range (14 > 13)",
			input:         "10,14,125,123,#FF0000,#00FF00",
			expectedError: errInvalidTokenParamsRange,
		},
		{
			name:          "invalid - x2 below min range (120 < 121)",
			input:         "10,12,120,123,#FF0000,#00FF00",
			expectedError: errInvalidTokenParamsRange,
		},
		{
			name:          "invalid - x2 above max range (127 > 126)",
			input:         "10,12,127,123,#FF0000,#00FF00",
			expectedError: errInvalidTokenParamsRange,
		},
		{
			name:          "invalid - y2 below min range (120 < 121)",
			input:         "10,12,125,120,#FF0000,#00FF00",
			expectedError: errInvalidTokenParamsRange,
		},
		{
			name:          "invalid - y2 above max range (127 > 126)",
			input:         "10,12,125,127,#FF0000,#00FF00",
			expectedError: errInvalidTokenParamsRange,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			_, err := parseImageParams(tc.input)
			if tc.expectedError == nil {
				uassert.NoError(t, err)
			} else {
				uassert.Error(t, err)
				// For range validation errors, check if error contains base error message
				// (detailed errors include coordinate info)
				if tc.expectedError == errInvalidTokenParamsRange {
					uassert.True(t, strings.Contains(err.Error(), tc.expectedError.Error()))
				} else {
					uassert.Equal(t, tc.expectedError.Error(), err.Error())
				}
			}
		})
	}
}

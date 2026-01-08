package gnft

import (
	b64 "encoding/base64"
	"math/rand"
	"strconv"
	"strings"

	"gno.land/p/nt/ufmt"
)

// SVG template structure:
// The template is split at variable insertion points for efficient string concatenation.
// Full template with placeholders (for reference):
//
//	<svg width="135" height="135" viewBox="0 0 135 135" fill="none" xmlns="...">
//	  <g clip-path="url(#clip0_7698_56846)">
//	    <circle cx="67.5" cy="67.5" r="67.5" fill="url(#paint0_linear_7698_56846)"/>
//	    ... (path elements) ...
//	  </g>
//	  <defs>
//	    <linearGradient id="paint0_linear_7698_56846"
//	      x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}"   <-- variables
//	      gradientUnits="userSpaceOnUse">
//	      <stop stop-color="{color1}"/>             <-- variable
//	      <stop offset="1" stop-color="{color2}"/>  <-- variable
//	    </linearGradient>
//	    ...
//	  </defs>
//	</svg>

// svgTemplate holds pre-split template parts for efficient concatenation.
// Usage: svgTemplate[0] + x1 + svgTemplate[1] + y1 + ... + color2 + svgTemplate[6]
var svgTemplate = [7]string{
	// [0] SVG header and body (before x1)
	`<svg width="135" height="135" viewBox="0 0 135 135" fill="none" xmlns="http://www.w3.org/2000/svg">
<g clip-path="url(#clip0_7698_56846)">
<circle cx="67.5" cy="67.5" r="67.5" fill="url(#paint0_linear_7698_56846)"/>
<path d="M51.2905 42.9449L66.4895 33L97 52.8061L81.8241 62.7425L51.2905 42.9449Z" fill="white"/>
<path d="M51.6055 67.5059L66.8044 57.561L97 77.0657L82.1046 87.1793L51.6055 67.5059Z" fill="white" fill-opacity="0.4"/>
<path d="M36.0464 81.7559L51.2905 71.811L81.7336 91.6547L66.4895 101.508L36.0464 81.7559Z" fill="white" fill-opacity="0.6"/>
<path d="M36.001 52.8055L51.2884 42.9177L51.2884 71.8145L36.001 81.779L36.001 52.8055Z" fill="white"/>
<path d="M82.1051 87.1797L97.0016 77.0662L97.0016 81.7029L81.7896 91.629L82.1051 87.1797Z" fill="white" fill-opacity="0.5"/>
</g>
<defs>
<linearGradient id="paint0_linear_7698_56846" x1="`,
	// [1] between x1 and y1
	`" y1="`,
	// [2] between y1 and x2
	`" x2="`,
	// [3] between x2 and y2
	`" y2="`,
	// [4] between y2 and color1
	`" gradientUnits="userSpaceOnUse">
<stop stop-color="`,
	// [5] between color1 and color2
	`"/>
<stop offset="1" stop-color="`,
	// [6] SVG footer (after color2)
	`"/>
</linearGradient>
<clipPath id="clip0_7698_56846">
<rect width="135" height="135" fill="white"/>
</clipPath>
</defs>
</svg>
`,
}

// charset contains valid hex digits for color generation.
const charset = "0123456789ABCDEF"

// Parameter range constants for gradient coordinates.
const (
	x1Min = 7
	x1Max = 13
	y1Min = 7
	y1Max = 13
	x2Min = 121
	x2Max = 126
	y2Min = 121
	y2Max = 126

	x1Range = x1Max - x1Min + 1
	y1Range = y1Max - y1Min + 1
	x2Range = x2Max - x2Min + 1
	y2Range = y2Max - y2Min + 1
)

// genImageParamsString generates random gradient parameters and returns them as a compact string.
// Format: "x1,y1,x2,y2,color1,color2" (e.g., "10,12,125,123,#AABBCC,#DDEEFF")
func genImageParamsString(r *rand.Rand) string {
	x1 := x1Min + r.Uint64N(x1Range)
	y1 := y1Min + r.Uint64N(y1Range)
	x2 := x2Min + r.Uint64N(x2Range)
	y2 := y2Min + r.Uint64N(y2Range)

	var buf1 [7]byte
	var buf2 [7]byte
	buf1[0] = '#'
	buf2[0] = '#'
	for i := 1; i < 7; i++ {
		buf1[i] = charset[r.IntN(16)]
		buf2[i] = charset[r.IntN(16)]
	}
	color1 := string(buf1[:])
	color2 := string(buf2[:])

	return strconv.Itoa(int(x1)) + "," + strconv.Itoa(int(y1)) + "," +
		strconv.Itoa(int(x2)) + "," + strconv.Itoa(int(y2)) + "," +
		color1 + "," + color2
}

// ImageParams holds parsed and validated image parameters.
type ImageParams struct {
	x1, y1, x2, y2 int
	color1, color2 string
}

// validateCoordinate checks if a coordinate value is within valid range.
// Returns error with details about which coordinate failed if out of range.
func validateCoordinate(value int, min int, max int, name string) error {
	if value < min || value > max {
		details := ufmt.Sprintf("%s=%d (expected range: [%d, %d])", name, value, min, max)
		return makeErrorWithDetails(errInvalidTokenParamsRange, details)
	}
	return nil
}

// parseImageParams parses and validates parameters in one step.
// Returns parsed ImageParams pointer or error.
// Returns nil on error to avoid allocating zero-value struct.
// Expected format: "x1,y1,x2,y2,color1,color2"
func parseImageParams(s string) (*ImageParams, error) {
	parts := strings.Split(s, ",")
	if len(parts) != 6 {
		return nil, errInvalidTokenParams
	}

	x1, err := strconv.Atoi(parts[0])
	if err != nil {
		return nil, errInvalidTokenParams
	}

	y1, err := strconv.Atoi(parts[1])
	if err != nil {
		return nil, errInvalidTokenParams
	}

	x2, err := strconv.Atoi(parts[2])
	if err != nil {
		return nil, errInvalidTokenParams
	}

	y2, err := strconv.Atoi(parts[3])
	if err != nil {
		return nil, errInvalidTokenParams
	}

	// Validate coordinate ranges with detailed error messages
	if err := validateCoordinate(x1, x1Min, x1Max, "x1"); err != nil {
		return nil, err
	}
	if err := validateCoordinate(y1, y1Min, y1Max, "y1"); err != nil {
		return nil, err
	}
	if err := validateCoordinate(x2, x2Min, x2Max, "x2"); err != nil {
		return nil, err
	}
	if err := validateCoordinate(y2, y2Min, y2Max, "y2"); err != nil {
		return nil, err
	}

	color1 := parts[4]
	color2 := parts[5]

	// Validate color format (#XXXXXX)
	if !isValidHexColor(color1) || !isValidHexColor(color2) {
		return nil, errInvalidColorFormat
	}

	return &ImageParams{
		x1:     x1,
		y1:     y1,
		x2:     x2,
		y2:     y2,
		color1: color1,
		color2: color2,
	}, nil
}

// generateImageURI converts parsed image parameters to a base64-encoded SVG image URI.
func (params ImageParams) generateImageURI() string {
	svg := params.generateSVG()
	sEnc := b64.StdEncoding.EncodeToString([]byte(svg))

	return "data:image/svg+xml;base64," + sEnc
}

// generateSVG generates SVG image from parsed and validated parameters.
func (params ImageParams) generateSVG() string {
	return svgTemplate[0] + strconv.Itoa(params.x1) + svgTemplate[1] + strconv.Itoa(params.y1) +
		svgTemplate[2] + strconv.Itoa(params.x2) + svgTemplate[3] + strconv.Itoa(params.y2) +
		svgTemplate[4] + params.color1 + svgTemplate[5] + params.color2 + svgTemplate[6]
}

// isValidHexColor checks if a string is a valid hex color in #XXXXXX format.
func isValidHexColor(color string) bool {
	if len(color) != 7 || color[0] != '#' {
		return false
	}

	for i := 1; i < 7; i++ {
		c := color[i]

		isHex := (c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f')
		if !isHex {
			return false
		}
	}

	return true
}

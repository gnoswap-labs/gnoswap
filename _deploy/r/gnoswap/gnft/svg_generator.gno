package gnft

import (
	b64 "encoding/base64"
	"math/rand"
	"strings"

	"gno.land/p/demo/ufmt"
)

var baseTempalte = `<svg width="135" height="135" viewBox="0 0 135 135" fill="none" xmlns="http://www.w3.org/2000/svg">
<circle cx="67" cy="68" r="46" fill="url(#paint0_linear_7698_56946)"/>
<path d="M58.7734 53.6828L67.4941 48L85.0002 59.3178L76.2927 64.9957L58.7734 53.6828Z" fill="white"/>
<path d="M58.9541 67.7177L67.6748 62.0349L85.0001 73.1804L76.4536 78.9596L58.9541 67.7177Z" fill="white" fill-opacity="0.4"/>
<path d="M50.0269 75.8605L58.7735 70.1777L76.2408 81.517L67.4942 87.1472L50.0269 75.8605Z" fill="white" fill-opacity="0.6"/>
<path d="M50.001 59.3174L58.7724 53.6672L58.7724 70.1797L50.001 75.8737L50.001 59.3174Z" fill="white"/>
<path d="M76.4545 78.9598L85.0017 73.1807L85.0017 75.8302L76.2734 81.5023L76.4545 78.9598Z" fill="white" fill-opacity="0.5"/>
<path d="M58.7734 53.6828L67.4941 48L85.0002 59.3178L76.2927 64.9957L58.7734 53.6828Z" fill="white"/>
<path d="M58.9541 67.7177L67.6748 62.0349L85.0001 73.1804L76.4536 78.9596L58.9541 67.7177Z" fill="white" fill-opacity="0.4"/>
<path d="M50.0269 75.8605L58.7735 70.1777L76.2408 81.517L67.4942 87.1472L50.0269 75.8605Z" fill="white" fill-opacity="0.6"/>
<path d="M50.001 59.3174L58.7724 53.6672L58.7724 70.1797L50.001 75.8737L50.001 59.3174Z" fill="white"/>
<path d="M76.4545 78.9598L85.0017 73.1807L85.0017 75.8302L76.2734 81.5023L76.4545 78.9598Z" fill="white" fill-opacity="0.5"/>
<defs>
<linearGradient id="paint0_linear_7698_56946" x1="%d" y1="%d" x2="%d" y2="%d" gradientUnits="userSpaceOnUse">
	<stop stop-color="%s"/>
	<stop offset="1" stop-color="%s"/>
</linearGradient>
</defs>
</svg>
`

// range for hex color
const charset = "0123456789ABCDEF"

func genImageURI(r *rand.Rand) string {
	imageRaw := genImageRaw(r)
	sEnc := b64.StdEncoding.EncodeToString([]byte(imageRaw))

	return "data:image/svg+xml;base64," + sEnc
}

func genImageRaw(r *rand.Rand) string {
	x1 := 7 + r.Uint64N(7)
	y1 := 7 + r.Uint64N(7)

	x2 := 121 + r.Uint64N(6)
	y2 := 121 + r.Uint64N(6)

	var color1, color2 strings.Builder
	color1.Grow(7)
	color2.Grow(7)
	color1.WriteByte('#')
	color2.WriteByte('#')

	for i := 0; i < 6; i++ {
		color1.WriteByte(charset[r.IntN(16)])
		color2.WriteByte(charset[r.IntN(16)])
	}

	randImage := ufmt.Sprintf(baseTempalte, x1, y1, x2, y2, color1.String(), color2.String())
	return randImage
}
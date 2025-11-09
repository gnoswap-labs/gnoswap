package main

import (
	"fmt"
	"regexp"
	"strings"
)

const (
	// DefaultMaskSpec is applied when no custom mask flag is provided.
	DefaultMaskSpec    = "timestamp,bytes_delta,fee_delta.amount"
	defaultMaskPattern = "[0-9]+"
	placeholderPrefix  = "__MASK_PLACEHOLDER_"
)

var (
	metricPrefixes = []string{
		"GAS USED:",
		"GAS WANTED:",
		"STORAGE DELTA:",
		"STORAGE FEE:",
		"TOTAL TX COST:",
	}

	addressPattern = regexp.MustCompile(`g1[0-9a-z]{38}`)
)

// MaskPattern describes a dynamic field that should be replaced with a regex placeholder.
type MaskPattern struct {
	spec        string
	replacement string
	re          *regexp.Regexp
}

// Converter turns raw output lines into escaped testscript expectations.
type Converter struct {
	kind      string
	trimSpace bool
	skipEmpty bool
	patterns  []MaskPattern
}

// NewConverter returns a Converter for the provided keyword (stdout/stderr).
func NewConverter(kind string, trim, skip bool, patterns []MaskPattern) Converter {
	return Converter{
		kind:      kind,
		trimSpace: trim,
		skipEmpty: skip,
		patterns:  patterns,
	}
}

// ConvertLine escapes a single line and returns the formatted expectation.
func (c Converter) ConvertLine(line string) (string, bool) {
	if c.trimSpace {
		line = strings.TrimSpace(line)
	} else {
		line = strings.TrimRight(line, "\r\n")
	}

	if c.skipEmpty && line == "" {
		return "", false
	}

	if line == "" {
		return fmt.Sprintf("%s ''", c.kind), true
	}

	var placeholders []placeholder

	line = applyMetricMask(line, &placeholders)
	line = maskAddresses(line, &placeholders)

	for _, pattern := range c.patterns {
		line = applyMask(line, pattern, &placeholders)
	}

	escaped := regexp.QuoteMeta(line)
	for _, ph := range placeholders {
		escaped = strings.ReplaceAll(escaped, ph.token, ph.pattern)
	}

	escaped = strings.ReplaceAll(escaped, `"`, `\"`)
	escaped = strings.ReplaceAll(escaped, `'`, `\'`)
	return fmt.Sprintf("%s '%s'", c.kind, escaped), true
}

type placeholder struct {
	token   string
	pattern string
}

func applyMask(line string, pattern MaskPattern, placeholders *[]placeholder) string {
	if pattern.re == nil {
		return line
	}

	matches := pattern.re.FindAllStringSubmatchIndex(line, -1)
	if len(matches) == 0 {
		return line
	}

	var builder strings.Builder
	last := 0
	for _, match := range matches {
		if len(match) < 6 {
			continue
		}

		valueStart, valueEnd := match[4], match[5]
		builder.WriteString(line[last:valueStart])

		token := fmt.Sprintf("%s%d__", placeholderPrefix, len(*placeholders))
		*placeholders = append(*placeholders, placeholder{
			token:   token,
			pattern: pattern.replacement,
		})

		builder.WriteString(token)
		last = valueEnd
	}

	builder.WriteString(line[last:])
	return builder.String()
}

func applyMetricMask(line string, placeholders *[]placeholder) string {
	trimmed := strings.TrimSpace(line)
	for _, prefix := range metricPrefixes {
		if strings.HasPrefix(trimmed, prefix) {
			return maskDigits(line, placeholders)
		}
	}

	return line
}

func maskDigits(line string, placeholders *[]placeholder) string {
	var builder strings.Builder
	for i := 0; i < len(line); {
		ch := line[i]
		if ch < '0' || ch > '9' {
			builder.WriteByte(ch)
			i++
			continue
		}

		start := i
		for i < len(line) && line[i] >= '0' && line[i] <= '9' {
			i++
		}

		digits := line[start:i]
		if len(digits) == 1 {
			builder.WriteString(digits)
			continue
		}

		token := fmt.Sprintf("%s%d__", placeholderPrefix, len(*placeholders))
		pattern := fmt.Sprintf("%c[0-9]{%d}", digits[0], len(digits)-1)
		*placeholders = append(*placeholders, placeholder{
			token:   token,
			pattern: pattern,
		})
		builder.WriteString(token)
	}

	return builder.String()
}

func maskAddresses(line string, placeholders *[]placeholder) string {
	return addressPattern.ReplaceAllStringFunc(line, func(addr string) string {
		token := fmt.Sprintf("%s%d__", placeholderPrefix, len(*placeholders))
		*placeholders = append(*placeholders, placeholder{
			token:   token,
			pattern: "g1[0-9a-z]{38}",
		})
		return token
	})
}

// ParseMaskPatterns parses the comma-separated mask specification.
func ParseMaskPatterns(spec string) ([]MaskPattern, error) {
	spec = strings.TrimSpace(spec)
	if spec == "" {
		return nil, nil
	}

	items := strings.Split(spec, ",")
	patterns := make([]MaskPattern, 0, len(items))
	for _, item := range items {
		item = strings.TrimSpace(item)
		if item == "" {
			continue
		}

		key := item
		replacement := defaultMaskPattern
		if parts := strings.SplitN(item, "=", 2); len(parts) == 2 {
			key = strings.TrimSpace(parts[0])
			replacement = strings.TrimSpace(parts[1])
			if replacement == "" {
				replacement = defaultMaskPattern
			}
		}

		mp, err := buildMaskPattern(key, replacement)
		if err != nil {
			return nil, err
		}

		patterns = append(patterns, mp)
	}

	return patterns, nil
}

func buildMaskPattern(path, replacement string) (MaskPattern, error) {
	if path == "" {
		return MaskPattern{}, fmt.Errorf("mask path is empty")
	}

	segments := strings.Split(path, ".")
	if len(segments) == 0 || len(segments) > 2 {
		return MaskPattern{}, fmt.Errorf("mask path %q is invalid", path)
	}

	var expr string
	if len(segments) == 1 {
		key := regexp.QuoteMeta(segments[0])
		expr = fmt.Sprintf(`((?:"%s"|%s)\s*[:=]\s*)(-?\d+)`, key, key)
	} else {
		parent := regexp.QuoteMeta(segments[0])
		child := regexp.QuoteMeta(segments[1])
		expr = fmt.Sprintf(`((?:"%s"|%s)\s*:\s*\{[^}]*?(?:(?:"%s"|%s)\s*[:=]\s*))(-?\d+)`, parent, parent, child, child)
	}

	re, err := regexp.Compile(expr)
	if err != nil {
		return MaskPattern{}, fmt.Errorf("compile mask %q: %w", path, err)
	}

	return MaskPattern{
		spec:        path,
		replacement: replacement,
		re:          re,
	}, nil
}

package main

import (
	"fmt"
	"regexp"
	"strings"
)

const (
	// DefaultMaskSpec is applied when no custom mask flag is provided.
	DefaultMaskSpec    = "timestamp,bytes_delta,fee_delta.amount,currentTime,currentHeight,observationTimestamp"
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

	// Precompiled regex patterns for better performance
	addressPattern = regexp.MustCompile(`g1[0-9a-z]{38}`)
	digitPattern   = regexp.MustCompile(`\d{2,}`) // 2자리 이상의 숫자
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

// placeholder represents a temporary token and its regex replacement pattern.
type placeholder struct {
	token   string
	pattern string
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
	line = c.normalizeLine(line)

	if c.skipEmpty && line == "" {
		return "", false
	}

	if line == "" {
		return fmt.Sprintf("%s ''", c.kind), true
	}

	placeholders := make([]placeholder, 0, 8) // Pre-allocate with reasonable capacity

	// Apply masking in order
	line = c.applyAllMasks(line, &placeholders)

	// Escape and replace placeholders
	escaped := c.escapeAndReplace(line, placeholders)

	return fmt.Sprintf("%s '%s'", c.kind, escaped), true
}

// normalizeLine trims or cleans up the line based on converter settings.
func (c Converter) normalizeLine(line string) string {
	if c.trimSpace {
		return strings.TrimSpace(line)
	}
	return strings.TrimRight(line, "\r\n")
}

// applyAllMasks applies all masking operations to the line.
func (c Converter) applyAllMasks(line string, placeholders *[]placeholder) string {
	line = applyMetricMask(line, placeholders)
	line = maskAddresses(line, placeholders)

	for _, pattern := range c.patterns {
		line = applyMask(line, pattern, placeholders)
	}

	return line
}

// escapeAndReplace escapes the line and replaces placeholders with their patterns.
func (c Converter) escapeAndReplace(line string, placeholders []placeholder) string {
	escaped := regexp.QuoteMeta(line)

	// Replace all placeholders with their regex patterns
	for _, ph := range placeholders {
		escaped = strings.ReplaceAll(escaped, ph.token, ph.pattern)
	}

	// Escape quotes
	escaped = strings.ReplaceAll(escaped, `"`, `\"`)
	escaped = strings.ReplaceAll(escaped, `'`, `\'`)

	return escaped
}

// applyMask applies a single mask pattern to the line.
func applyMask(line string, pattern MaskPattern, placeholders *[]placeholder) string {
	if pattern.re == nil {
		return line
	}

	matches := pattern.re.FindAllStringSubmatchIndex(line, -1)
	if len(matches) == 0 {
		return line
	}

	var builder strings.Builder
	builder.Grow(len(line) + len(matches)*len(placeholderPrefix)) // Optimize allocation

	last := 0
	for _, match := range matches {
		valueStart, valueEnd := extractValueIndices(match)
		if valueStart == -1 {
			continue
		}

		builder.WriteString(line[last:valueStart])

		token := createPlaceholder(len(*placeholders), pattern.replacement, placeholders)
		builder.WriteString(token)

		last = valueEnd
	}

	builder.WriteString(line[last:])
	return builder.String()
}

// extractValueIndices determines the start and end indices of the value to mask.
func extractValueIndices(match []int) (int, int) {
	// Check attrs format first (groups 3-5)
	if len(match) >= 10 && match[6] != -1 && match[7] != -1 {
		return match[8], match[9] // {"key":"X","value":"123"}
	}

	// Check standard format (groups 1-2)
	if len(match) >= 6 && match[2] != -1 && match[3] != -1 {
		return match[4], match[5] // "X":123
	}

	// Two-segment pattern
	if len(match) >= 6 {
		return match[4], match[5]
	}

	return -1, -1
}

// createPlaceholder creates a new placeholder token and adds it to the list.
func createPlaceholder(index int, pattern string, placeholders *[]placeholder) string {
	token := fmt.Sprintf("%s%d__", placeholderPrefix, index)
	*placeholders = append(*placeholders, placeholder{
		token:   token,
		pattern: pattern,
	})
	return token
}

// applyMetricMask masks digits in lines starting with known metric prefixes.
func applyMetricMask(line string, placeholders *[]placeholder) string {
	trimmed := strings.TrimSpace(line)

	for _, prefix := range metricPrefixes {
		if strings.HasPrefix(trimmed, prefix) {
			return maskDigits(line, placeholders)
		}
	}

	return line
}

// maskDigits masks all multi-digit numbers in the line.
func maskDigits(line string, placeholders *[]placeholder) string {
	return digitPattern.ReplaceAllStringFunc(line, func(digits string) string {
		if len(digits) == 1 {
			return digits
		}

		pattern := fmt.Sprintf("%c[0-9]{%d}", digits[0], len(digits)-1)
		return createPlaceholder(len(*placeholders), pattern, placeholders)
	})
}

// maskAddresses replaces all g1 addresses with placeholders.
func maskAddresses(line string, placeholders *[]placeholder) string {
	return addressPattern.ReplaceAllStringFunc(line, func(addr string) string {
		return createPlaceholder(len(*placeholders), "g1[0-9a-z]{38}", placeholders)
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

		key, replacement := parseKeyValue(item)

		mp, err := buildMaskPattern(key, replacement)
		if err != nil {
			return nil, err
		}

		patterns = append(patterns, mp)
	}

	return patterns, nil
}

// parseKeyValue splits "key=value" into key and value, with default value.
func parseKeyValue(item string) (string, string) {
	parts := strings.SplitN(item, "=", 2)
	if len(parts) == 2 {
		key := strings.TrimSpace(parts[0])
		replacement := strings.TrimSpace(parts[1])
		if replacement == "" {
			replacement = defaultMaskPattern
		}
		return key, replacement
	}
	return item, defaultMaskPattern
}

// buildMaskPattern constructs a MaskPattern from a path and replacement string.
func buildMaskPattern(path, replacement string) (MaskPattern, error) {
	if path == "" {
		return MaskPattern{}, fmt.Errorf("mask path is empty")
	}

	segments := strings.Split(path, ".")
	if len(segments) == 0 || len(segments) > 2 {
		return MaskPattern{}, fmt.Errorf("mask path %q is invalid (must have 1 or 2 segments)", path)
	}

	var expr string
	if len(segments) == 1 {
		expr = buildSingleSegmentPattern(segments[0])
	} else {
		expr = buildTwoSegmentPattern(segments[0], segments[1])
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

// buildSingleSegmentPattern creates regex for single-level keys.
// Matches both: "currentTime":1234 and {"key":"currentTime","value":"1234"}
func buildSingleSegmentPattern(key string) string {
	quotedKey := regexp.QuoteMeta(key)

	// Standard format: "key":123 or key:123
	standardPattern := fmt.Sprintf(`(?:"%s"|%s)\s*[:=]\s*`, quotedKey, quotedKey)

	// Attrs array format: {"key":"key","value":"123"}
	attrsPattern := fmt.Sprintf(`\{\"key\":\s*\"%s\"\s*,\s*\"value\":\s*\"`, quotedKey)

	return fmt.Sprintf(`(?:(%s)(-?\d+)|(%s)(-?\d+)(\"))`, standardPattern, attrsPattern)
}

// buildTwoSegmentPattern creates regex for nested keys like "parent.child".
func buildTwoSegmentPattern(parent, child string) string {
	quotedParent := regexp.QuoteMeta(parent)
	quotedChild := regexp.QuoteMeta(child)

	return fmt.Sprintf(
		`((?:"%s"|%s)\s*:\s*\{[^}]*?(?:(?:"%s"|%s)\s*[:=]\s*))(-?\d+)`,
		quotedParent, quotedParent, quotedChild, quotedChild,
	)
}

package launchpad

import (
	"strings"

	"gno.land/p/demo/json"
)

type TimeInfo struct {
	height uint64
	time   uint64
}

func (t *TimeInfo) Height() uint64     { return t.height }
func (t *TimeInfo) SetHeight(v uint64) { t.height = v }
func (t *TimeInfo) Time() uint64       { return t.time }
func (t *TimeInfo) SetTime(v uint64)   { t.time = v }

// NewTimeInfo create a new TimeInfo instance.
func NewTimeInfo(height, time uint64) TimeInfo {
	return TimeInfo{height, time}
}

func (t *TimeInfo) isEnded(current uint64) bool {
	return t.Height() < current
}

func (t *TimeInfo) JSON(b *json.NodeBuilder, prefix string) *json.NodeBuilder {
	return b.
		WriteString(prefix+"Height", formatUint64(t.height)).
		WriteString(prefix+"Time", formatUint64(t.time))
}

type RefundInfo struct {
	amount uint64
	height uint64
	time   uint64
}

func (r *RefundInfo) Amount() uint64     { return r.amount }
func (r *RefundInfo) SetAmount(v uint64) { r.amount = v }
func (r *RefundInfo) Height() uint64     { return r.height }
func (r *RefundInfo) SetHeight(v uint64) { r.height = v }
func (r *RefundInfo) Time() uint64       { return r.time }
func (r *RefundInfo) SetTime(v uint64)   { r.time = v }

// NewRefundInfo create a new RefundInfo instance.
func NewRefundInfo(amount, height, time uint64) RefundInfo {
	return RefundInfo{amount, height, time}
}

func (r *RefundInfo) JSON(b *json.NodeBuilder) *json.NodeBuilder {
	return b.
		WriteString("amount", formatUint64(r.amount)).
		WriteString("height", formatUint64(r.height)).
		WriteString("time", formatUint64(r.time))
}

type Condition struct {
	tokenPath string
	minAmount uint64
}

func (c *Condition) TokenPath() string     { return c.tokenPath }
func (c *Condition) MinAmount() uint64     { return c.minAmount }
func (c *Condition) SetTokenPath(v string) { c.tokenPath = v }
func (c *Condition) SetMinAmount(v uint64) { c.minAmount = v }

// NewCondition create a new Condition instance.
func NewCondition(tokenPath string, minAmount uint64) Condition {
	return Condition{tokenPath, minAmount}
}

func (c *Condition) JSON(b *json.NodeBuilder) *json.NodeBuilder {
	panic("not implemented yet")
}

func makeConditionsToStr(conditions map[string]Condition) (string, string) {
	var tokenPathList string
	var amountList string

	for tokenPath, condition := range conditions {
		// append with *PAD*, except last one
		tokenPathList += tokenPath + PAD_SEP
		amountList += formatUint64(condition.minAmount) + PAD_SEP
	}

	// remove last *PAD*
	tokenPathList = strings.TrimSuffix(tokenPathList, PAD_SEP)
	amountList = strings.TrimSuffix(amountList, PAD_SEP)

	return tokenPathList, amountList
}

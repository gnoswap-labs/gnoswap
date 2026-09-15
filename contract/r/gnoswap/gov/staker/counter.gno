package staker

type Counter struct {
	id int64
}

// NewCounter creates a counter initialized before the first allocated identifier.
//
// Returns:
//   - *Counter: counter whose current identifier is zero.
func NewCounter() *Counter {
	return &Counter{id: 0}
}

// Get returns the counter's current identifier without incrementing it.
//
// Returns:
//   - int64: most recently allocated identifier, or zero for a new counter.
func (c *Counter) Get() int64 { return c.id }

// Next increments the counter and returns the newly allocated identifier.
//
// Returns:
//   - int64: next identifier after incrementing the counter by one.
func (c *Counter) Next() int64 {
	c.id++
	return c.id
}

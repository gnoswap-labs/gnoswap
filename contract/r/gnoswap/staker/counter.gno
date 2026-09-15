package staker

type Counter struct {
	id int64
}

// NewCounter creates a counter initialized at zero.
//
// Returns:
//   - counter: Counter whose next generated identifier is 1.
func NewCounter() *Counter {
	return &Counter{
		id: 0,
	}
}

// Next increments the counter and returns the new identifier.
//
// Returns:
//   - id: Counter value after incrementing by one.
func (c *Counter) Next() int64 {
	c.id++

	return c.id
}

// Get returns the counter's current identifier without incrementing it.
//
// Returns:
//   - id: Current counter value.
func (c *Counter) Get() int64 {
	return c.id
}

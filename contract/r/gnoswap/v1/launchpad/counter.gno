package launchpad

// Counter manages unique incrementing IDs.
type Counter struct {
	id int64
}

// NewCounter creates a new Counter starting at 0.
func NewCounter() *Counter {
	return &Counter{
		id: 0,
	}
}

// next increments the counter and returns the next ID.
func (c *Counter) next() int64 {
	c.id++

	return c.id
}

// Get returns the current ID without incrementing.
func (c *Counter) Get() int64 {
	return c.id
}

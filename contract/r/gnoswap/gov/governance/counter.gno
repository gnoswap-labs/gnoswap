package governance

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

// Get returns the current ID without incrementing.
func (c *Counter) Get() int64   { return c.id }
func (c *Counter) Set(id int64) { c.id = id }

// next increments and returns the next ID.
func (c *Counter) Next() int64 {
	c.id++
	return c.id
}

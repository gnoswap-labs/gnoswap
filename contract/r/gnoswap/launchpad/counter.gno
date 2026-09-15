package launchpad

// Counter manages unique incrementing IDs.
type Counter struct {
	id int64
}

// NewCounter creates a new Counter starting at zero.
//
// Returns:
//   - counter: counter initialized with current ID zero.
func NewCounter() *Counter {
	return &Counter{
		id: 0,
	}
}

// Next increments the counter and returns the next unique ID.
//
// Returns:
//   - id: incremented counter value.
func (c *Counter) Next() int64 {
	c.id++

	return c.id
}

// Get returns the current counter ID without incrementing it.
//
// Returns:
//   - id: current counter value.
func (c *Counter) Get() int64 {
	return c.id
}

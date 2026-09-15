package governance

// Counter manages unique incrementing IDs.
type Counter struct {
	id int64
}

// NewCounter creates a new Counter whose current ID is initialized to zero.
//
// Returns:
//   - *Counter: counter initialized with current ID 0
func NewCounter() *Counter {
	return &Counter{
		id: 0,
	}
}

// Get returns the counter's current ID without changing it.
//
// Returns:
//   - int64: currently stored counter ID
func (c *Counter) Get() int64 { return c.id }

// Set replaces the counter's current ID with id.
//
// Parameters:
//   - id: new current ID to store; the value is not incremented
func (c *Counter) Set(id int64) { c.id = id }

// Next increments the counter and returns the resulting ID.
//
// Returns:
//   - int64: incremented counter ID after the update
func (c *Counter) Next() int64 {
	c.id++
	return c.id
}

package model

// DocValueSpec represents a single const or var declaration.
type DocValueSpec struct {
	DocNode
	Type  string
	Value string
}

// DocValueGroup represents a group of const or var declarations.
// For example: const ( A = 1; B = 2 )
type DocValueGroup struct {
	DocNode
	Specs []DocValueSpec
}

// Names returns the names of all specs in this group.
func (g DocValueGroup) Names() []string {
	names := make([]string, len(g.Specs))
	for i, spec := range g.Specs {
		names[i] = spec.Name
	}
	return names
}

// HasExported reports whether any spec in this group is exported.
func (g DocValueGroup) HasExported() bool {
	for _, spec := range g.Specs {
		if spec.IsExported() {
			return true
		}
	}
	return false
}

package model

// TypeKind represents the kind of a type declaration.
type TypeKind string

const (
	TypeKindStruct    TypeKind = "struct"
	TypeKindInterface TypeKind = "interface"
	TypeKindAlias     TypeKind = "alias"
	TypeKindOther     TypeKind = "other"
)

// String returns the string representation of the type kind.
func (k TypeKind) String() string {
	return string(k)
}

// DocType represents a type declaration.
type DocType struct {
	DocNode
	TypeKind     TypeKind
	Fields       []DocField
	Methods      []DocFunc
	Constructors []DocFunc
}

// IsStruct reports whether this is a struct type.
func (t DocType) IsStruct() bool {
	return t.TypeKind == TypeKindStruct
}

// IsInterface reports whether this is an interface type.
func (t DocType) IsInterface() bool {
	return t.TypeKind == TypeKindInterface
}

// HasMethods reports whether this type has any methods.
func (t DocType) HasMethods() bool {
	return len(t.Methods) > 0
}

// HasConstructors reports whether this type has any constructors.
func (t DocType) HasConstructors() bool {
	return len(t.Constructors) > 0
}

// ExportedFields returns only the exported fields.
func (t DocType) ExportedFields() []DocField {
	var result []DocField
	for _, f := range t.Fields {
		if f.IsExported() {
			result = append(result, f)
		}
	}
	return result
}

// ExportedMethods returns only the exported methods.
func (t DocType) ExportedMethods() []DocFunc {
	var result []DocFunc
	for _, m := range t.Methods {
		if m.IsExported() {
			result = append(result, m)
		}
	}
	return result
}

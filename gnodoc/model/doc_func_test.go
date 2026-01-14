package model

import "testing"

func TestDocFunc_ZeroValue(t *testing.T) {
	var fn DocFunc

	if fn.Name != "" {
		t.Errorf("expected empty Name, got %q", fn.Name)
	}
	if fn.Receiver != nil {
		t.Errorf("expected nil Receiver")
	}
	if len(fn.Params) != 0 {
		t.Errorf("expected empty Params")
	}
	if len(fn.Results) != 0 {
		t.Errorf("expected empty Results")
	}
}

func TestDocFunc_IsMethod(t *testing.T) {
	tests := []struct {
		name     string
		fn       DocFunc
		expected bool
	}{
		{
			name:     "function without receiver",
			fn:       DocFunc{DocNode: DocNode{Name: "Foo", Kind: KindFunc}},
			expected: false,
		},
		{
			name: "method with receiver",
			fn: DocFunc{
				DocNode:  DocNode{Name: "Bar", Kind: KindMethod},
				Receiver: &DocReceiver{Name: "f", Type: "Foo"},
			},
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.fn.IsMethod()
			if got != tt.expected {
				t.Errorf("IsMethod() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestDocFunc_ReceiverType(t *testing.T) {
	tests := []struct {
		name     string
		fn       DocFunc
		expected string
	}{
		{
			name:     "function",
			fn:       DocFunc{},
			expected: "",
		},
		{
			name: "method",
			fn: DocFunc{
				Receiver: &DocReceiver{Name: "f", Type: "Foo"},
			},
			expected: "Foo",
		},
		{
			name: "pointer receiver",
			fn: DocFunc{
				Receiver: &DocReceiver{Name: "f", Type: "*Foo"},
			},
			expected: "*Foo",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.fn.ReceiverType()
			if got != tt.expected {
				t.Errorf("ReceiverType() = %q, want %q", got, tt.expected)
			}
		})
	}
}

func TestDocFunc_FullSignature(t *testing.T) {
	tests := []struct {
		name     string
		fn       DocFunc
		expected string
	}{
		{
			name: "simple function no params no results",
			fn: DocFunc{
				DocNode: DocNode{Name: "DoSomething", Kind: KindFunc},
			},
			expected: "func DoSomething()",
		},
		{
			name: "function with params",
			fn: DocFunc{
				DocNode: DocNode{Name: "Add", Kind: KindFunc},
				Params: []DocParam{
					{Name: "a", Type: "int"},
					{Name: "b", Type: "int"},
				},
			},
			expected: "func Add(a int, b int)",
		},
		{
			name: "function with results",
			fn: DocFunc{
				DocNode: DocNode{Name: "GetValue", Kind: KindFunc},
				Results: []DocParam{
					{Type: "int"},
				},
			},
			expected: "func GetValue() int",
		},
		{
			name: "function with multiple results",
			fn: DocFunc{
				DocNode: DocNode{Name: "Parse", Kind: KindFunc},
				Params: []DocParam{
					{Name: "s", Type: "string"},
				},
				Results: []DocParam{
					{Type: "int"},
					{Type: "error"},
				},
			},
			expected: "func Parse(s string) (int, error)",
		},
		{
			name: "method with receiver",
			fn: DocFunc{
				DocNode:  DocNode{Name: "String", Kind: KindMethod},
				Receiver: &DocReceiver{Name: "f", Type: "Foo"},
				Results: []DocParam{
					{Type: "string"},
				},
			},
			expected: "func (f Foo) String() string",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.fn.FullSignature()
			if got != tt.expected {
				t.Errorf("FullSignature() = %q, want %q", got, tt.expected)
			}
		})
	}
}

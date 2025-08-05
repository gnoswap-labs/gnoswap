package governance

const (
	// Governance can execute multiple messages in a single proposal
	// each message is a string with the following format:
	// <pkgPath>*EXE*<function>*EXE*<params>
	// To execute a message, we need to parse the message and call the corresponding function
	// with the given parameters
	parameterSeparator = "*EXE*"

	messageSeparator = "*GOV*"

	maxTitleLength       = 255
	maxDescriptionLength = 10_000
	maxNumberOfExecution = 10
)

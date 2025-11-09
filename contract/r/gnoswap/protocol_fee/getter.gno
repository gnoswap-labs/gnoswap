package protocol_fee

// GetDomainPath returns the domain path of the protocol fee contract.
func GetDomainPath() string {
	return domainPath
}

// GetVersionPackagePath returns the current implementation package path.
func GetVersionPackagePath() string {
	return versionManager.GetCurrentPackagePath()
}

package protocol_fee

func GetDomainPath() string {
	return domainPath
}

func GetVersionPackagePath() string {
	return versionManager.GetCurrentPackagePath()
}

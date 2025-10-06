package storage

import "chain/runtime"

func GetDataKeys(namespace string) ([]string, error) {
	namespaceStore, err := GetNamespace()
	if err != nil {
		return nil, err
	}

	return namespaceStore.GetAllKeys()
}

func HasData(key string) bool {
	namespaceStore, err := GetNamespace()
	if err != nil {
		return false
	}

	return namespaceStore.Has(key)
}

func GetData(key string) (any, error) {
	namespaceStore, err := GetNamespace()
	if err != nil {
		return nil, err
	}

	caller := runtime.PreviousRealm().Address()
	data, err := namespaceStore.Get(key, caller)
	if err != nil {
		return nil, err
	}

	return data, nil
}

func SetData(key string, value any) error {
	namespaceStore, err := GetNamespace()
	if err != nil {
		return err
	}

	caller := runtime.PreviousRealm().Address()

	return namespaceStore.Set(key, value, caller)
}

func DeleteData(key string) error {
	namespaceStore, err := GetNamespace()
	if err != nil {
		return err
	}

	caller := runtime.PreviousRealm().Address()

	return namespaceStore.Delete(key, caller)
}

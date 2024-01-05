package main

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
)

func getMd5(input string) string {
	hashBytes := md5.Sum([]byte(input))
	return hex.EncodeToString(
		hashBytes[:],
	)
}

func convertToType[T comparable](input interface{}) (output T, err error) {
	inputBytes, err := json.Marshal(input)
	if err != nil {
		return
	}
	err = json.Unmarshal(inputBytes, &output)
	return
}

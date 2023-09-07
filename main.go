package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
)

// https://github.com/onflow/flow-go-sdk#querying-blocks

func main() {
	err := InitializeFlow("localhost:3569")
	if err != nil {
		panic(err)
	}

	client, ctx := GetFlow()

	script, err := getScript("./cadence/scripts/get-nft-details.script.cdc")
	if err != nil {
		panic(err)
	}

	value, err := client.ExecuteScriptAtLatestBlock(ctx, script, nil)
	if err != nil {
		panic(err)
	}
	fmt.Println("Script Value: ", value.String())

	b, err := client.GetLatestBlock(ctx, true)
	if err != nil {
		panic(err)
	}

	data, err := json.MarshalIndent(map[string]string{
		"id":        b.ID.String(),
		"height":    fmt.Sprintf("%d", b.Height),
		"parentId":  b.ParentID.String(),
		"timestamp": b.Timestamp.String(),
	}, "", "  ")
	if err != nil {
		panic(err)
	}

	fmt.Println(string(data))
}

func getScript(filePath string) ([]byte, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	content, err := io.ReadAll(file)
	if err != nil {
		return nil, err
	}

	return content, nil
}

package main

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/onflow/flow-go-sdk/access/grpc"
)

// https://github.com/onflow/flow-go-sdk#querying-blocks

func main() {
	ctx := context.Background()

	c, err := grpc.NewClient("localhost:3569")
	if err != nil {
		panic(err)
	}
	
	script := []byte(`
		pub struct NFT {
			pub let id: Int
			init(id: Int) {
				self.id = id
			}
		}

		pub fun main(): {String:String} {
			let nft = NFT(id: 2)
			return {
				"id": nft.id.toString()
			}
		}
	`)
	value, err := c.ExecuteScriptAtLatestBlock(ctx, script, nil)
	if err != nil {
		panic(err)
	}
	fmt.Println("Script Value: ", value.String())

	b, err := c.GetLatestBlock(ctx, true)
	if err != nil {
		panic(err)
	}

	data, err := json.MarshalIndent(map[string]string{
		"id": b.ID.String(),
		"height": fmt.Sprintf("%d", b.Height),
		"parentId": b.ParentID.String(),
		"timestamp": b.Timestamp.String(),
	}, "", "  ")
	if err != nil {
		panic(err)
	}

	fmt.Println(string(data))
}

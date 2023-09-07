package main

import (
	"context"
	"sync"

	"github.com/onflow/flow-go-sdk/access/grpc"
)

var (
	ctx  context.Context
	Flow *grpc.Client
	once sync.Once
)

func InitializeFlow(host string) error {
	var err error
	once.Do(func() {
		Flow, err = grpc.NewClient(host)
		ctx = context.Background()
	})
	return err
}

func GetFlow() (*grpc.Client, context.Context) {
	return Flow, ctx
}

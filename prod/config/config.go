package main

import (
	"fmt"
	"io/ioutil"
	"os"
	"time"
)

func main() {
	if len(os.Args) < 1 {
		panic("Usage: ./config <path-to-config>")
	}
	bytes, err := ioutil.ReadFile(os.Args[1])
	if err != nil {
		panic(fmt.Sprintf("Failed to read config file: %v", err))
	}
	fmt.Printf("Started with config: %v\n", string(bytes))
	time.Sleep(time.Hour)
}

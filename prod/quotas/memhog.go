package main

import "time"

func main() {
	var total [][]int
	for i := 0; i < 10000; i++ {
		var inner []int
		for i := 0; i < 1000; i++ {
			inner = append(inner, 0)
		}
		total = append(total, inner)
	}
	time.Sleep(time.Hour)
}

// Usage:
//   extract --image PATH   print the image's sha256 and byte size

package main

import (
	"crypto/sha256"
	"encoding/hex"
	"flag"
	"fmt"
	"io"
	"os"
)

func main() {
	image := flag.String("image", "", "path to a receipt image")
	flag.Parse()

	if *image == "" {
		fmt.Fprintln(os.Stderr, "extract: --image is required")
		os.Exit(2)
	}

	sum, size, err := hashFile(*image)
	if err != nil {
		fmt.Fprintf(os.Stderr, "extract: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("sha256 %s\nbytes  %d\n", sum, size)
}

func hashFile(path string) (string, int64, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", 0, err
	}
	defer f.Close()

	h := sha256.New()
	n, err := io.Copy(h, f)
	if err != nil {
		return "", 0, err
	}
	return hex.EncodeToString(h.Sum(nil)), n, nil
}

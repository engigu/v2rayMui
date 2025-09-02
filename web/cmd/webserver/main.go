package main

import (
    "flag"
    "fmt"
    "log"
    "net/http"
    "os"
    "path/filepath"
)

func main() {
    host := flag.String("host", "127.0.0.1", "listen host")
    port := flag.Int("port", 8787, "listen port")
    flag.Parse()

    exe, _ := os.Executable()
    // Static files are copied next to the webserver binary under ./static
    staticDir := filepath.Join(filepath.Dir(exe), "static")
    if _, err := os.Stat(staticDir); err != nil {
        log.Printf("warning: static directory not found: %s", staticDir)
    }

    // Serve static frontend (shancn-vue build output placed into static/)
    fs := http.FileServer(http.Dir(staticDir))
    http.Handle("/", fs)

    addr := fmt.Sprintf("%s:%d", *host, *port)
    log.Printf("webserver listening at http://%s", addr)
    if err := http.ListenAndServe(addr, nil); err != nil {
        log.Fatalf("webserver error: %v", err)
    }
}



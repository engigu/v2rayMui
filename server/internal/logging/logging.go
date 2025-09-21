package logging

import (
	"io"
	"log"
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
	"gopkg.in/natefinch/lumberjack.v2"
)

// InitGinLogging configures Gin and standard log outputs to write
// both to stdout and a rolling file named ginserver.log under dataPath/logs.
// Log file max size is 5 MB with a few sensible defaults for rotation.
func InitGinLogging(dataPath string) error {
	logDir := dataPath
	if err := os.MkdirAll(logDir, 0755); err != nil {
		return err
	}
	lj := &lumberjack.Logger{
		Filename:   filepath.Join(logDir, "goServer.log"),
		MaxSize:    3, // megabytes
		MaxBackups: 2,
		MaxAge:     7, // days
		Compress:   true,
	}
	mw := io.MultiWriter(os.Stdout, lj)

	// Standard library logger
	log.SetOutput(mw)
	log.SetFlags(log.LstdFlags | log.Lshortfile)

	// Gin writers (access and error logs)
	gin.DefaultWriter = mw
	gin.DefaultErrorWriter = mw
	return nil
}

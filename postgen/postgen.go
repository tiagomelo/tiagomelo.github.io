package main

import (
	"fmt"
	"os"
	"strings"
	"text/template"
	"time"

	"github.com/jessevdk/go-flags"
	"github.com/pkg/errors"
)

type options struct {
	Title string `short:"t" long:"title" description:"article's title" required:"true"`
}

const headerTemplate = `---
layout: post
title:  ""
date:   {{ .Date }}
categories:
---
`

func run(title string) error {
	const (
		docsDir   = "docs"
		postsDir  = "_posts"
		imagesDir = "assets/images"
	)
	now := time.Now().UTC()
	publishedDateLayout := "2006-01-02 15:04:05 -0000"
	formattedPublishedDate := now.Format(publishedDateLayout)
	markdownDateLayout := "2006-01-02"
	formattedMarkdownDateLayout := now.Format(markdownDateLayout)
	markdownFilePath := fmt.Sprintf("%s/%s/%s-%s.markdown", docsDir, postsDir, formattedMarkdownDateLayout, title)
	markdownFile, err := os.Create(markdownFilePath)
	if err != nil {
		return errors.Wrapf(err, "writing file %s", markdownFilePath)
	}
	fmt.Printf("markdownFilePath: %v\n", markdownFilePath)
	tmpl, err := template.New("header").Parse(headerTemplate)
	if err != nil {
		return errors.Wrap(err, "parsing template")
	}
	if err := tmpl.Execute(markdownFile, map[string]string{"Date": formattedPublishedDate}); err != nil {
		return errors.Wrap(err, "executing template")
	}
	imagesFolderPath := fmt.Sprintf("%s/%s/%s-%s", docsDir, imagesDir, formattedMarkdownDateLayout, title)
	if err := os.Mkdir(imagesFolderPath, os.ModePerm); err != nil {
		return errors.Wrapf(err, "creating folder %s", imagesFolderPath)
	}
	fmt.Printf("imagesFolderPath: %v\n", imagesFolderPath)
	return nil
}

func main() {
	var opts options
	parser := flags.NewParser(&opts, flags.Default)
	if _, err := parser.Parse(); err != nil {
		switch flagsErr := err.(type) {
		case flags.ErrorType:
			if flagsErr == flags.ErrHelp {
				fmt.Println(err)
				os.Exit(0)
			}
			fmt.Println(err)
			os.Exit(1)
		default:
			os.Exit(1)
		}
	}
	if containsSpace(opts.Title) {
		fmt.Printf("title \"%s\" contains space(s)\n", opts.Title)
		os.Exit(1)
	}
	if err := run(opts.Title); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

func containsSpace(s string) bool {
	return strings.Contains(s, " ")
}

#!/bin/bash

Rscript -e "bookdown::render_book(input = 'index.Rmd', output_format = 'bookdown::gitbook')"
Rscript -e "utils::browseURL(url = 'docs/index.html')"

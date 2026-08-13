#!/usr/bin/env Rscript

# Quarto 1.4 on Windows writes backslashes into alias redirect targets.
# Normalize them so committed docs/ output also works when served directly.
project_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
for (relative_path in c("docs/column.html", "docs/colmn.html")) {
  path <- file.path(project_dir, relative_path)
  if (!file.exists(path)) next
  text <- paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  normalized <- gsub("column\\\\index.html", "column/index.html", text, fixed = TRUE)
  writeLines(normalized, path, useBytes = TRUE)
}

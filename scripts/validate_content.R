#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(yaml))

project_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
abort <- function(...) stop(sprintf(...), call. = FALSE)
assert <- function(condition, ...) if (!isTRUE(condition)) abort(...)
read_text <- function(path) paste(readLines(file.path(project_dir, path), encoding = "UTF-8", warn = FALSE), collapse = "\n")

required_outputs <- c(
  "docs/index.html",
  "docs/research.html",
  "docs/background.html",
  "docs/teaching.html",
  "docs/ja/index.html",
  "docs/ja/research.html",
  "docs/ja/background.html",
  "docs/ja/teaching.html",
  "docs/column/index.html",
  "docs/column/index.xml",
  "docs/CV/cv_202409.pdf"
)
missing_outputs <- required_outputs[!file.exists(file.path(project_dir, required_outputs))]
assert(!length(missing_outputs), "Missing rendered outputs: %s", paste(missing_outputs, collapse = ", "))

news_en <- yaml.load_file(file.path(project_dir, "generated/listings/news-en.yml"))
news_ja <- yaml.load_file(file.path(project_dir, "generated/listings/news-ja.yml"))
assert(length(news_en) == length(news_ja), "English and Japanese news counts differ")
news_dates <- vapply(news_en, function(x) as.character(x$date), character(1))
assert(identical(news_dates, sort(news_dates, decreasing = TRUE)), "News is not sorted date-descending")

research_en <- yaml.load_file(file.path(project_dir, "generated/listings/research-en.yml"))
expected_counts <- c(publication = 8L, preprint = 5L, conference = 5L, other = 1L, software = 2L)
actual_counts <- table(vapply(research_en, function(x) as.character(x$section), character(1)))
for (section in names(expected_counts)) {
  assert(as.integer(actual_counts[[section]]) == expected_counts[[section]], "Unexpected %s count", section)
}

home_en <- read_text("docs/index.html")
home_ja <- read_text("docs/ja/index.html")
research_html_en <- read_text("docs/research.html")
research_html_ja <- read_text("docs/ja/research.html")
background_en <- read_text("docs/background.html")
background_ja <- read_text("docs/ja/background.html")
teaching_en <- read_text("docs/teaching.html")
teaching_ja <- read_text("docs/ja/teaching.html")

count_fixed <- function(text, pattern) lengths(regmatches(text, gregexpr(pattern, text, fixed = TRUE)))
assert(count_fixed(home_en, 'class="news-entry"') == 10L, "English Home must show 10 news items")
assert(count_fixed(home_ja, 'class="news-entry"') == 10L, "Japanese Home must show 10 news items")
assert(grepl("2506.15913", research_html_en, fixed = TRUE), "Correct Statistics in Medicine arXiv link is missing")
assert(grepl("\u63a1\u629e\u30fb\u51fa\u7248\u6e08\u307f\u8ad6\u6587", research_html_ja, fixed = TRUE), "Japanese Research heading is missing")
assert(grepl("Assistant Professor", background_en, fixed = TRUE), "English employment is missing")
assert(grepl("\u535a\u58eb", background_ja, fixed = TRUE), "Japanese education is missing")
assert(grepl("Statistics Fundamentals", teaching_en, fixed = TRUE), "English teaching item is missing")
assert(grepl("\u7d71\u8a08\u57fa\u790e", teaching_ja, fixed = TRUE), "Japanese teaching item is missing")

column_sources <- list.files(file.path(project_dir, "column"), pattern = "\\.qmd$", full.names = TRUE)
column_outputs <- list.files(file.path(project_dir, "docs/column"), pattern = "\\.html$", full.names = TRUE)
assert(length(column_sources) == length(column_outputs), "Column source/output count differs")
assert(file.exists(file.path(project_dir, "docs/column.html")), "Legacy /column.html redirect is missing")
assert(file.exists(file.path(project_dir, "docs/colmn.html")), "Legacy /colmn.html redirect is missing")
for (redirect_path in c("docs/column.html", "docs/colmn.html")) {
  redirect <- read_text(redirect_path)
  assert(grepl("column/index.html", redirect, fixed = TRUE), "Legacy redirect target is invalid: %s", redirect_path)
  assert(!grepl("column\\\\index.html", redirect, fixed = TRUE), "Legacy redirect contains a backslash: %s", redirect_path)
}

pdf_path <- file.path(project_dir, "docs/CV/cv_202409.pdf")
assert(file.info(pdf_path)$size > 30000, "Generated CV PDF is unexpectedly small")
signature <- rawToChar(readBin(pdf_path, what = "raw", n = 5L))
assert(signature == "%PDF-", "Generated CV is not a PDF")

cv <- read_text("CV/cv.qmd")
for (heading in c("Working Experience", "Education", "Grants and Funding", "Awards", "Teaching Experience", "Academic Service", "Peer-Reviewed Methodological Articles", "Clinical Research", "Submitted Manuscripts / Preprints", "Talks at International Conferences", "Software")) {
  assert(grepl(heading, cv, fixed = TRUE), "CV section missing: %s", heading)
}

message("Content validation passed.")

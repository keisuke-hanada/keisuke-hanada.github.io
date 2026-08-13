#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(yaml))

project_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
abort <- function(...) stop(sprintf(...), call. = FALSE)
assert <- function(condition, ...) if (!isTRUE(condition)) abort(...)
read_text <- function(path) paste(readLines(file.path(project_dir, path), encoding = "UTF-8", warn = FALSE), collapse = "\n")
scalar <- function(x, default = "") if (is.null(x) || !length(x) || is.na(x[[1]])) default else as.character(x[[1]])
`%||%` <- function(x, y) if (is.null(x)) y else x

read_qmd_metadata <- function(path) {
  lines <- readLines(path, encoding = "UTF-8", warn = FALSE)
  closing <- which(trimws(lines[-1]) == "---")[1] + 1L
  assert(length(lines) >= 3L && trimws(lines[[1]]) == "---" && !is.na(closing), "Invalid front matter: %s", path)
  yaml.load(paste(lines[2:(closing - 1L)], collapse = "\n"))
}

read_content <- function(dir) {
  paths <- sort(list.files(file.path(project_dir, dir), pattern = "\\.qmd$", full.names = TRUE))
  lapply(paths, read_qmd_metadata)
}

has_channel <- function(item, channel) channel %in% unlist(item$channels %||% character())
research_section <- function(item) {
  kind <- scalar(item$kind)
  if (kind == "publication" && scalar(item$category) == "clinical") return("medical")
  if (kind == "publication") return("publication")
  if (kind == "preprint") return("preprint")
  if (kind == "conference") return(paste0("conference-", scalar(item$scope)))
  if (kind == "software") return("software")
  "other"
}

profile <- yaml.load_file(file.path(project_dir, "content/data/profile.yml"))
cv_href <- scalar(profile$cv)
assert(grepl("^/CV/[^/]+[.]pdf$", cv_href), "profile.cv must be an absolute /CV/*.pdf path")
cv_output <- file.path("docs", sub("^/", "", cv_href))

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
  "docs/search.json",
  "docs/sitemap.xml",
  cv_output
)
missing_outputs <- required_outputs[!file.exists(file.path(project_dir, required_outputs))]
assert(!length(missing_outputs), "Missing rendered outputs: %s", paste(missing_outputs, collapse = ", "))
assert(!file.exists(file.path(project_dir, "tools.qmd")), "Removed Tools source page still exists")
assert(!file.exists(file.path(project_dir, "docs/tools.html")), "Removed Tools output page still exists")

news_en <- yaml.load_file(file.path(project_dir, "generated/listings/news-en.yml"))
news_ja <- yaml.load_file(file.path(project_dir, "generated/listings/news-ja.yml"))
assert(length(news_en) == length(news_ja), "English and Japanese news counts differ")
news_dates <- vapply(news_en, function(x) as.character(x$date), character(1))
assert(identical(news_dates, sort(news_dates, decreasing = TRUE)), "News is not sorted date-descending")

research_en <- yaml.load_file(file.path(project_dir, "generated/listings/research-en.yml"))
research_ja <- yaml.load_file(file.path(project_dir, "generated/listings/research-ja.yml"))
all_content <- c(read_content("content/research"), read_content("content/talks"), read_content("content/software"))
source_research <- Filter(function(x) has_channel(x, "research"), all_content)
section_levels <- c("publication", "medical", "preprint", "conference-international", "conference-domestic", "other", "software")
expected_counts <- table(factor(vapply(source_research, research_section, character(1)), levels = section_levels))
actual_counts_en <- table(factor(vapply(research_en, function(x) scalar(x$section), character(1)), levels = section_levels))
actual_counts_ja <- table(factor(vapply(research_ja, function(x) scalar(x$section), character(1)), levels = section_levels))
assert(identical(as.integer(actual_counts_en), as.integer(expected_counts)), "English Research listing counts do not match source metadata")
assert(identical(as.integer(actual_counts_ja), as.integer(expected_counts)), "Japanese Research listing counts do not match source metadata")
source_ids <- sort(vapply(source_research, function(x) scalar(x$id), character(1)))
assert(identical(sort(vapply(research_en, function(x) scalar(x$id), character(1))), source_ids), "English Research listing IDs do not match source metadata")
assert(identical(sort(vapply(research_ja, function(x) scalar(x$id), character(1))), source_ids), "Japanese Research listing IDs do not match source metadata")
domestic <- Filter(function(x) as.character(x$section) == "conference-domestic", research_en)
domestic_dates <- vapply(domestic, function(x) as.character(x$date), character(1))
assert(identical(domestic_dates, sort(domestic_dates, decreasing = TRUE)), "Domestic presentations are not sorted date-descending")

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
assert(grepl('<div class="news-entry"[^>]*>[[:space:]]*<time class="listing-date"', home_en, perl = TRUE), "English news date and title must be direct grid children")
assert(grepl('<div class="news-entry"[^>]*>[[:space:]]*<time class="listing-date"', home_ja, perl = TRUE), "Japanese news date and title must be direct grid children")
assert(grepl("2506.15913", research_html_en, fixed = TRUE), "Correct Statistics in Medicine arXiv link is missing")
assert(grepl("10.1111/den.70229", research_html_en, fixed = TRUE), "Specified Digestive Endoscopy paper DOI is missing")
assert(grepl("Impact of Stent Type on Surgical Outcomes", research_html_ja, fixed = TRUE), "English medical-paper title is missing from Japanese Research")
assert(grepl("\u63a1\u629e\u30fb\u51fa\u7248\u6e08\u307f\u8ad6\u6587", research_html_ja, fixed = TRUE), "Japanese Research heading is missing")
assert(grepl("Medical Research", research_html_en, fixed = TRUE), "English Medical Research heading is missing")
assert(grepl("Medical Research", research_html_ja, fixed = TRUE), "Japanese Medical Research heading is missing")
assert(grepl("Conference Presentations (JPN Domestic)", research_html_en, fixed = TRUE), "English domestic-presentation heading is missing")
assert(grepl("\u5b66\u4f1a\u767a\u8868\uff08\u56fd\u5185\u5b66\u4f1a\u30fb\u7814\u7a76\u4f1a\uff09", research_html_ja, fixed = TRUE), "Japanese domestic-presentation heading is missing")
assert(grepl("Kaplan-Meier\u66f2\u7dda\u56f3\u306e\u7d71\u5408\u306b\u3088\u308b\u751f\u5b58\u6642\u9593\u30e1\u30bf\u30a2\u30ca\u30ea\u30b7\u30b9", research_html_ja, fixed = TRUE), "Domestic presentation is missing from Japanese Research")
assert(grepl("Clear Cell Papillary Renal Cell Tumor Revisited", research_html_ja, fixed = TRUE), "English medical-paper title must remain English on Japanese Research")
assert(!grepl("\u6de1\u660e\u7d30\u80de\u4e73\u982d\u72b6\u814e\u7d30\u80de\u816b\u306e\u518d\u691c\u8a0e", research_html_ja, fixed = TRUE), "English medical-paper title was translated on Japanese Research")
assert(grepl("\u30a4\u30d9\u30f3\u30c8\u6642\u9593\u30a2\u30a6\u30c8\u30ab\u30e0\u306b\u5bfe\u3059\u308b\u500b\u4eba\u30c7\u30fc\u30bf\u5fa9\u5143", research_html_ja, fixed = TRUE), "Japanese-language paper title is missing from Japanese Research")
assert(grepl("Random-effects meta-analysis via generalized linear mixed models", research_html_ja, fixed = TRUE), "English methodological title must remain English on Japanese Research")
assert(grepl("Assistant Professor", background_en, fixed = TRUE), "English employment is missing")
assert(grepl("\u535a\u58eb", background_ja, fixed = TRUE), "Japanese education is missing")
assert(grepl("Statistics Fundamentals", teaching_en, fixed = TRUE), "English teaching item is missing")
assert(grepl("\u7d71\u8a08\u57fa\u790e", teaching_ja, fixed = TRUE), "Japanese teaching item is missing")
for (url in c(scalar(profile$`google-scholar`), scalar(profile$researchmap), cv_href)) {
  rendered_url <- gsub("&", "&amp;", url, fixed = TRUE)
  if (startsWith(rendered_url, "/")) rendered_url <- substring(rendered_url, 2L)
  rendered_en <- gsub("\\", "/", paste(home_en, research_html_en), fixed = TRUE)
  rendered_ja <- gsub("\\", "/", paste(home_ja, research_html_ja), fixed = TRUE)
  assert(url != "" && grepl(rendered_url, rendered_en, fixed = TRUE), "Profile URL is missing from rendered English pages: %s", url)
  assert(grepl(rendered_url, rendered_ja, fixed = TRUE), "Profile URL is missing from rendered Japanese pages: %s", url)
}

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
historical_news <- read_text("docs/column/20260113-news-before-2026.html")
for (resource in c("IASC-ARS2025-oral.pdf", "JSM2025-poster.pdf")) {
  assert(grepl(paste0("../files/", resource), historical_news, fixed = TRUE), "Column resource link is invalid: %s", resource)
  assert(file.exists(file.path(project_dir, "docs/files", resource)), "Column resource is missing: %s", resource)
}

unwanted_cv_outputs <- c("docs/CV/cv_202409.pdf", "docs/CV/cv_202409.pdf.html", paste0(cv_output, ".html"))
assert(!any(file.exists(file.path(project_dir, unwanted_cv_outputs))), "Legacy or HTML CV output must not exist")
search_and_sitemap <- paste(read_text("docs/search.json"), read_text("docs/sitemap.xml"))
assert(!grepl("tools.html", search_and_sitemap, fixed = TRUE), "Removed Tools URL remains in search index or sitemap")
assert(!grepl("cv_202409", search_and_sitemap, fixed = TRUE), "Legacy CV URL remains in search index or sitemap")
assert(!grepl(paste0(basename(cv_output), ".html"), search_and_sitemap, fixed = TRUE), "HTML CV URL remains in search index or sitemap")

rendered_html_paths <- list.files(file.path(project_dir, "docs"), pattern = "\\.html$", recursive = TRUE, full.names = TRUE)
for (path in rendered_html_paths) {
  html <- paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  assert(!grepl('href="[^\"]*tools[.]html"', html, perl = TRUE), "Removed Tools navbar link remains in %s", path)
}

pdf_path <- file.path(project_dir, cv_output)
assert(file.info(pdf_path)$size > 30000, "Generated CV PDF is unexpectedly small")
signature <- rawToChar(readBin(pdf_path, what = "raw", n = 5L))
assert(signature == "%PDF-", "Generated CV is not a PDF")

cv <- read_text("CV/cv.qmd")
for (heading in c("Working Experience", "Education", "Grants and Funding", "Awards", "Teaching Experience", "Academic Service", "Peer-Reviewed Methodological Articles", "Clinical Research", "Submitted Manuscripts / Preprints", "Conference Presentations (International)", "Conference Presentations (JPN Domestic)", "Software")) {
  assert(grepl(heading, cv, fixed = TRUE), "CV section missing: %s", heading)
}

message("Content validation passed.")

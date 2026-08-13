#!/usr/bin/env Rscript

run_test <- function() {
  project_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  fixture <- file.path(project_dir, "content/research/__single-source-test.qmd")
  render_targets <- c("index.qmd", "research.qmd", "ja/index.qmd", "ja/research.qmd", "CV/cv.qmd")

  run <- function(command, args) {
    output <- system2(command, args, stdout = TRUE, stderr = TRUE)
    status <- attr(output, "status")
    if (!is.null(status) && status != 0L) stop(paste(output, collapse = "\n"), call. = FALSE)
    invisible(output)
  }

  render <- function() {
    for (target in render_targets) run("quarto", c("render", target))
  }

  cleanup <- function() {
    if (file.exists(fixture)) unlink(fixture)
    run("Rscript", "scripts/build_content.R")
    render()
  }
  on.exit(cleanup(), add = TRUE)

  baseline_pdf <- unname(tools::md5sum(file.path(project_dir, "docs/CV/cv_202409.pdf")))

  fixture_lines <- c(
  "---",
  "id: single-source-test",
  "record-type: research",
  "kind: publication",
  "status: accepted",
  "category: methodological",
  "date: 2099-12-31",
  "year: 2099",
  "title-en: Single Source Integration Test",
  "title-ja: Single Source Integration Test JA",
  "authors-en: '{self}'",
  "publication-en: Test Journal, accepted",
  "publication-ja: Test Journal, accepted",
  "description-en: Temporary integration fixture.",
  "description-ja: Temporary integration fixture JA.",
  "channels: [research, cv]",
  "news:",
  "  - date: 2099-12-31",
  "    en: Single source test news.",
  "    ja: Single source test news JA.",
  "---",
  ""
  )
  writeLines(fixture_lines, fixture, useBytes = TRUE)

  run("Rscript", "scripts/build_content.R")
  render()

  targets <- c(
    "generated/listings/research-en.yml" = "Single Source Integration Test",
    "generated/listings/research-ja.yml" = "Single Source Integration Test JA",
    "generated/listings/news-en.yml" = "Single source test news.",
    "generated/listings/news-ja.yml" = "Single source test news JA.",
    "CV/cv.qmd" = "Single Source Integration Test",
    "docs/index.html" = "Single source test news.",
    "docs/ja/index.html" = "Single source test news JA.",
    "docs/research.html" = "Single Source Integration Test",
    "docs/ja/research.html" = "Single Source Integration Test JA"
  )
  for (target in names(targets)) {
    text <- paste(readLines(file.path(project_dir, target), encoding = "UTF-8", warn = FALSE), collapse = "\n")
    if (!grepl(targets[[target]], text, fixed = TRUE)) stop(sprintf("Fixture missing from %s", target), call. = FALSE)
  }

  fixture_pdf <- unname(tools::md5sum(file.path(project_dir, "docs/CV/cv_202409.pdf")))
  if (identical(baseline_pdf, fixture_pdf)) stop("Fixture did not change the rendered CV PDF", call. = FALSE)

  message("Single-source integration test passed; temporary item will be removed.")
}

run_test()

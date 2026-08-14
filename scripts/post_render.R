#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(yaml))

project_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
`%||%` <- function(x, y) if (is.null(x)) y else x

# Quarto 1.4 on Windows writes backslashes into alias redirect targets.
# Normalize them so committed docs/ output also works when served directly.
for (relative_path in c("docs/column.html", "docs/colmn.html")) {
  path <- file.path(project_dir, relative_path)
  if (!file.exists(path)) next
  text <- paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  normalized <- gsub("column\\\\index.html", "column/index.html", text, fixed = TRUE)
  writeLines(normalized, path, useBytes = TRUE)
}

# Quarto 1.4 cannot use external/custom href values as RSS GUIDs for YAML
# listing items. Build the unified feed from the same generated listing data so
# each item retains its canonical URL and stable GUID.
updates_path <- file.path(project_dir, "generated/listings/updates.yml")
feed_path <- file.path(project_dir, "docs/updates.xml")
if (file.exists(updates_path)) {
  updates <- yaml.load_file(updates_path)
  project <- yaml.load_file(file.path(project_dir, "_quarto.yml"))
  site_url <- sub("/$", "", as.character(project$website$`site-url`[[1]]))
  feed_items <- head(updates, 50L)

  escape_xml <- function(x) {
    x <- gsub("&", "&amp;", as.character(x), fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x <- gsub('"', "&quot;", x, fixed = TRUE)
    gsub("'", "&apos;", x, fixed = TRUE)
  }
  scalar <- function(x, default = "") {
    if (is.null(x) || !length(x) || is.na(x[[1]])) default else as.character(x[[1]])
  }
  absolute_url <- function(href) {
    if (grepl("^https?://", href)) href else paste0(site_url, if (startsWith(href, "/")) href else paste0("/", href))
  }
  rss_date <- function(value) {
    date <- as.Date(value)
    weekdays <- c("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
    months <- c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
    parts <- as.POSIXlt(date, tz = "UTC")
    sprintf("%s, %02d %s %04d 00:00:00 GMT", weekdays[[parts$wday + 1L]], parts$mday, months[[parts$mon + 1L]], parts$year + 1900L)
  }

  item_xml <- unlist(lapply(feed_items, function(item) {
    href <- escape_xml(absolute_url(scalar(item$href)))
    categories <- unlist(item$categories %||% character())
    c(
      "<item>",
      sprintf("  <title>%s</title>", escape_xml(scalar(item$title))),
      sprintf("  <link>%s</link>", href),
      sprintf("  <description>%s</description>", escape_xml(scalar(item$description, scalar(item$title)))),
      vapply(categories, function(category) sprintf("  <category>%s</category>", escape_xml(category)), character(1)),
      sprintf("  <guid isPermaLink=\"true\">%s</guid>", href),
      sprintf("  <pubDate>%s</pubDate>", rss_date(scalar(item$date))),
      "</item>"
    )
  }))

  last_build_date <- if (length(feed_items)) rss_date(scalar(feed_items[[1]]$date)) else rss_date(Sys.Date())
  feed <- c(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<rss xmlns:atom="http://www.w3.org/2005/Atom" version="2.0">',
    "<channel>",
    "<title>Keisuke Hanada - Site Updates</title>",
    sprintf("<link>%s/updates.html</link>", escape_xml(site_url)),
    sprintf('<atom:link href="%s/updates.xml" rel="self" type="application/rss+xml"/>', escape_xml(site_url)),
    "<description>Research, professional activities, and columns by Keisuke Hanada</description>",
    "<language>en</language>",
    "<generator>Quarto with scripts/post_render.R</generator>",
    sprintf("<lastBuildDate>%s</lastBuildDate>", last_build_date),
    item_xml,
    "</channel>",
    "</rss>"
  )
  writeLines(feed, feed_path, useBytes = TRUE)
}

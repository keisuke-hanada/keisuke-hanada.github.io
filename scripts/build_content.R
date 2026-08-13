#!/usr/bin/env Rscript

suppressPackageStartupMessages(library(yaml))

project_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
generated_dir <- file.path(project_dir, "generated")
listing_dir <- file.path(generated_dir, "listings")
dir.create(listing_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(project_dir, "CV"), recursive = TRUE, showWarnings = FALSE)

abort <- function(...) stop(sprintf(...), call. = FALSE)

read_qmd_metadata <- function(path) {
  lines <- readLines(path, encoding = "UTF-8", warn = FALSE)
  if (length(lines) < 3L || trimws(lines[[1]]) != "---") {
    abort("Missing YAML front matter: %s", path)
  }
  closing <- which(trimws(lines[-1]) == "---")[1] + 1L
  if (is.na(closing)) abort("Unclosed YAML front matter: %s", path)
  meta <- yaml.load(paste(lines[2:(closing - 1L)], collapse = "\n"))
  meta$.source <- sub(paste0("^", project_dir, "/?"), "", normalizePath(path, winslash = "/"))
  meta
}

read_content <- function(dir) {
  paths <- sort(list.files(file.path(project_dir, dir), pattern = "\\.qmd$", full.names = TRUE))
  lapply(paths, read_qmd_metadata)
}

scalar <- function(x, default = "") {
  if (is.null(x) || length(x) == 0L || is.na(x[[1]])) default else as.character(x[[1]])
}

has_channel <- function(item, channel) channel %in% unlist(item$channels %||% character())
`%||%` <- function(x, y) if (is.null(x)) y else x

escape_html <- function(x) {
  x <- scalar(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

inline_markdown_html <- function(x) {
  x <- escape_html(x)
  gsub("\\*([^*]+)\\*", "<em>\\1</em>", x, perl = TRUE)
}

localized <- function(item, field, lang, fallback = TRUE) {
  localized_name <- paste0(field, "-", lang)
  value <- item[[localized_name]]
  if ((is.null(value) || length(value) == 0L) && fallback) value <- item[[paste0(field, "-en")]]
  scalar(value)
}

# Research titles and descriptions follow the language of the work. On the
# Japanese page, only works written or presented in Japanese use Japanese
# metadata; English-language works retain their original English wording.
research_display_language <- function(item, page_lang) {
  if (page_lang == "ja" && scalar(item$language) == "ja") "ja" else "en"
}

sort_date <- function(item) {
  value <- scalar(item$date, paste0(scalar(item$year, "0000"), "-01-01"))
  suppressWarnings(as.Date(value))
}

ordered_items <- function(items) {
  if (!length(items)) return(items)
  explicit <- vapply(items, function(x) suppressWarnings(as.numeric(scalar(x$order, NA_character_))), numeric(1))
  dates <- vapply(items, function(x) as.numeric(sort_date(x)), numeric(1))
  items[order(is.na(explicit), explicit, -dates, na.last = TRUE)]
}

validate_items <- function(items) {
  allowed_records <- c("research", "talk", "software")
  allowed_kinds <- c("publication", "preprint", "thesis", "conference", "software")
  ids <- vapply(items, function(x) scalar(x$id), character(1))
  if (any(ids == "")) abort("Every content item must define id")
  duplicate_ids <- unique(ids[duplicated(ids)])
  if (length(duplicate_ids)) abort("Duplicate ids: %s", paste(duplicate_ids, collapse = ", "))
  for (item in items) {
    source <- scalar(item$.source)
    if (!scalar(item$`record-type`) %in% allowed_records) abort("Invalid record-type in %s", source)
    if (!scalar(item$kind) %in% allowed_kinds) abort("Invalid kind in %s", source)
    for (field in c("status", "date", "year", "language", "title-en", "authors-en", "publication-en")) {
      if (scalar(item[[field]]) == "") abort("Missing %s in %s", field, source)
    }
    if (!scalar(item$language) %in% c("en", "ja")) abort("Invalid language in %s", source)
    if (scalar(item$language) == "ja" && scalar(item$`title-ja`) == "") abort("Missing title-ja for Japanese-language work in %s", source)
    if (scalar(item$kind) == "conference") {
      if (!scalar(item$scope) %in% c("international", "domestic")) abort("Invalid or missing conference scope in %s", source)
      if (!scalar(item$`presentation-type`) %in% c("oral", "poster", "symposium", "unspecified")) abort("Invalid or missing presentation-type in %s", source)
    }
    channels <- unlist(item$channels %||% character())
    invalid_channels <- setdiff(channels, c("research", "cv", "teaching", "background"))
    if (length(invalid_channels)) abort("Invalid channels in %s: %s", source, paste(invalid_channels, collapse = ", "))
    if (!is.null(item$news)) {
      for (event in item$news) {
        for (field in c("date", "en", "ja")) {
          if (scalar(event[[field]]) == "") abort("Missing news.%s in %s", field, source)
        }
      }
    }
  }
  invisible(TRUE)
}

link_html <- function(item, lang) {
  links <- item$links %||% list()
  labels <- if (lang == "ja") {
    c(paper = "\u8ad6\u6587", doi = "DOI", arxiv = "arXiv", github = "GitHub", cran = "CRAN", event = "\u5927\u4f1a\u30b5\u30a4\u30c8", oral = "\u767a\u8868\u8cc7\u6599", poster = "\u30dd\u30b9\u30bf\u30fc")
  } else {
    c(paper = "paper", doi = "DOI", arxiv = "arXiv", github = "GitHub", cran = "CRAN", event = "event", oral = "oral", poster = "poster")
  }
  rendered <- character()
  for (name in names(labels)) {
    href <- scalar(links[[name]])
    if (href != "") rendered <- c(rendered, sprintf('<a href="%s">%s</a>', escape_html(href), labels[[name]]))
  }
  if (!length(rendered)) return("")
  sprintf('<span class="research-links">[%s]</span>', paste(rendered, collapse = ", "))
}

citation_html <- function(item, lang) {
  authors <- localized(item, "authors", lang)
  if (lang == "ja" && !is.null(item$`authors-ja`)) {
    authors <- gsub("{self-ja}", "<u>\u82b1\u7530 \u572d\u4f51</u>", escape_html(authors), fixed = TRUE)
  } else {
    authors <- gsub("{self}", "<u>Hanada, K.</u>", escape_html(authors), fixed = TRUE)
  }
  title <- escape_html(localized(item, "title", lang))
  publication <- inline_markdown_html(localized(item, "publication", lang))
  year <- escape_html(scalar(item$`year-display`, item$year))
  sprintf("%s (%s). %s. %s.", authors, year, title, publication)
}

research_section <- function(item) {
  kind <- scalar(item$kind)
  if (kind == "publication" && scalar(item$category) == "clinical") return("medical")
  if (kind == "publication") return("publication")
  if (kind == "preprint") return("preprint")
  if (kind == "conference") return(paste0("conference-", scalar(item$scope)))
  if (kind == "software") return("software")
  "other"
}

research <- read_content("content/research")
talks <- read_content("content/talks")
software <- read_content("content/software")
all_content <- c(research, talks, software)
validate_items(all_content)
activities <- yaml.load_file(file.path(project_dir, "content/data/activities.yml"))$items

make_research_listing <- function(lang) {
  selected <- Filter(function(x) has_channel(x, "research"), all_content)
  sections <- vapply(selected, research_section, character(1))
  result <- list()
  for (section in c("publication", "medical", "preprint", "conference-international", "conference-domestic", "other", "software")) {
    group <- selected[sections == section]
    if (!length(group)) next
    group <- ordered_items(group)
    total <- length(group)
    for (i in seq_along(group)) {
      item <- group[[i]]
      display_lang <- research_display_language(item, lang)
      result[[length(result) + 1L]] <- list(
        id = scalar(item$id),
        title = localized(item, "title", display_lang),
        section = section,
        date = scalar(item$date),
        order = i,
        `display-number` = total - i + 1L,
        `citation-html` = citation_html(item, display_lang),
        `description-html` = escape_html(localized(item, "description", display_lang)),
        `links-html` = link_html(item, lang)
      )
    }
  }
  result
}

make_news_listing <- function(lang) {
  events <- list()
  for (item in all_content) {
    if (is.null(item$news)) next
    for (event in item$news) {
      events[[length(events) + 1L]] <- list(
        id = paste(scalar(item$id), scalar(event$date), sep = "-"),
        title = scalar(event[[lang]]),
        date = scalar(event$date),
        href = scalar(event$href)
      )
    }
  }
  for (item in activities) {
    if (is.null(item$news)) next
    for (event in item$news) {
      events[[length(events) + 1L]] <- list(
        id = paste(scalar(item$id), scalar(event$date), sep = "-"),
        title = scalar(event[[lang]]),
        date = scalar(event$date),
        href = scalar(event$href)
      )
    }
  }
  dates <- vapply(events, function(x) as.numeric(as.Date(x$date)), numeric(1))
  events[order(dates, decreasing = TRUE)]
}

make_activity_listing <- function(lang) {
  selected <- Filter(function(x) any(c("background", "teaching") %in% unlist(x$channels %||% character())), activities)
  result <- list()
  types <- c(employment = "employment", education = "education", teaching = "teaching")
  for (section in names(types)) {
    group <- Filter(function(x) scalar(x$type) == types[[section]], selected)
    values <- vapply(group, function(x) scalar(x$start), character(1))
    group <- group[order(values, decreasing = TRUE)]
    for (i in seq_along(group)) {
      item <- group[[i]]
      result[[length(result) + 1L]] <- list(
        id = scalar(item$id),
        title = localized(item, "title", lang),
        details = localized(item, "details", lang),
        period = localized(item, "period", lang),
        section = section,
        order = i
      )
    }
  }
  result
}

write_yaml(make_research_listing("en"), file.path(listing_dir, "research-en.yml"), handlers = list(date = function(x) format(x, "%Y-%m-%d")))
write_yaml(make_research_listing("ja"), file.path(listing_dir, "research-ja.yml"), handlers = list(date = function(x) format(x, "%Y-%m-%d")))
write_yaml(make_news_listing("en"), file.path(listing_dir, "news-en.yml"), handlers = list(date = function(x) format(x, "%Y-%m-%d")))
write_yaml(make_news_listing("ja"), file.path(listing_dir, "news-ja.yml"), handlers = list(date = function(x) format(x, "%Y-%m-%d")))
write_yaml(make_activity_listing("en"), file.path(listing_dir, "activities-en.yml"))
write_yaml(make_activity_listing("ja"), file.path(listing_dir, "activities-ja.yml"))

profile <- yaml.load_file(file.path(project_dir, "content/data/profile.yml"))
for (field in c("google-scholar", "researchmap", "cv")) {
  if (scalar(profile[[field]]) == "") abort("profile.yml must define %s", field)
}
cv_href <- scalar(profile$cv)
if (!grepl("^/CV/[^/]+[.]pdf$", cv_href)) abort("profile.cv must be an absolute /CV/*.pdf path")
cv_filename <- basename(cv_href)

# Remove legacy/stale CV outputs before Quarto builds its search index and
# sitemap. The CV has a PDF output only; an HTML sibling is never canonical.
obsolete_cv_outputs <- file.path(project_dir, c(
  "docs/CV/cv_202409.pdf",
  "docs/CV/cv_202409.pdf.html",
  sprintf("docs/CV/%s.html", cv_filename)
))
unlink(obsolete_cv_outputs[file.exists(obsolete_cv_outputs)])

current_jobs <- Filter(function(x) scalar(x$type) == "employment" && isTRUE(x$current), activities)
if (length(current_jobs) != 1L) abort("activities.yml must contain exactly one current employment")
current_job <- current_jobs[[1]]
education <- ordered_items(Filter(function(x) scalar(x$type) == "education", activities))
if (!length(education)) abort("activities.yml must contain at least one education item")
highest_degree <- education[[1]]
profile_en <- c(
  scalar(profile$`bio-en`), "",
  sprintf("%s, %s", scalar(highest_degree$`title-en`), scalar(highest_degree$`details-en`)), "",
  sprintf("%s, %s", scalar(current_job$`title-en`), scalar(current_job$`details-en`)), "",
  sprintf("- [Google Scholar](%s)", scalar(profile$`google-scholar`)),
  sprintf("- [researchmap](%s)", scalar(profile$researchmap)),
  sprintf("- [Curriculum Vitae](%s)", cv_href)
)
profile_ja <- c(
  scalar(profile$`bio-ja`), "",
  sprintf("%s\u3001%s", scalar(highest_degree$`title-ja`), scalar(highest_degree$`details-ja`)), "",
  sprintf("%s\u3001%s", scalar(current_job$`details-ja`), scalar(current_job$`title-ja`)), "",
  sprintf("- [Google Scholar](%s)", scalar(profile$`google-scholar`)),
  sprintf("- [researchmap](%s)", scalar(profile$researchmap)),
  sprintf("- [Curriculum Vitae](%s)", cv_href)
)
writeLines(profile_en, file.path(generated_dir, "profile-en.md"), useBytes = TRUE)
writeLines(profile_ja, file.path(generated_dir, "profile-ja.md"), useBytes = TRUE)
writeLines(scalar(profile$`interests-en`), file.path(generated_dir, "interests-en.md"), useBytes = TRUE)
writeLines(scalar(profile$`interests-ja`), file.path(generated_dir, "interests-ja.md"), useBytes = TRUE)
writeLines(
  sprintf("Please see my [Google Scholar](%s) page for a full list of publications. Here, I highlight research focusing on methodological developments in biostatistics.", scalar(profile$`google-scholar`)),
  file.path(generated_dir, "research-intro-en.md"), useBytes = TRUE
)
writeLines(
  sprintf("\u7814\u7a76\u696d\u7e3e\u5168\u4f53\u306b\u3064\u3044\u3066\u306f[Google Scholar](%s)\u3082\u3054\u89a7\u304f\u3060\u3055\u3044\u3002\u3053\u3053\u3067\u306f\u3001\u751f\u7269\u7d71\u8a08\u5b66\u306e\u65b9\u6cd5\u8ad6\u3092\u4e2d\u5fc3\u3068\u3057\u305f\u7814\u7a76\u3092\u7d39\u4ecb\u3057\u307e\u3059\u3002", scalar(profile$`google-scholar`)),
  file.path(generated_dir, "research-intro-ja.md"), useBytes = TRUE
)
writeLines(
  sprintf("Other information is available on [researchmap](%s).", scalar(profile$researchmap)),
  file.path(generated_dir, "research-outro-en.md"), useBytes = TRUE
)
writeLines(
  sprintf("\u305d\u306e\u4ed6\u306e\u60c5\u5831\u306f[researchmap](%s)\u3092\u3054\u89a7\u304f\u3060\u3055\u3044\u3002", scalar(profile$researchmap)),
  file.path(generated_dir, "research-outro-ja.md"), useBytes = TRUE
)

cv_author <- function(item) {
  gsub("{self}", "\\underline{Hanada, K.}", scalar(item$`authors-en`), fixed = TRUE)
}

cv_links <- function(item) {
  links <- item$links %||% list()
  labels <- c(paper = "paper", doi = "DOI", arxiv = "arXiv", github = "GitHub", cran = "CRAN", event = "event", oral = "oral", poster = "poster")
  rendered <- character()
  for (name in names(labels)) {
    href <- scalar(links[[name]])
    if (href != "") rendered <- c(rendered, sprintf("[%s](%s)", labels[[name]], href))
  }
  if (!length(rendered)) "" else sprintf(" [%s]", paste(rendered, collapse = ", "))
}

cv_citation <- function(item) {
  year <- scalar(item$`year-display`, item$year)
  sprintf("%s (%s). %s. %s.%s", cv_author(item), year, scalar(item$`title-en`), scalar(item$`publication-en`), cv_links(item))
}

cv_numbered <- function(items) {
  if (!length(items)) return(character())
  paste0(seq_along(items), ". ", vapply(ordered_items(items), cv_citation, character(1)))
}

cv_bullets <- function(items) {
  if (!length(items)) return(character())
  unlist(lapply(ordered_items(items), function(x) {
    details <- x$`details-en`
    if (is.list(details) || length(details) > 1L) {
      c(sprintf("- **%s** %s", scalar(x$`period-en`), scalar(x$`title-en`)), paste0("  - ", unlist(details)))
    } else {
      detail_text <- scalar(details)
      suffix <- if (detail_text == "") "" else paste0(", ", detail_text)
      sprintf("- **%s** %s%s", scalar(x$`period-en`), scalar(x$`title-en`), suffix)
    }
  }))
}

activity_type <- function(type) Filter(function(x) scalar(x$type) == type && has_channel(x, "cv"), activities)
cv_items <- Filter(function(x) has_channel(x, "cv"), all_content)
cv_research <- Filter(function(x) scalar(x$`record-type`) == "research", cv_items)
methodological <- Filter(function(x) scalar(x$kind) == "publication" && scalar(x$category) == "methodological", cv_research)
clinical <- Filter(function(x) scalar(x$kind) == "publication" && scalar(x$category) == "clinical", cv_research)
preprints <- Filter(function(x) scalar(x$kind) == "preprint", cv_research)
cv_talks <- Filter(function(x) scalar(x$`record-type`) == "talk", cv_items)
cv_talks_international <- Filter(function(x) scalar(x$scope) == "international", cv_talks)
cv_talks_domestic <- Filter(function(x) scalar(x$scope) == "domestic", cv_talks)
cv_software <- Filter(function(x) scalar(x$`record-type`) == "software", cv_items)

section <- function(title, lines) c(sprintf("## %s", title), "", lines, "")
subsection <- function(title, lines) c(sprintf("### %s", title), "", lines, "")
cv <- c(
  "---",
  'title: "Curriculum Vitae"',
  'author: "Keisuke Hanada"',
  sprintf('date: "%s"', format(Sys.Date(), "%Y-%m-%d")),
  "format:",
  "  pdf:",
  "    pdf-engine: lualatex",
  "    documentclass: article",
  "    keep-tex: false",
  "    number-sections: false",
  "    toc: false",
  "    geometry:",
  "      - margin=1in",
  '    mainfont: "TeX Gyre Termes"',
  "fontsize: 12pt",
  sprintf('output-file: "%s"', cv_filename),
  "---", "",
  section("Contact Information", c(
    sprintf("- Name: %s", scalar(profile$name)),
    sprintf("- Address: %s", scalar(current_job$`details-en`)),
    sprintf("- Email: %s", scalar(profile$email)),
    sprintf("- ORCID: [%s](https://orcid.org/%s)", scalar(profile$orcid), scalar(profile$orcid)),
    sprintf("- GitHub: [%s](%s)", scalar(profile$github), scalar(profile$github)),
    sprintf("- Website: [%s](%s)", scalar(profile$website), scalar(profile$website))
  )),
  section("Working Experience", cv_bullets(activity_type("employment"))),
  section("Education", cv_bullets(activity_type("education"))),
  section("Grants and Funding", cv_bullets(activity_type("grant"))),
  section("Awards", cv_bullets(activity_type("award"))),
  section("Teaching Experience", cv_bullets(activity_type("teaching"))),
  section("Academic Service", cv_bullets(activity_type("service"))),
  "## Research Publications", "",
  subsection("Peer-Reviewed Methodological Articles", cv_numbered(methodological)),
  subsection("Clinical Research", cv_numbered(clinical)),
  subsection("Submitted Manuscripts / Preprints", cv_numbered(preprints)),
  subsection("Conference Presentations (International)", cv_numbered(cv_talks_international)),
  subsection("Conference Presentations (JPN Domestic)", cv_numbered(cv_talks_domestic)),
  subsection("Software", cv_numbered(cv_software))
)
writeLines(c("<!-- GENERATED by scripts/build_content.R; do not edit directly. -->", cv), file.path(project_dir, "CV/cv.qmd"), useBytes = TRUE)

message(sprintf(
  "Generated listings and CV from %d research items, %d talks, %d software records, and %d activities.",
  length(research), length(talks), length(software), length(activities)
))

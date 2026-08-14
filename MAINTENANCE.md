# サイト更新手順

このサイトでは、`content/` 配下の構造化metadataを情報の正本とします。`research.qmd`、HomeのRecent news、`CV/cv.qmd`、`generated/` は直接編集しません。

## ディレクトリ

```text
content/
├─ research/       # 1 publication / preprint / thesis = 1 qmd
├─ talks/          # 1 presentation = 1 qmd
├─ software/       # 1 software package = 1 qmd
└─ data/
   ├─ profile.yml
   └─ activities.yml
```

employment、education、grant、award、teaching、academic serviceは、ファイル数を増やさず `content/data/activities.yml` でまとめて管理します。

Google Scholar、researchmap、Webサイト、CVのURLは `content/data/profile.yml` で管理します。URLを変更するときは、ページや生成スクリプトではなくこのファイルだけを編集してください。

## 新しい研究成果を追加する

`content/research/example-paper.qmd` を1ファイル追加します。英語版と日本語版を分けて作らないでください。

```yaml
---
id: example-paper
record-type: research
kind: publication             # publication / preprint / thesis
status: published             # submitted / accepted / published
category: methodological      # methodological / clinical / other
language: en                  # 成果・発表自体の言語: en / ja
date: 2026-08-13
year: 2026
order: 10                     # 同一セクションで明示順が必要な場合のみ

title-en: English title
title-ja: 日本語タイトル
authors-en: "{self}, & Coauthor, A."
authors-ja: "{self-ja}、共著者 A."
publication-en: "*Journal Name*, 12(3), 1-10"
publication-ja: "*Journal Name*, 12(3), 1-10"
description-en: English description.
description-ja: 日本語の説明。

channels: [research, cv]

links:
  paper: https://example.org/paper
  doi: https://doi.org/10.xxxx/example
  arxiv: https://arxiv.org/abs/xxxx.xxxxx
  github: https://github.com/example/repository

news:
  - date: 2026-08-13
    en: Our paper was published in Journal Name.
    ja: 論文がJournal Nameに掲載されました。
---
```

`authors-en` 内の `{self}` はWebとCVで本人を下線表示するための記号です。和文著者列を使う場合は `authors-ja` に `{self-ja}` を指定します。

通常は日付降順です。`order` を設定した項目は同一セクション内で小さい値から優先表示されるため、日付だけでは決められない順番に使用します。

## submittedからacceptedになった場合

新しいファイルは作らず、既存qmdの次の項目を更新します。

```yaml
status: accepted
date: 2026-08-13
year: 2026
year-display: 2026+       # 必要な場合のみ
publication-en: "*Journal Name*, accepted"
publication-ja: "*Journal Name*, accepted"
news:
  - date: 2026-08-13
    en: Our paper was accepted in Journal Name.
    ja: 論文がJournal Nameに採択されました。
```

過去のarXiv公開newsも残す場合は、`news` に複数の項目を保持できます。

## Research、CVへの掲載指定

`channels` で表示先を制御します。

```yaml
channels: [research, cv]  # ResearchとCV
channels: [research]      # Researchのみ
channels: [cv]            # CVのみ
channels: []              # いずれにも表示しない
```

HomeのRecent newsはbooleanではなく、`news` 配列が存在する項目を自動収集します。research、talk、software、grant等で同じ形式を使用できます。

同じ `news` 配列は統合RSS（`/updates.xml`）にも使用されます。`news` を追加してmainへpushすると、HomeのRecent newsと統合RSSが同時に更新されます。`href` は任意で、省略時は内容に応じてResearch、Background、TeachingまたはHomeへリンクします。詳細なColumn記事がある場合は、そのURLを `href` に指定してください。

## 成果自体の言語と英語・日本語表示

`language` は論文・発表自体の言語です。

```yaml
language: en  # 英語論文・英語発表
language: ja  # 日本語論文・日本語発表
```

日本語Researchページでも、`language: en` の成果は `title-en`、`description-en`、`publication-en`、`authors-en` を表示します。`language: ja` の成果だけが日本語fieldを表示します。英語ページでは成果の言語にかかわらず英語fieldを表示します。

英語成果の `title-ja` や `description-ja` は表示には使われないため省略できます。既存metadataに残っていても問題ありません。日本語成果では `title-ja` が必須です。

原則として以下の対で保持します。

- `title-en` / `title-ja`
- `description-en` / `description-ja`
- `publication-en` / `publication-ja`
- `authors-en` / `authors-ja`（和文著者表記が必要な場合）
- `news[].en` / `news[].ja`

英語ページは `/research.html`、日本語ページは `/ja/research.html` に生成されますが、両方とも同じqmdを読みます。Recent newsの `news[].en` / `news[].ja` は成果自体の言語とは独立しており、従来どおりページ言語に合わせて表示されます。

`category: clinical` のpublicationは、Researchページの「Medical Research」へ自動分類されます。

## Teaching、Background、助成、受賞等

`content/data/activities.yml` の `items` に追加します。主な `type` は次のとおりです。

- `employment`
- `education`
- `grant`
- `award`
- `teaching`
- `service`

WebとCVへの表示は、研究成果と同じく `channels` で指定します。

## 発表・ソフトウェア

- 発表は `content/talks/` に1発表1qmdで追加します。
- ソフトウェアは `content/software/` に1ソフトウェア1qmdで追加します。
- 発表の `kind` は `conference`、ソフトウェアは `software` とします。
- `links` には `event`、`oral`、`poster`、`cran`、`github` も指定できます。

発表では、発表言語とは別に国内・国際の区分を指定します。

```yaml
kind: conference
scope: domestic             # international / domestic
presentation-type: oral     # oral / poster / symposium / unspecified
language: ja                # 実際の発表言語
date: 2026-06-06            # 記事公開日ではなく実際の発表日
researchmap-id: 53874163    # researchmapとの照合用（存在する場合）
channels: [research, cv]
```

`scope: international` は「Conference Presentations (International)」、`scope: domestic` は「Conference Presentations (JPN Domestic)」へ自動分類されます。CVも同じ区分で生成されます。ニュースやColumnの公開日は `news[].date` として、発表日とは分けて管理します。

## ローカル生成

R、Quarto、LuaLaTeX、Rパッケージ `yaml` が必要です。

```powershell
# metadata検証、listing入力、CV用qmdの生成
Rscript scripts/build_content.R

# WebとCV PDFをまとめて生成
quarto render

# 生成結果を検証
Rscript scripts/validate_content.R

# 架空の研究1件を実際に追加・renderし、英日Home・英日Research・CVへの
# 同時反映を確認後、自動削除・再render
Rscript scripts/test_single_source.R
```

CV PDFのみを生成する場合は次を実行します。

```powershell
Rscript scripts/build_content.R
quarto render CV/cv.qmd
```

生成物は `docs/CV/cv.pdf` です。CVの公開URLは `content/data/profile.yml` の `cv` で一元管理します。

## GitHub Actions

Pull Requestではrenderとvalidationを行います。`main` にmergeされたpushでは、同じ処理後にGitHub Pagesへdeployします。リポジトリのPages設定は、初回利用時にSourceを **GitHub Actions** に設定してください。

## Column

`column/` は従来どおりQuarto blog/listingとして独立管理します。既存記事URL、カテゴリ、Column専用RSS（`/column/index.xml`）は維持されます。新しいColumnのqmdは、`news` を追加しなくても統合RSS（`/updates.xml`）へ自動的に掲載されます。

HomeのRecent newsの正本は `content/` 側ですが、`news[].href` から詳細なColumn記事へリンクできます。同じURLのColumn記事と `news` が存在する場合、統合RSSではColumn記事を優先して重複掲載を防ぎます。

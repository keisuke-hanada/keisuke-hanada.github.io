# keisuke-hanada.github.io

Keisuke Hanada's Quarto website.

Research, talks, software, background, teaching, Home news, and the PDF CV are generated from structured metadata under `content/`. See [MAINTENANCE.md](MAINTENANCE.md) for update instructions.

## Local build

```powershell
Rscript scripts/build_content.R
quarto render
Rscript scripts/validate_content.R
```

The rendered website is written to `docs/`, including `docs/CV/cv_202409.pdf`.

# Publishing checklist

Three independent steps: the repository, the documentation site, the live app.

## A. Repository on GitHub

1. Create an empty repository on github.com (no README/license — this folder
   has them). Public, if the demo should be public.
2. Fill in `LICENSE` (your name/organisation) and replace `<USER>/<REPO>` in
   `docs/_config.yml`.
3. From this folder:

   ```bash
   git init
   git add .
   git commit -m "Procurement Analytics Dashboard: app, demo dataset, docs"
   git branch -M main
   git remote add origin https://github.com/<USER>/<REPO>.git
   git push -u origin main
   ```

   The 10.7 MB demo CSV is well under GitHub's 100 MB per-file limit; no
   Git LFS needed.

## B. Documentation site (GitHub Pages)

1. On GitHub: **Settings → Pages → Build and deployment**.
2. Source: *Deploy from a branch*; Branch: `main`, folder **`/docs`**. Save.
3. After ~2 minutes the site is live at
   `https://<USER>.github.io/<REPO>/` — a themed site (just-the-docs) with a
   navigation sidebar: Home, Demo dataset guide, Methodology, Policy note,
   Developer guide, Function reference.

## C. Live app bundled with the dataset (shinyapps.io)

The app ships with `demo-data/demo_procurement_data.csv`; visitors click
**"Load bundled demo dataset (Demoland)"** on the Setup tab and every
threshold pre-fills automatically — no files to hunt for.

1. Free account at https://www.shinyapps.io; get the token
   (Account → Tokens) and run the `setAccountInfo` line from
   `deploy_shinyapps.R` once.
2. In R, from this folder: `source("deploy_shinyapps.R")`.
   First deployment takes a while (package installation on their servers).
3. Paste the printed URL into `README.md` and `docs/index.md`
   (both have a marked placeholder), commit, push.

Notes:
* Memory: with the 15.7k-row demo plus regressions, set the instance to
  1 GB (Dashboard → the app → Settings → Instance Size — "Large" on the
  free tier). If you outgrow the free tier's 25 active hours/month,
  alternatives: Posit Connect Cloud, or a small VPS running Shiny Server.
* The deploy bundle includes only what the app needs at runtime; docs and
  the data generator stay repository-only.

## D. After everything is live

- [ ] `LICENSE` filled in
- [ ] `docs/_config.yml` aux link points to the real repo
- [ ] Live-demo URL pasted in `README.md` + `docs/index.md`
- [ ] Pages site loads; sidebar shows all six pages
- [ ] On the live app: demo button loads data, thresholds pre-fill,
      network analysis + regressions + a Word export all work

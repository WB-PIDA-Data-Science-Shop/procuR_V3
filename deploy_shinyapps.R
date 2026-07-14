# Deploy the app (bundled with the demo dataset) to shinyapps.io
# One-time setup:
#   install.packages("rsconnect")
#   Get your token at https://www.shinyapps.io/admin/#/tokens and run:
#   rsconnect::setAccountInfo(name="<ACCOUNT>", token="<TOKEN>", secret="<SECRET>")

rsconnect::deployApp(
  appDir  = ".",
  appName = "procurement-analytics-demo",
  appFiles = c(
    "global.R", "ui.R", "server.R",
    "utils_shared.R", "econ_out_utils.R", "admin_utils.R", "integrity_utils.R",
    "www/styles.css",
    "demo-data/demo_procurement_data.csv"   # powers the demo-load button
  ),
  forceUpdate = TRUE
)
# The console prints your live URL, e.g.
#   https://<ACCOUNT>.shinyapps.io/procurement-analytics-demo/
# Paste it into README.md and docs/index.md where marked.

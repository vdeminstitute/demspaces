

RUN_ID <- "latest"
if (RUN_ID=="latest") {
  id <- tail(dir("model-grid"), 1)
  id <- substr(id, 1, 6)
  RUN_ID <- id
}

mg <- readRDS(sprintf("model-grid/%s_mg.rds", RUN_ID))

n_total <- nrow(mg)
n_done <- length(dir(sprintf("chunks_%s", RUN_ID)))

cat(sprintf("%s: %s of %s done (%s%%)\n", RUN_ID, n_done, n_total, round(n_done/n_total*100)))


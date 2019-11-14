#!/usr/bin/env Rscript
suppressPackageStartupMessages(library(argparse))
suppressPackageStartupMessages(library(jsonlite))
suppressPackageStartupMessages(library(PRROC))

compute_scores <- function(submission_path, goldstandard_path) {
  goldstandard <- read.csv(file = 'goldstandard.csv')
  predictions <- read.csv(file = 'predictions.csv')
  ​
  data <- merge(goldstandard, predictions, by="person_id")
  ​
  pos <- subset(data, status == 1)
  neg <- subset(data, status == 0)
  ​
  x = pos$score
  y = neg$score
  ​
  roc<-roc.curve(x,y)
  ​
  pr <- pr.curve(x,y)
  
  c('score_AUC'=roc$auc, 'score_PRAUC'=pr$auc.integral)
}
​

​
#just return roc and pr

parser <- ArgumentParser(description = 'Score submission')
parser$add_argument('-s', '--submission_file',  type = "character", required = T,
                    help = 'Submission path')
parser$add_argument('-g', '--goldstandard',  type = "character", required = T,
                    help = 'Goldstandard path')
parser$add_argument('-r', '--results',  type = "character", required = T,
                    help = 'Results file')
parser$add_argument('-s', '--status',  type = "character", required = T,
                    help = 'Submission status')
args <- parser$parse_args()

if (args$status == "VALIDATED")
scores = compute_scores(args$submission_file, args$goldstandard)

prediction_file_status = "SCORED"

result_list = list()
for (key in names(scores)) {
  result_list[[key]] = scores[[key]]
}

export_json <- toJSON(result_list, auto_unbox = TRUE, pretty=T)
write(export_json, args$results)

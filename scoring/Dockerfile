FROM rocker/tidyverse:3.6.1

RUN R -e 'install.packages("argparse")'

COPY validation_scoring.R /validation_scoring.R
COPY validate.R /usr/local/bin/validate.R
COPY score.R /usr/local/bin/score.R
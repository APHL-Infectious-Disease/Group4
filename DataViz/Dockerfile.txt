FROM rocker/shiny:4.3.1

# System dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-gnutls-dev libssl-dev libxml2-dev libxt-dev \
    && rm -rf /var/lib/apt/lists/*

# R packages
RUN R -e "install.packages(c('shinydashboard', 'tidyverse', 'leaflet', 'DT', 'plotly'), repos='https://cran.rstudio.com/')"

# Setup the app directory properly
RUN rm -rf /srv/shiny-server/*
# Create a subfolder called 'igas'
RUN mkdir /srv/shiny-server/igas
COPY GAS_app.R /srv/shiny-server/igas/
COPY Example_GAS_Genomic_Data.csv /srv/shiny-server/igas/

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]

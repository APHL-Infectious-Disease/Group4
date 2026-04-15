# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-gnutls-dev libssl-dev libxml2-dev libxt-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install CRAN packages
RUN R -e "install.packages(c('shinydashboard', 'tidyverse', 'leaflet', 'DT', 'plotly', 'BiocManager', 'ape'), repos='https://cran.rstudio.com/')"

# Install Bioconductor packages (ggtree)
RUN R -e "BiocManager::install('ggtree')"

# Setup directory
RUN rm -rf /srv/shiny-server/*
COPY app.R /srv/shiny-server/app.R
COPY Example_GAS_Genomic_Data.csv /srv/shiny-server/Example_GAS_Genomic_Data.csv
COPY GAS_tree.nwk /srv/shiny-server/GAS_tree.nwk

WORKDIR /srv/shiny-server/
EXPOSE 3838
CMD ["/usr/bin/shiny-server"]]

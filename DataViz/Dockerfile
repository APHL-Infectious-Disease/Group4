FROM rocker/shiny-verse:latest

# 1. Install EVERY prerequisite (Base layer remains untouched)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libxt-dev \
    zlib1g-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libsqlite3-dev \
    libudunits2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libtiff-dev \
    libnode-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Install 'sf' and 'leaflet' from binary
#RUN R -e "install.packages('sf', repos='https://packagemanager.posit.co/cran/__linux__/jammy/latest')"
RUN R -e "install.packages('leaflet', repos='https://packagemanager.posit.co/cran/__linux__/jammy/latest')"

# 3. MODIFIED: Adding rlang/vctrs and moving treeio to the Binary Repo
RUN R -e "install.packages(c('shinydashboard', 'dplyr', 'ggplot2', 'plotly', 'DT', 'BiocManager', 'ape', 'aplot', 'ggfun', 'yulab.utils', 'ggplotify', 'patchwork', 'rvcheck', 'tidytree', 'lazyeval', 'magrittr', 'jsonlite', 'rlang', 'vctrs', 'treeio'), repos='https://packagemanager.posit.co/cran/__linux__/jammy/latest')"
RUN R -e "BiocManager::install('ggtree', update=FALSE, ask=FALSE)"

# 4. DIAGNOSTIC GATE (The individual verification)
#RUN R -e "library(sf); print('sf: OK')"
RUN R -e "library(jsonlite); library(treeio); print('treeio: OK')"
RUN R -e "library(ggtree); print('ggtree: OK')"

# 5. Setup directory
RUN rm -rf /srv/shiny-server/*
COPY GAS_App.R /srv/shiny-server/GAS_App.R
COPY Example_GAS_Genomic_Data.csv /srv/shiny-server/Example_GAS_Genomic_Data.csv
COPY GAS_tree.nwk /srv/shiny-server/GAS_tree.nwk

WORKDIR /srv/shiny-server/
EXPOSE 3838

# 6. Standalone execution for Codespaces
CMD ["R", "-e", "shiny::runApp('/srv/shiny-server/GAS_App.R', host='0.0.0.0', port=3838)"]

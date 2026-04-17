# GAS_Dashboard
Fictional dashboard for Group A Strep Genomic survellance


This currently only works with the fictional data provided. Need to update for user provided data.

Dockerfile appears to compile in codespaces.

To test with fictional data
1. Open codespaces
2. Navigate to DataViz
3. In Codespaces terminal run "docker build -t gas-dashboard ."
4. Once container is built. run "docker run -p 3838:3838 gas-dashboard"



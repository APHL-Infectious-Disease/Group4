library(shiny)
library(shinydashboard)
library(dplyr)    # Replaces tidyverse for data manipulation
library(ggplot2)  # Replaces tidyverse for plotting
library(readr)    # Replaces tidyverse for reading CSV
library(leaflet)
library(DT)
library(plotly)
library(ggtree)
library(ape)

# Load Data
data <- read.csv("Example_GAS_Genomic_Data.csv")
tree <- read.tree("GAS_tree.nwk")

genotypic_features <- names(data)[!names(data) %in% c("Sample", "Total_Bases", "N50", "Longest_Contig", "Contig_Num")]

ui <- dashboardPage(
  dashboardHeader(title = "iGAS Surveillance"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Overview", tabName = "overview", icon = icon("chart-bar")),
      menuItem("Phylogeny", tabName = "phylo", icon = icon("tree")),
      menuItem("Map Visualization", tabName = "map", icon = icon("map")),
      menuItem("Genomic Data", tabName = "data", icon = icon("dna"))
    ),
    hr(),
    selectInput("selected_feature", "Color Tree/Plots by:", 
                choices = genotypic_features, selected = "emm_Type"),
    selectInput("filter_region", "Region:", choices = c("All", unique(data$Region)))
  ),
  dashboardBody(
    tabItems(
      tabItem(tabName = "overview",
              fluidRow(box(plotlyOutput("dynamic_plot"), width = 12))),
      
      # NEW PHYLOGENY TAB
      tabItem(tabName = "phylo",
              fluidRow(
                box(plotOutput("tree_plot", height = "700px"), width = 9, title = "Phylogenetic Tree"),
                box(width = 3, title = "Tree Settings",
                    radioButtons("layout", "Tree Layout:", 
                                 choices = c("rectangular", "circular", "slanted"), selected = "rectangular"),
                    checkboxInput("show_labels", "Show Sample IDs", value = TRUE))
              )
      ),
      
      tabItem(tabName = "map", box(leafletOutput("galactic_map"), width = 12)),
      tabItem(tabName = "data", box(DTOutput("raw_table"), width = 12, style = "overflow-x: scroll;"))
    )
  )
)

server <- function(input, output) {
  
  # Reactive Tree Plot
  output$tree_plot <- renderPlot({
    # Join tree with metadata
    p <- ggtree(tree, layout = input$layout) %<+% data +
      geom_tippoint(aes(color = !!sym(input$selected_feature)), size = 5) +
      theme(legend.position = "right") +
      labs(title = paste("Tree colored by", input$selected_feature))
    
    if (input$show_labels) {
      p <- p + geom_tiplab(size = 3, offset = 0.005)
    }
    
    p
  })
  
  # (Previous server logic for dynamic_plot, map, and table goes here...)
  output$dynamic_plot <- renderPlotly({
    p <- data %>% count(!!sym(input$selected_feature)) %>%
      ggplot(aes(x = reorder(!!sym(input$selected_feature), n), y = n, fill = !!sym(input$selected_feature))) +
      geom_col() + coord_flip() + theme_minimal()
    ggplotly(p)
  })
  
  output$galactic_map <- renderLeaflet({
    set.seed(42)
    map_df <- data %>% mutate(lat = runif(n(), -20, 20), lng = runif(n(), -20, 20))
    leaflet(map_df) %>% addProviderTiles(providers$CartoDB.DarkMatter) %>%
      addCircleMarkers(~lng, ~lat, popup = ~Sample, color = "cyan", radius = 8)
  })
  
  output$raw_table <- renderDT({ datatable(data, options = list(scrollX = TRUE)) })
}

shinyApp(ui, server)

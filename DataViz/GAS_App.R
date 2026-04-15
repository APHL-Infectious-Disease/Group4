## V2
library(shiny)
library(shinydashboard)
library(tidyverse)
library(leaflet)
library(DT)
library(plotly)

# Load the fictional dataset
data <- read.csv("Expanded_iGAS_Genomic_Data.csv")

# Identify columns to use for the overview dropdown 
# (Excluding ID and coordinate columns)
genotypic_features <- names(data)[!names(data) %in% c("Sample", "Planet", "Region", "Total_Bases", "N50", "Longest_Contig", "Contig_Num")]

ui <- dashboardPage(
  dashboardHeader(title = "Group A Strep Surveillance"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Overview", tabName = "overview", icon = icon("chart-bar")),
      menuItem("Map Visualization", tabName = "map", icon = icon("map")),
      menuItem("Genomic Data", tabName = "data", icon = icon("dna"))
    ),
    hr(),
    # FEATURE SELECTION DROPDOWN
    selectInput("selected_feature", "Select Genotypic Feature:", 
                choices = genotypic_features, selected = "emm_Type"),
    
    selectInput("filter_region", "Filter by Galactic Region:", 
                choices = c("All", unique(data$Region))),
    
    checkboxGroupInput("filter_sir", "Filter by Penicillin SIR:",
                       choices = unique(data$WGS_PEN_SIR),
                       selected = unique(data$WGS_PEN_SIR))
  ),
  
  dashboardBody(
    tabItems(
      # Tab 1: Dynamic Overview
      tabItem(tabName = "overview",
              fluidRow(
                box(plotlyOutput("dynamic_plot"), width = 12, 
                    title = textOutput("plot_title"))
              ),
              fluidRow(
                valueBoxOutput("sample_count"),
                valueBoxOutput("unique_st_count")
              )
      ),
      
      # Tab 2: Map
      tabItem(tabName = "map",
              box(leafletOutput("galactic_map", height = 500), width = 12, 
                  title = "Fictional Galactic Distribution")
      ),
      
      # Tab 3: Data Table
      tabItem(tabName = "data",
              box(DTOutput("raw_table"), width = 12, style = "overflow-x: scroll;")
      )
    )
  )
)

server <- function(input, output) {
  
  # Reactive data filtering
  filtered_data <- reactive({
    df <- data
    if (input$filter_region != "All") {
      df <- df %>% filter(Region == input$filter_region)
    }
    df <- df %>% filter(WGS_PEN_SIR %in% input$filter_sir)
    return(df)
  })
  
  # Dynamic Title for the Plot
  output$plot_title <- renderText({
    paste("Frequency Distribution of", input$selected_feature)
  })
  
  # Dynamic Plot: Updates based on selected dropdown column
  output$dynamic_plot <- renderPlotly({
    req(input$selected_feature)
    
    p <- filtered_data() %>%
      count(!!sym(input$selected_feature)) %>%
      ggplot(aes(x = reorder(!!sym(input$selected_feature), n), y = n, fill = !!sym(input$selected_feature))) +
      geom_col() +
      coord_flip() +
      theme_minimal() +
      theme(legend.position = "none") +
      labs(x = input$selected_feature, y = "Count")
    
    ggplotly(p)
  })
  
  # Dynamic Value Boxes
  output$sample_count <- renderValueBox({
    valueBox(nrow(filtered_data()), "Samples in View", icon = icon("vial"), color = "purple")
  })
  
  output$unique_st_count <- renderValueBox({
    st_count <- length(unique(filtered_data()$ST))
    valueBox(st_count, "Unique STs", icon = icon("fingerprint"), color = "blue")
  })
  
  # Map Visualization
  output$galactic_map <- renderLeaflet({
    # Generating consistent random coords for the fictional planets
    set.seed(42)
    map_df <- filtered_data() %>%
      mutate(lat = runif(n(), -20, 20), lng = runif(n(), -20, 20))
    
    leaflet(map_df) %>%
      addProviderTiles(providers$CartoDB.DarkMatter) %>%
      addCircleMarkers(~lng, ~lat, 
                       popup = ~paste("Sample:", Sample, "<br>Planet:", Planet, "<br>ST:", ST),
                       color = "cyan", radius = 8, fillOpacity = 0.7)
  })
  
  # Data Table
  output$raw_table <- renderDT({
    datatable(filtered_data(), options = list(scrollX = TRUE, pageLength = 10))
  })
}

shinyApp(ui, server)

library(shiny)
library(shinydashboard)
library(tidyverse)
library(leaflet)
library(DT)
library(plotly)
library(ggtree)
library(ape)

# Load Data
data <- read.csv("Expanded_iGAS_Genomic_Data.csv")
tree <- read.tree("iGAS_tree.nwk")

genotypic_features <- names(data)[!names(data) %in% c("Sample", "Planet", "Region", "Total_Bases", "N50", "Longest_Contig", "Contig_Num")]

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


#V4
library(shiny)
library(shinydashboard)
library(dplyr)
library(ggplot2)
library(readr)
library(leaflet)
library(DT)
library(plotly)
library(ggtree)
library(ape)
library(htmltools)

# --- Initial Data Load ---
# These remain as the "default" state
default_data <- read.csv("Example_GAS_Genomic_Data.csv")
tree <- read.tree("GAS_tree.nwk")

genotypic_features <- names(default_data)[!names(default_data) %in% c("Sample", "Total_Bases", "N50", "Longest_Contig", "Contig_Num")]
report_files <- list.files("html_reports", pattern = "\\.html$", full.names = TRUE)

ui <- dashboardPage(
  dashboardHeader(title = "Group A Strep Surveillance"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Overview", tabName = "overview", icon = icon("chart-bar")),
      menuItem("Map Visualization", tabName = "map", icon = icon("map")),
      menuItem("Phylogeny", tabName = "phylo", icon = icon("tree")),
      menuItem("Genomic Data", tabName = "data", icon = icon("dna")),
      menuItem("Fastp Data", tabName = "QC", icon = icon("chart-line")) # Fixed missing quote
    ),
    hr(),
    
    # NEW: Drag and Drop File Input
    fileInput("upload_csv", "Upload New Genomic CSV",
              accept = c("text/csv", "text/comma-separated-values,text/plain", ".csv")),
    
    hr(),
    selectInput("selected_feature", "Select Genotypic Feature:", 
                choices = genotypic_features, selected = "emm_Type"),
    
    selectInput("filter_region", "Filter by Galactic Region:", 
                choices = c("All", unique(default_data$Region))),
    
    checkboxGroupInput("filter_sir", "Filter by Penicillin SIR:",
                       choices = unique(default_data$WGS_PEN_SIR),
                       selected = unique(default_data$WGS_PEN_SIR)),
    
    selectInput("report", "Choose report", choices = basename(report_files))
  ),
  
  dashboardBody(
    tabItems(
      tabItem(tabName = "overview",
              fluidRow(
                box(plotlyOutput("dynamic_plot"), width = 12, title = textOutput("plot_title"))
              ),
              fluidRow(
                valueBoxOutput("sample_count"),
                valueBoxOutput("unique_st_count")
              )
      ),
      tabItem(tabName = "phylo",
              fluidRow(
                box(plotOutput("tree_plot", height = "700px"), width = 9, title = "Phylogenetic Tree"),
                box(width = 3, title = "Tree Settings",
                    radioButtons("layout", "Tree Layout:", 
                                 choices = c("rectangular", "circular", "slanted"), selected = "rectangular"),
                    checkboxInput("show_labels", "Show Sample IDs", value = TRUE))
              )
      ),
      tabItem(tabName = "map",
              box(leafletOutput("galactic_map", height = 500), width = 12, 
                  title = "Fictional Galactic Distribution")
      ),
      tabItem(tabName = "data",
              box(DTOutput("raw_table"), width = 12, style = "overflow-x: scroll;")
      ),
      tabItem(tabName = "QC",
              uiOutput("report_ui")
      )
    )
  )
)

server <- function(input, output, session) {
  
  # 1. Store the data in a Reactive Value
  # Starts with the default_data loaded at startup
  dataset <- reactiveValues(main = default_data)
  
  # 2. Update logic for when a file is "dropped" into the app
  observeEvent(input$upload_csv, {
    req(input$upload_csv)
    
    # Read the new file
    new_df <- read.csv(input$upload_csv$datapath)
    dataset$main <- new_df
    
    # Update UI Inputs to match the new file's content
    new_features <- names(new_df)[!names(new_df) %in% c("Sample", "Total_Bases", "N50", "Longest_Contig", "Contig_Num")]
    updateSelectInput(session, "selected_feature", choices = new_features)
    updateSelectInput(session, "filter_region", choices = c("All", unique(new_df$Region)))
    updateCheckboxGroupInput(session, "filter_sir", choices = unique(new_df$WGS_PEN_SIR), 
                             selected = unique(new_df$WGS_PEN_SIR))
  })
  
  # 3. Use the reactive dataset for filtering
  filtered_data <- reactive({
    df <- dataset$main
    if (input$filter_region != "All") {
      df <- df %>% filter(Region == input$filter_region)
    }
    df <- df %>% filter(WGS_PEN_SIR %in% input$filter_sir)
    return(df)
  })
  
  # --- Outputs (Now using filtered_data() which is reactive) ---
  
  output$tree_plot <- renderPlot({
    # Join tree with metadata from the reactive dataframe
    p <- ggtree(tree, layout = input$layout) %<+% dataset$main +
      geom_tippoint(aes(color = !!sym(input$selected_feature)), size = 5) +
      theme(legend.position = "right") +
      labs(title = paste("Tree colored by", input$selected_feature))
    
    if (input$show_labels) {
      p <- p + geom_tiplab(size = 3, offset = 0.005)
    }
    p
  })
  
  output$plot_title <- renderText({
    paste("Frequency Distribution of", input$selected_feature)
  })
  
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
  
  output$sample_count <- renderValueBox({
    valueBox(nrow(filtered_data()), "Samples in View", icon = icon("vial"), color = "purple")
  })
  
  output$unique_st_count <- renderValueBox({
    # Ensure ST column exists in uploaded data
    st_val <- if("ST" %in% names(filtered_data())) length(unique(filtered_data()$ST)) else 0
    valueBox(st_val, "Unique STs", icon = icon("fingerprint"), color = "blue")
  })
  
  output$galactic_map <- renderLeaflet({
    set.seed(42)
    map_df <- filtered_data() %>%
      mutate(lat = runif(n(), -20, 20), lng = runif(n(), -20, 20))
    
    leaflet(map_df) %>%
      addProviderTiles(providers$CartoDB.DarkMatter) %>%
      addCircleMarkers(~lng, ~lat, 
                       popup = ~paste("Sample:", Sample),
                       color = "cyan", radius = 8, fillOpacity = 0.7)
  })
  
  output$raw_table <- renderDT({
    datatable(filtered_data(), options = list(scrollX = TRUE, pageLength = 10))
  })
  
  output$report_ui <- renderUI({
    req(input$report)
    # Note: Ensure the file path logic matches your local folder structure
    file <- file.path("html_reports", input$report)
    includeHTML(file)
  })
}

shinyApp(ui, server)

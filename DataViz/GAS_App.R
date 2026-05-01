#V5
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
library(rmarkdown)

# --- 1. Initial Data Load & Setup ---
# These must match the filenames in your Dockerfile COPY commands
default_data <- read.csv("Example_GAS_Genomic_Data.csv")
default_tree <- read.tree("GAS_tree.nwk")

# Resource Paths: Tells Shiny where to find subfolders inside the Docker container
addResourcePath("html_reports", "html_reports")
addResourcePath("sample_pdfs", "sample_pdfs")

# Identify columns to use for the dropdown (excluding ID/QC metrics)
get_features <- function(df) {
  names(df)[!names(df) %in% c("Sample", "Total_Bases", "N50", "Longest_Contig", "Contig_Num")]
}

# --- 2. UI Definition ---
ui <- dashboardPage(
  dashboardHeader(title = "GAS Genomic Surveillance"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Overview", tabName = "overview", icon = icon("chart-bar")),
      menuItem("Map Visualization", tabName = "map", icon = icon("map")),
      menuItem("Phylogeny", tabName = "phylo", icon = icon("tree")),
      menuItem("Genomic Data", tabName = "data", icon = icon("dna")),
      menuItem("Fastp QC", tabName = "QC", icon = icon("chart-line")),
      menuItem("Sample Reports", tabName = "html_reports", icon = icon("file-html"))
    ),
    hr(),
    # Sidebar Controls
    fileInput("upload_csv", "1. Upload New CSV", accept = ".csv"),
    fileInput("upload_tree", "2. Upload New Tree (.nwk)", accept = c(".nwk", ".tree")),
    
    hr(),
    selectInput("selected_feature", "Color/Filter by:", choices = get_features(default_data)),
    selectInput("filter_region", "Region:", choices = c("All", unique(default_data$Region))),
    
    hr(),
    helpText("Developed by Group 4")
  ),
  
  dashboardBody(
    tabItems(
      # Overview Tab
      tabItem(tabName = "overview",
              fluidRow(
                box(plotlyOutput("dynamic_plot"), width = 12, title = "Genomic Feature Distribution")
              ),
              fluidRow(
                valueBoxOutput("sample_count"),
                valueBoxOutput("unique_st_count")
              )),
      
      # Phylogeny Tab
      tabItem(tabName = "phylo",
              fluidRow(
                box(plotOutput("tree_plot", height = "700px"), width = 9, title = "Phylogenetic Tree"),
                box(width = 3, title = "Tree Settings",
                    radioButtons("layout", "Tree Layout:", choices = c("rectangular", "circular", "slanted")),
                    checkboxInput("show_labels", "Show Sample IDs", value = TRUE),
                    downloadButton("download_tree_pdf", "Export Tree as PDF"))
              )),
      
      # Map Tab
      tabItem(tabName = "map",
              box(leafletOutput("galactic_map", height = 600), width = 12, title = "Spatial Distribution")),
      
      # Data Tab
      tabItem(tabName = "data",
              box(DTOutput("raw_table"), width = 12, style = "overflow-x: scroll;")),
      
      # Fastp HTML Tab
      tabItem(tabName = "QC",
              box(width = 12, title = "Sequence Quality (Fastp)",
                  selectInput("selected_html", "Select Report:", choices = list.files("html_reports")),
                  htmlOutput("fastp_frame"))),
      
      # html Generation Tab
      tabItem(tabName = "html_reports",
              fluidRow(
                box(width = 4, title = "Report Generator",
                    selectInput("report_sample", "Select Sample ID:", choices = default_data$Sample),
                    downloadButton("download_report", "Generate & Download html")),
                box(width = 8, title = "Information",
                    p("This tool generates a clinical-style summary for the selected isolate including assembly quality (N50, Contigs) and genotypic markers (EMM, MLST)."))
              ))
    )
  )
)

# --- 3. Server Logic ---
server <- function(input, output, session) {
  
  # Reactive Values to hold the current app state
  state <- reactiveValues(
    main_df = default_data,
    main_tree = default_tree
  )
  
  # Update state when CSV is uploaded
  observeEvent(input$upload_csv, {
    req(input$upload_csv)
    new_df <- read.csv(input$upload_csv$datapath)
    state$main_df <- new_df
    
    # Update UI Inputs
    updateSelectInput(session, "selected_feature", choices = get_features(new_df))
    updateSelectInput(session, "filter_region", choices = c("All", unique(new_df$Region)))
    updateSelectInput(session, "report_sample", choices = new_df$Sample)
  })
  
  # Update state when Tree is uploaded
  observeEvent(input$upload_tree, {
    req(input$upload_tree)
    state$main_tree <- read.tree(input$upload_tree$datapath)
  })
  
  # Reactive filtering
  filtered_data <- reactive({
    df <- state$main_df
    if (input$filter_region != "All") {
      df <- df %>% filter(Region == input$filter_region)
    }
    df
  })
  
  # --- Output: Overview ---
  output$dynamic_plot <- renderPlotly({
    req(input$selected_feature)
    p <- filtered_data() %>%
      count(!!sym(input$selected_feature)) %>%
      ggplot(aes(x = reorder(!!sym(input$selected_feature), n), y = n, fill = !!sym(input$selected_feature))) +
      geom_col() + coord_flip() + theme_minimal() + theme(legend.position = "none")
    ggplotly(p)
  })
  
  output$sample_count <- renderValueBox({
    valueBox(nrow(filtered_data()), "Samples in View", icon = icon("vial"), color = "purple")
  })
  
  output$unique_st_count <- renderValueBox({
    st_col <- if("ST" %in% names(filtered_data())) length(unique(filtered_data()$ST)) else "N/A"
    valueBox(st_col, "Unique MLSTs", icon = icon("fingerprint"), color = "blue")
  })
  
  # --- Output: Phylogeny ---
  output$tree_plot <- renderPlot({
    req(state$main_tree, state$main_df, input$selected_feature)
    p <- ggtree(state$main_tree, layout = input$layout) %<+% state$main_df +
      geom_tippoint(aes(color = !!sym(input$selected_feature)), size = 5) +
      theme(legend.position = "right")
    
    if (input$show_labels) p <- p + geom_tiplab(size = 3, offset = 0.005)
    p
  })
  
  output$download_tree_pdf <- downloadHandler(
    filename = function() { paste0("Tree_Export_", Sys.Date(), ".pdf") },
    content = function(file) {
      pdf(file, width = 11, height = 8.5)
      p <- ggtree(state$main_tree, layout = input$layout) %<+% state$main_df +
           geom_tippoint(aes(color = !!sym(input$selected_feature)), size = 3) +
           geom_tiplab(size = 2)
      print(p)
      dev.off()
    }
  )
  
  # --- Output: Map ---
  output$galactic_map <- renderLeaflet({
    set.seed(42) # For consistent random jitter if lat/long aren't provided
    map_df <- filtered_data() %>%
      mutate(lat = runif(n(), -20, 20), lng = runif(n(), -20, 20))
    
    leaflet(map_df) %>%
      addProviderTiles(providers$CartoDB.DarkMatter) %>%
      addCircleMarkers(~lng, ~lat, popup = ~paste("Sample:", Sample),
                       color = "cyan", radius = 7, fillOpacity = 0.8)
  })
  
  # --- Output: Data Table ---
  output$raw_table <- renderDT({
    datatable(filtered_data(), options = list(scrollX = TRUE, pageLength = 10))
  })
  
  # --- Output: Fastp Viewer ---
  output$fastp_frame <- renderUI({
    req(input$selected_html)
    tags$iframe(src = paste0("html_reports/", input$selected_html), 
                style = "width:100%; height:800px; border:none;")
  })
  
  # --- Output: html Report Generation ---
 output$download_report <- downloadHandler(
  # Change extension to .html
  filename = function() { 
    paste0("GAS_Report_", input$report_sample, ".html") 
  },
  content = function(file) {
    id <- showNotification("Generating HTML Report...", duration = NULL, closeButton = FALSE)
    on.exit(removeNotification(id), add = TRUE)
    
    sample_info <- state$main_df %>% filter(Sample == input$report_sample)
    
    temp_rmd <- file.path(tempdir(), "report_template.Rmd")
    file.copy("report_template.Rmd", temp_rmd, overwrite = TRUE)
    
    # Render to HTML
    rmarkdown::render(temp_rmd, output_file = file,
                      params = list(sample_data = sample_info),
                      envir = new.env(parent = globalenv()))
  }
)
}

# --- 4. Launch ---
shinyApp(ui, server)
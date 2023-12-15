library(shiny)
library(ggplot2)
library(DT)
library(plotly)

data <- read.csv('seaad_metadata.csv')

ui <- fluidPage(
  titlePanel("SEA-AD Metadata Explorer"),
  tabsetPanel(
    tabPanel('Overview of variables',
             selectInput('variable', 'Select the variable to visualize:',
                         choices = c('Age.at.Death', 'Sex','Braak', 'Thal', 'ADNC')),
             plotlyOutput('visualization'),
             htmlOutput('uniqueValuesText') 
    ),
    tabPanel('Select based on Donor ID',
             HTML('Please select the sample metadata based on Donor.ID which you need for analyzing the snRNA-seq data.<br>'),
             selectInput('donorInput', 'Select Donor.ID:',
                         choices = unique(data$Donor.ID),
                         multiple = FALSE),
             actionButton('addButton', 'Add'),
             DTOutput('donorTable'),
             downloadButton('downloadButton', 'Download Table')
    ),
    tabPanel('Filter by Cognitive Status, Braak Stage, and ADNC Score',
             selectInput('cognitiveStatusInput', 'Select Cognitive Status:',
                         choices = c("No dementia", "Dementia")),
             selectInput('braakStageInput', 'Select Braak Stage:',
                         choices = c("Braak I", "Braak II", "Braak III", "Braak IV", "Braak V", "Braak VI")),
             selectInput('adncScoreInput', 'Select ADNC Score:',
                         choices = c("Low", "Intermediate", "High")),
             DTOutput('filteredDataTable'),
             downloadButton('filteredDownloadButton', 'Download Filtered Table')
    )
  )
)

server <- function(input, output, session) {
  # Create a reactive expression for data transformation
  transformed_data <- reactive({
    data$Cognitive.status = as.factor(data$Cognitive.status)
    data$Age.at.Death = as.numeric(data$Age.at.Death)
    data$Braak = as.factor(data$Braak)
    data$Thal = as.factor(data$Thal)
    data$ADNC = as.factor(data$ADNC)
    
    # Returning the data based on the selected variable
    switch(input$variable,
           'Age.at.Death' = data[, c('Cognitive.status', 'Age.at.Death')],
           'Sex' = data[, c('Cognitive.status', 'Sex')],
           'Braak' = data[, c('Cognitive.status', 'Braak')],
           'Thal' = data[, c('Cognitive.status', 'Thal')],
           'ADNC' = data[, c('Cognitive.status', 'ADNC')]
    )
  })
  
  output$visualization = renderPlotly({  # Use renderPlotly instead of renderPlot
    ggplot(transformed_data(), aes(x = as.factor(get(input$variable)), fill = as.factor(get(input$variable)))) +
      geom_bar(width = 0.7, position = "dodge") +  # Use geom_bar for discrete x aesthetic
      theme_classic() +
      facet_grid(. ~ Cognitive.status) +
      labs(x = input$variable, y = 'count', fill = input$variable)
    
  })
  
  output$uniqueValuesText <- renderUI({
    unique_values <- unique(data[[input$variable]])
    unique_string <- paste0(unique_values, collapse = ", ")
    result_html <- tags$div(
      tags$strong(input$variable, ":"),
      tags$span(unique_string)
    )
    
    # Return the HTML element
    result_html
  })
  
  selected_donor_data <- reactiveVal(data.frame())
  
  observeEvent(input$addButton, {
    donor_id <- input$donorInput
    donor_row <- data[data$Donor.ID == donor_id, ]
    
    if (!is.null(donor_row) && nrow(donor_row) > 0) {
      selected_donor_data(rbind(selected_donor_data(), donor_row))
    } else {
      # Display a message if the Donor.ID is not found
      showModal(modalDialog(
        title = "Donor.ID Not Found",
        "The selected Donor.ID does not exist in the dataset.",
        easyClose = TRUE
      ))
    }
  })
  
  output$donorTable <- renderDT({
    datatable(selected_donor_data(), options = list(pageLength = 5))
  })
  
  # Download button functionality
  output$downloadButton <- downloadHandler(
    filename = function() {
      paste("donorTable_", Sys.Date(), ".csv", sep = "")
    },
    content = function(file) {
      write.csv(selected_donor_data(), file, row.names = FALSE)
    }
  )
  
  filtered_data <- reactive({
    data$Cognitive.status = as.factor(data$Cognitive.status)
    data$Braak = as.factor(data$Braak)
    data$ADNC = as.factor(data$ADNC)
    
    filtered_data <- data[data$Cognitive.status == input$cognitiveStatusInput &
                            data$Braak == input$braakStageInput &
                            data$ADNC == input$adncScoreInput, ]
    
    filtered_data
  })
  
  output$filteredDataTable <- renderDT({
    datatable(filtered_data(), options = list(pageLength = 5))
  })
  
  # Download button functionality for the filtered table
  output$filteredDownloadButton <- downloadHandler(
    filename = function() {
      paste("filteredTable_", Sys.Date(), ".csv", sep = "")
    },
    content = function(file) {
      write.csv(filtered_data(), file, row.names = FALSE)
    }
  )
}

shinyApp(ui, server)

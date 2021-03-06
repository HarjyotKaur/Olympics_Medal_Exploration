# app.R
# Harjyot Kaur and Shayne Andrews, Jan 2019

#

# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.



# load packages
suppressPackageStartupMessages(library(rsconnect))
suppressPackageStartupMessages(library(shiny))
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(maps))
suppressPackageStartupMessages(library(plotly))
suppressPackageStartupMessages(library(shinyWidgets))
suppressPackageStartupMessages(library(tm))
suppressPackageStartupMessages(library(wordcloud))
suppressPackageStartupMessages(library(shinyjs))
suppressPackageStartupMessages(library(shinyalert))


# sidebar and top bar background color
c1 <- "#f0f0f0"


# load data
df <- read.csv('2014_world_gdp_with_codes.csv',stringsAsFactors = FALSE)


# data wrangling
athletes <- read.csv("df_athlete.csv",stringsAsFactors = FALSE)  %>%
    mutate(Medal=replace_na(Medal,0),
           Gold=replace_na(Gold,0),
           Silver=replace_na(Silver,0),
           Bronze=replace_na(Bronze,0),
           Medal_Count = Gold + Silver + Bronze,
           Medal_Value = Gold*3 + Silver*2 + Bronze,
           Sex=if_else(Sex=="F","1","2")) %>%
    select(-c(City)) %>%
    filter(Medal_Count > 0) %>%
    drop_na()


# widget inputs
ageRange <- c(min(athletes$Age),max(athletes$Age))
weightRange <- c(min(athletes$Weight),max(athletes$Weight))
heightRange <- c(min(athletes$Height),max(athletes$Height))
yearRange <- c(min(athletes$Year),max(athletes$Year))
countries <- sort(unique(athletes$country))
sports <- sort(unique(athletes$Sport))


# adding color to slider widgets
mycss <- "
.irs-bar,
.irs-bar-edge,
.irs-single,
.irs-grid-pol {
  background: black;
  border-color: black;
}
"


ui <- fluidPage(

    useShinyalert(),
    useShinyjs(),

    # this first fluidRow is the top bar
    fluidRow(),
    fluidRow(

        style = paste("background-color:",c1),
        column(width = 3,align="center",
           h2("Olympic Medal Explorer"),
           img(src="rings.png", width="50%")
        ),

        br(),
        br(),

        column(width = 1,
            strong("Medals"),
            checkboxGroupInput("inpMedals", label = NULL,
                               choices = list("Gold" = 3, "Silver" = 2, "Bronze" = 1),
                               selected = c(1,2,3)),
            strong("Sex"),
            checkboxGroupInput("inpSex", label = NULL,
                               choices = list("Female" = 1, "Male" = 2),
                               selected = c(1,2))
        ),
        column(width = 2,
            strong("Age"),
            plotOutput("histAge", height="8%"),
            tags$style(mycss),
            sliderInput("inpAge", label = NULL, width="100%",
                        min = ageRange[1], max = ageRange[2], value = ageRange
            )
        ),
        column(width = 2,
               strong("Weight (kg)"),
               plotOutput("histWeight", height="8%"),
               setSliderColor(c("Black "), c(2)),
               sliderInput("inpWeight", label=NULL, width="100%",
                           min = weightRange[1], max = weightRange[2], value = weightRange
               )
        ),
        column(width = 2,
               strong("Height (cm)"),
               plotOutput("histHeight", height="8%"),
               setSliderColor(c("Black "), c(3)),
               sliderInput("inpHeight", label=NULL, width="100%",
                           min = heightRange[1], max = heightRange[2], value = heightRange
               )
        )
    ),


    # this fluidRow contains the left sidebar and tabs
    fluidRow(

        column(width=3, style=paste("background-color:",c1),


            pickerInput("inpCountry","Country",
                        choices=countries,
                        selected = countries,
                        options = list(`actions-box` = TRUE),multiple = T),
            br(),
            br(),

            pickerInput("inpSport","Sport",
                        choices = sports,
                        selected = sports,
                        options = list(`actions-box` = TRUE),multiple = T),
            br(),
            br(),

            strong("Timeline"),
            plotOutput("histYear", height="8%"),
            setSliderColor(c("Black "), c(4)),
            sliderInput("inpYear", label=NULL,
                        min=yearRange[1], max=yearRange[2],
                        value=yearRange,width="100%",sep="",animate=TRUE
            ),


            actionButton("help", strong("Help"),
                         icon = icon("info-circle")),



            actionButton("reset", strong("Reset All"),
                         icon = icon("refresh")),
            br(),
            br()
        ),

        column(width=8,
            tabsetPanel(
                tabPanel("World Map",
                         br(),
                         br(),
                         plotlyOutput("world_map",height = 600)),
                tabPanel("Compare Countries and Sports",
                         br(),
                         br(),
                         plotOutput("lineSports",height = 600)),
                tabPanel(align="center",
                         "Olympic Event Particpation ",
                         plotOutput("word_cloud",height = 600),
                         h5("Note: The size of the word corresponds to participants in that Olympics Event."
                            ))
            )
        )
    )
)


server <- function(input, output, session) {


    # this is the reactive object to filter data from all inputs
    df_filtered <- reactive({
        athletes %>%
            filter(Year>input$inpYear[1],
               Year<input$inpYear[2],
               country %in% input$inpCountry,
               Age >= input$inpAge[1],
               Age <= input$inpAge[2],
               Weight >= input$inpWeight[1],
               Weight <= input$inpWeight[2],
               Height >= input$inpHeight[1],
               Height <= input$inpHeight[2],
               Medal_Value %in% input$inpMedals,
               Sex %in% input$inpSex,
               Sport %in% input$inpSport)
    })


    # resets widgets to original selections
    observeEvent(input$reset, {
      shinyjs::reset("inpMedals")
      shinyjs::reset("inpSex")
      shinyjs::reset("inpAge")
      shinyjs::reset("inpWeight")
      shinyjs::reset("inpHeight")
      shinyjs::reset("inpCountry")
      shinyjs::reset("inpSport")
      shinyjs::reset("inpYear")
    })


    # message for help button
    observeEvent(input$help, {
      shinyalert("Olympics Medal Explorer",
                 paste0("This app showcases distribution of olympic medals
                 across different countires. The distribution can be observed
                 in various events over the past years. Users can explore this
                 app by utilizing the wide array of filter options available.
                 To download data please visit ",
                href="https://www.kaggle.com/heesoo37/120-years-of-olympic-history-athletes-and-results"),
                type = "info")
    })


    # dynamic color scheme for plots
    # in accordance with medal selection
    c3 <- reactive({
      if (length(input$inpMedals)==1)
      {
      if (input$inpMedals == '3') return("YlOrRd")
      if (input$inpMedals == '2') return("Greys")
      if (input$inpMedals == '1') return("Oranges")
      }
      else return("Blues")
    })


    # dynamic color scheme for widgets
    # in accordance with medal selection
    c2 <- reactive({
      if (length(input$inpMedals)==1)
      {
        if (input$inpMedals == '3') return("goldenrod3")
        if (input$inpMedals == '2') return("grey40")
        if (input$inpMedals == '1') return("darkorange3")
      }
      else return("dodgerblue4")
    })


    # top 4 countries
    df_top_countries <- reactive({
        df_filtered() %>%
            group_by(country) %>%
            tally() %>%
            top_n(5)
    })


    # age histogram
    output$histAge <- renderPlot(height=100,
        ggplot(df_filtered(), aes(Age)) +
            geom_histogram(binwidth=2, fill=c2()) +
            theme_minimal() +
            theme(axis.text.x=element_blank(),
                  axis.ticks.x=element_blank(),
                  axis.text.y=element_blank(),
                  axis.ticks.y=element_blank(),
                  plot.background = element_rect(fill = c1, color = c1)) +
            xlim(ageRange[1],ageRange[2]) +
            labs(x = NULL, y = NULL)
    )


    # weight histogram
    output$histWeight <- renderPlot(height=100,
        ggplot(df_filtered(), aes(Weight)) +
            geom_histogram(binwidth=5, fill=c2()) +
            theme_minimal() +
            theme(axis.text.x=element_blank(),
                  axis.ticks.x=element_blank(),
                  axis.text.y=element_blank(),
                  axis.ticks.y=element_blank(),
                  plot.background = element_rect(fill = c1, color = c1)) +
            xlim(weightRange[1],weightRange[2]) +
            labs(x = NULL, y = NULL)
    )


    # height histogram
    output$histHeight <- renderPlot(height=100,
        ggplot(df_filtered(), aes(Height)) +
            geom_histogram(binwidth=5, fill=c2()) +
            theme_minimal() +
            theme(axis.text.x=element_blank(),
                  axis.ticks.x=element_blank(),
                  axis.text.y=element_blank(),
                  axis.ticks.y=element_blank(),
                  plot.background = element_rect(fill = c1, color = c1)) +
            xlim(heightRange[1],heightRange[2]) +
            labs(x = NULL, y = NULL)
    )


    # year histogram
    output$histYear <- renderPlot(height=100,
        ggplot(df_filtered(), aes(Year)) +
            geom_histogram(binwidth=4, fill=c2()) +
            theme_minimal() +
            theme(axis.text.x=element_blank(),
                  axis.ticks.x=element_blank(),
                  axis.text.y=element_blank(),
                  axis.ticks.y=element_blank(),
                  plot.background = element_rect(fill = c1, color = c1)) +
            xlim(yearRange[1],yearRange[2]) +
            labs(x = NULL, y = NULL)
    )


    # faceted bar chart for sports and countries
    output$lineSports <- renderPlot(
        df_filtered() %>%
            group_by(Sport) %>%
            tally() %>%
            top_n(5) %>%
            inner_join(df_filtered()) %>%
            inner_join(df_top_countries(),
                       by=c("country" = "country")) %>%
            ggplot(aes(Year)) +
                geom_bar(fill="black",width=4) +
                labs(x="Year", y="Medals") +
                theme_light() +
                theme(legend.position="none") +
                scale_x_discrete() +
                xlim(yearRange) +
                facet_grid(rows = vars(Sport), cols = vars(country))+
                scale_fill_distiller(palette=c3())+
                labs(caption="\n Note: The plot above has pre-selection of all countries and sports and thus showcases the top 5 countires and top 5 sports played.
                    On changing countires and sports from the side-bar user can compare other countries. There can be rare cases where there will be no data points
                    for that country/sport combination, and therefore you may see fewer than 5 countries shown. Nevertheless be very useable in the majority of cases.")+
            theme_bw()+
            theme(
                plot.caption = element_text(hjust = 0.5,size=12),
                strip.text.x = element_text(size = 14, colour = "white",face = "bold"),
                strip.text.y = element_text(size = 14, colour = "white",face = "bold"),
                strip.background =element_rect(fill=c2()))

    )


    # choropleth world map for medal count
    output$world_map <- renderPlotly({

        medals <- left_join(df_filtered(), df, by=c("country"="COUNTRY")) %>%
            group_by(country,CODE) %>%
            summarize(medal_count=sum(Medal_Count))

        l <- list(color = toRGB("grey"), width = 0.5)
        g <- list(
            showframe = FALSE,
            showcoastlines = TRUE,
            projection = list(type = 'Mercator')
        )
        p <- plot_geo(medals) %>%
            add_trace(
                z = ~medal_count, color = ~medal_count, colors = c3(),
                text = ~country, locations = ~CODE, marker = list(line = l)
            ) %>%
            colorbar(title = 'Medal Count') %>%
            layout(geo = g)
    })


    # word cloud for olympic events
    output$word_cloud <- renderPlot({

        text = df_filtered() %>%
            select(Event)

        myCorpus = Corpus(VectorSource(text))
        myCorpus = tm_map(myCorpus, content_transformer(tolower))
        myCorpus = tm_map(myCorpus, removePunctuation)
        myCorpus = tm_map(myCorpus, removeNumbers)
        myCorpus = tm_map(myCorpus, removeWords, c("mens","womens","metres","team","water"))

        myDTM = TermDocumentMatrix(myCorpus, control = list(minWordLength = 1))

        m = as.matrix(myDTM)
        v=sort(rowSums(m), decreasing = TRUE)

        wordcloud_rep <- repeatable(wordcloud)

        wordcloud_rep(names(v), v,scale=c(5,1),
                      size = 10, minRotation = -pi/2, maxRotation = -pi/2,
                      max.words=40, colors=brewer.pal(8,c3())
        )
    })
}


# Run the application
shinyApp(ui = ui, server = server)

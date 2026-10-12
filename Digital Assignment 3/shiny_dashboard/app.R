library(shiny); library(plotly); library(DT); library(dplyr); library(readr); library(bslib)

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))   # run from the app folder

scores  <- read_csv("da3_customer_scores.csv",   show_col_types = FALSE)
models  <- read_csv("da3_final_comparison.csv",  show_col_types = FALSE)
segprof <- read_csv("da3_segment_profiles.csv",  show_col_types = FALSE)
monthly <- read_csv("da3_monthly_revenue.csv",   show_col_types = FALSE)
feats   <- read_csv("customer_features.csv",     show_col_types = FALSE)

CAT  <- c("#2A6FB0", "#C65A1E", "#0E8F86", "#8E4EA8", "#B8902A")
RISK <- c(Low = "#0E8F86", Medium = "#B8902A", High = "#C65A1E")
SURF <- "#fcfcfb"; INK <- "#33312e"; MUTED <- "#6f6a62"

base_ly <- function(p, ytitle = "", xtitle = "") {
  p %>% layout(paper_bgcolor = SURF, plot_bgcolor = SURF,
               font = list(family = "Segoe UI, Arial", color = INK, size = 13),
               yaxis = list(title = ytitle, gridcolor = "#eceae4", zeroline = FALSE),
               xaxis = list(title = xtitle, showgrid = FALSE),
               margin = list(l = 70, r = 30, t = 40, b = 60),
               legend = list(orientation = "h", y = -0.2))
}

ui <- page_sidebar(
  title = "Customer Analytics Dashboard — DA3",
  theme = bs_theme(bg = "#f4f1ea", fg = INK, primary = "#2A6FB0", base_font = font_google("Inter")),
  sidebar = sidebar(
    width = 290,
    h5("Filters"),
    checkboxGroupInput("risk", "Churn risk band",
                       choices = c("Low", "Medium", "High"), selected = c("Low", "Medium", "High")),
    checkboxGroupInput("tier", "Customer value tier",
                       choices = c("Bronze", "Silver", "Gold", "Platinum"),
                       selected = c("Bronze", "Silver", "Gold", "Platinum")),
    selectInput("seg", "Segment", choices = c("All", sort(unique(scores$segment))), selected = "All"),
    sliderInput("minprob", "Minimum churn probability", 0, 1, 0, step = 0.05),
    hr(),
    downloadButton("dl", "Download filtered list", class = "btn-primary btn-sm")
  ),
  layout_columns(
    fill = FALSE,
    value_box("Customers", textOutput("kpi_n"), theme = "primary"),
    value_box("Lifetime value", textOutput("kpi_val")),
    value_box("Revenue at risk", textOutput("kpi_risk")),
    value_box("Average churn risk", textOutput("kpi_prob"))
  ),
  navset_card_tab(
    nav_panel("Overview",   plotlyOutput("p_action", height = "380px"),
              plotlyOutput("p_risk",   height = "340px")),
    nav_panel("Segments",   plotlyOutput("p_scatter", height = "480px"),
              DTOutput("t_seg")),
    nav_panel("Models",     plotlyOutput("p_models", height = "400px"), DTOutput("t_models")),
    nav_panel("Revenue",    plotlyOutput("p_month", height = "380px"),
              plotlyOutput("p_tier",  height = "380px")),
    nav_panel("Customers",  DTOutput("t_cust"))
  )
)

server <- function(input, output, session) {
  
  filt <- reactive({
    d <- scores %>%
      filter(risk_band %in% input$risk,
             value_tier %in% input$tier,
             churn_probability >= input$minprob)
    if (input$seg != "All") d <- d %>% filter(segment == as.integer(input$seg))
    d
  })
  
  output$kpi_n    <- renderText(format(nrow(filt()), big.mark = ","))
  output$kpi_val  <- renderText(paste0("GBP ", format(round(sum(filt()$monetary)), big.mark = ",")))
  output$kpi_risk <- renderText(paste0("GBP ", format(round(sum(filt()$revenue_at_risk)), big.mark = ",")))
  output$kpi_prob <- renderText(sprintf("%.3f", mean(filt()$churn_probability)))
  
  output$p_action <- renderPlotly({
    d <- filt() %>% group_by(recommended_action) %>%
      summarise(revenue = sum(revenue_at_risk), n = n()) %>% arrange(revenue)
    plot_ly(d, x = ~revenue, y = ~reorder(recommended_action, revenue), type = "bar",
            orientation = "h", marker = list(color = CAT[1]),
            text = ~paste0("GBP ", format(round(revenue), big.mark = ","), "  (", n, ")"),
            textposition = "outside", textfont = list(color = MUTED),
            hovertemplate = "%{y}<br>GBP %{x:,.0f}<extra></extra>") %>%
      base_ly(xtitle = "Revenue at risk (GBP)") %>%
      layout(title = "Revenue exposed by recommended action",
             margin = list(l = 190, r = 90),
             xaxis = list(title = "Revenue at risk (GBP)",
                          range = c(0, max(d$revenue) * 1.35)))
  })
  
  output$p_risk <- renderPlotly({
    d <- filt() %>% group_by(risk_band) %>% summarise(n = n()) %>%
      mutate(risk_band = factor(risk_band, levels = c("Low", "Medium", "High"))) %>% arrange(risk_band)
    plot_ly(d, x = ~risk_band, y = ~n, type = "bar",
            marker = list(color = unname(RISK[as.character(d$risk_band)])),
            text = ~format(n, big.mark = ","), textposition = "outside",
            textfont = list(color = MUTED),
            hovertemplate = "%{x} risk<br>%{y:,} customers<extra></extra>") %>%
      base_ly(ytitle = "Customers") %>% layout(title = "Customers by risk band")
  })
  
  output$p_scatter <- renderPlotly({
    ids <- filt()$customer_id
    d <- feats %>% filter(`Customer ID` %in% ids) %>% mutate(Seg = paste("Segment", Segment))
    plot_ly(d, x = ~Recency, y = ~Monetary, color = ~Seg, colors = CAT[1:4],
            size = ~Frequency, sizes = c(30, 500), type = "scatter", mode = "markers",
            marker = list(opacity = 0.65, line = list(width = 1, color = SURF)),
            hovertemplate = "Recency %{x:.0f} days<br>Spend GBP %{y:,.0f}<extra></extra>") %>%
      base_ly(ytitle = "Monetary (GBP, log)", xtitle = "Recency (days)") %>%
      layout(yaxis = list(type = "log", title = "Monetary (GBP, log)", gridcolor = "#eceae4"),
             title = "Segments: recency against spend")
  })
  
  output$t_seg <- renderDT(datatable(segprof, rownames = FALSE,
                                     options = list(dom = "t", pageLength = 10)))
  
  output$p_models <- renderPlotly({
    d <- models %>% arrange(`Test ROC-AUC`)
    plot_ly(d, x = ~`Test ROC-AUC`, y = ~reorder(Model, `Test ROC-AUC`), type = "bar",
            orientation = "h", marker = list(color = CAT[1]),
            text = ~sprintf("%.3f", `Test ROC-AUC`), textposition = "outside",
            textfont = list(color = MUTED),
            hovertemplate = "%{y}<br>AUC %{x:.4f}<extra></extra>") %>%
      base_ly(xtitle = "Test ROC-AUC") %>%
      layout(title = "Churn model comparison", xaxis = list(range = c(0.70, 0.86)))
  })
  
  output$t_models <- renderDT(datatable(models %>% mutate(across(where(is.numeric), ~round(., 4))),
                                        rownames = FALSE, options = list(dom = "t")))
  
  output$p_month <- renderPlotly({
    plot_ly(monthly, x = ~month, y = ~revenue, type = "scatter", mode = "lines+markers",
            line = list(color = CAT[1], width = 2), marker = list(size = 8),
            hovertemplate = "%{x}<br>GBP %{y:,.0f}<extra></extra>") %>%
      base_ly(ytitle = "Revenue (GBP)") %>% layout(title = "Monthly revenue")
  })
  
  output$p_tier <- renderPlotly({
    d <- filt() %>% group_by(value_tier, risk_band) %>%
      summarise(revenue = sum(revenue_at_risk), .groups = "drop") %>%
      mutate(value_tier = factor(value_tier, levels = c("Bronze","Silver","Gold","Platinum")))
    plot_ly(d, x = ~value_tier, y = ~revenue, color = ~risk_band,
            colors = RISK, type = "bar",
            hovertemplate = "%{x}<br>GBP %{y:,.0f}<extra></extra>") %>%
      base_ly(ytitle = "Revenue at risk (GBP)") %>%
      layout(barmode = "group", title = "Revenue at risk by value tier")
  })
  
  output$t_cust <- renderDT({
    datatable(filt() %>%
                select(customer_id, segment, monetary, frequency, recency,
                       churn_probability, risk_band, value_tier,
                       revenue_at_risk, recommended_action) %>%
                arrange(desc(revenue_at_risk)),
              rownames = FALSE, filter = "top",
              options = list(pageLength = 15, scrollX = TRUE)) %>%
      formatRound(c("monetary", "revenue_at_risk"), 2) %>%
      formatRound("churn_probability", 3)
  })
  
  output$dl <- downloadHandler(
    filename = function() "filtered_customers.csv",
    content  = function(file) write_csv(filt(), file)
  )
}

shinyApp(ui, server)
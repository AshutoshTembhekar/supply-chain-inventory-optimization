# ==============================================================================
# Enterprise Supply Chain Analytics: Dynamic Inventory Policy Dashboard
# File: app.R
# Stack: Shiny, bslib, tidyverse, DT, scales, bsicons
# ==============================================================================

library(shiny)
library(bslib)
library(readr)
library(dplyr)
library(tidyr)
library(lubridate)
library(ggplot2)
library(scales)
library(DT)
library(bsicons)

# --- 1. Data Ingestion & Base Aggregation ---
DATA_PATH <- "Warehouse_and_Retail_Sales.csv"

if (!file.exists(DATA_PATH)) {
  stop(paste0("Could not locate '", DATA_PATH, "'. Place app.R in the project root."))
}

raw_df <- read_csv(
  DATA_PATH,
  col_types = cols(
    YEAR = col_integer(),
    MONTH = col_integer(),
    SUPPLIER = col_character(),
    `ITEM CODE` = col_character(),
    `ITEM DESCRIPTION` = col_character(),
    `ITEM TYPE` = col_character(),
    `RETAIL SALES` = col_double(),
    `RETAIL TRANSFERS` = col_double(),
    `WAREHOUSE SALES` = col_double()
  ),
  show_col_types = FALSE
)

# Standardize and calculate total item outflow per month
monthly_sku_base <- raw_df |>
  rename(
    year = YEAR,
    month = MONTH,
    supplier = SUPPLIER,
    item_code = `ITEM CODE`,
    item_desc = `ITEM DESCRIPTION`,
    item_type = `ITEM TYPE`,
    retail_sales = `RETAIL SALES`,
    retail_transfers = `RETAIL TRANSFERS`,
    warehouse_sales = `WAREHOUSE SALES`
  ) |>
  mutate(
    supplier = if_else(is.na(supplier), "UNKNOWN SUPPLIER", supplier),
    item_type = if_else(is.na(item_type), "OTHER", item_type),
    retail_sales = if_else(is.na(retail_sales), 0, retail_sales),
    period = ymd(paste(year, sprintf("%02d", month), "01", sep = "-")),
    total_sales = retail_sales + warehouse_sales,
    total_outflow = total_sales + retail_transfers
  ) |>
  group_by(item_code, item_desc, item_type, supplier, period) |>
  summarize(
    monthly_outflow = sum(total_outflow, na.rm = TRUE),
    .groups = "drop"
  )

# Pre-compute static statistical moments
sku_moments <- monthly_sku_base |>
  group_by(item_code, item_desc, item_type, supplier) |>
  summarize(
    total_demand = sum(monthly_outflow),
    mean_monthly_demand = mean(monthly_outflow),
    std_monthly_demand = sd(monthly_outflow),
    active_months = n_distinct(period),
    .groups = "drop"
  ) |>
  mutate(
    std_monthly_demand = replace_na(std_monthly_demand, 0),
    cv = if_else(mean_monthly_demand > 0, std_monthly_demand / mean_monthly_demand, Inf)
  )

unique_types <- sort(unique(sku_moments$item_type))

# --- 2. User Interface ---
ui <- page_sidebar(
  title = "Supply Chain Inventory Optimization Engine",
  theme = bs_theme(
    version = 5,
    bootswatch = "darkly",
    primary = "#00bc8c",
    base_font = font_google("Inter")
  ),
  sidebar = sidebar(
    title = "Policy Controls",
    sliderInput(
      inputId = "target_service_level",
      label = "Cycle Service Level (CSL):",
      min = 0.80,
      max = 0.999,
      value = 0.95,
      step = 0.005,
      post = "%"
    ),
    sliderInput(
      inputId = "lead_time_months",
      label = "Average Supplier Lead Time (Months):",
      min = 0.5,
      max = 3.0,
      value = 1.0,
      step = 0.1
    ),
    sliderInput(
      inputId = "lead_time_std_months",
      label = "Lead Time Std Dev (Months):",
      min = 0.0,
      max = 1.0,
      value = 0.20,
      step = 0.05
    ),
    hr(),
    numericInput(
      inputId = "unit_cost",
      label = "Est. Avg Unit Cost ($):",
      value = 15.00,
      min = 1.00,
      step = 1.00
    ),
    sliderInput(
      inputId = "carrying_cost_rate",
      label = "Annual Carrying Cost Rate (H):",
      min = 0.10,
      max = 0.40,
      value = 0.22,
      step = 0.01,
      post = "%"
    ),
    hr(),
    selectizeInput(
      inputId = "filter_item_type",
      label = "Filter by Item Type:",
      choices = c("ALL TYPES", unique_types),
      selected = "ALL TYPES",
      multiple = FALSE
    ),
    selectizeInput(
      inputId = "filter_segment",
      label = "Filter ABC-XYZ Segment:",
      choices = c("ALL", "AX", "AY", "AZ", "BX", "BY", "BZ", "CX", "CY", "CZ"),
      selected = "ALL",
      multiple = FALSE
    )
  ),
  
  # KPI Top Cards
  layout_column_wrap(
    width = 1/3,
    value_box(
      title = "Filtered SKUs",
      value = textOutput("kpi_skus"),
      showcase = bsicons::bs_icon("boxes")
    ),
    value_box(
      title = "Computed Z-Score",
      value = textOutput("kpi_zscore"),
      showcase = bsicons::bs_icon("graph-up")
    ),
    value_box(
      title = "Total Safety Stock Buffer",
      value = textOutput("kpi_safety_stock"),
      showcase = bsicons::bs_icon("shield-check")
    ),
    value_box(
      title = "Tied-Up Working Capital",
      value = textOutput("kpi_working_capital"),
      showcase = bsicons::bs_icon("cash-stack"),
      theme = "teal"
    ),
    value_box(
      title = "Annual Carrying / Holding Cost",
      value = textOutput("kpi_holding_cost"),
      showcase = bsicons::bs_icon("piggy-bank"),
      theme = "danger"
    ),
    value_box(
      title = "Total System Outflow",
      value = textOutput("kpi_demand"),
      showcase = bsicons::bs_icon("cart-check")
    )
  ),
  
  # Dashboard Body Tabs
  navset_card_tab(
    nav_panel(
      title = "ABC-XYZ Segmentation",
      card_body(
        plotOutput("matrix_plot", height = "420px")
      )
    ),
    nav_panel(
      title = "Segment SKU Summary",
      card_body(
        tableOutput("matrix_summary_table")
      )
    ),
    nav_panel(
      title = "Item Policy Optimization Explorer",
      card_body(
        DTOutput("sku_table")
      )
    )
  )
)

# --- 3. Server Logic ---
server <- function(input, output, session) {
  
  optimized_data <- reactive({
    data_subset <- sku_moments
    
    if (input$filter_item_type != "ALL TYPES") {
      data_subset <- data_subset |> filter(item_type == input$filter_item_type)
    }
    
    total_vol <- sum(data_subset$total_demand)
    req(total_vol > 0)
    
    z <- qnorm(input$target_service_level)
    l_m <- input$lead_time_months
    l_s <- input$lead_time_std_months
    
    data_subset |>
      arrange(desc(total_demand)) |>
      mutate(
        cumulative_demand = cumsum(total_demand),
        cum_share = cumulative_demand / total_vol,
        abc_class = case_when(
          cum_share <= 0.80 ~ "A",
          cum_share <= 0.95 ~ "B",
          TRUE              ~ "C"
        ),
        xyz_class = case_when(
          cv <= 0.50 ~ "X",
          cv <= 1.00 ~ "Y",
          TRUE       ~ "Z"
        ),
        segment = paste0(abc_class, xyz_class),
        var_demand = l_m * (std_monthly_demand^2),
        var_leadtime = (mean_monthly_demand^2) * (l_s^2),
        safety_stock = ceiling(z * sqrt(var_demand + var_leadtime)),
        reorder_point = ceiling((mean_monthly_demand * l_m) + safety_stock)
      ) |>
      select(-var_demand, -var_leadtime)
  })
  
  table_data <- reactive({
    df <- optimized_data()
    if (input$filter_segment != "ALL") {
      df <- df |> filter(segment == input$filter_segment)
    }
    df
  })
  
  # KPI Renderers
  output$kpi_skus <- renderText({
    comma(nrow(table_data()))
  })
  
  output$kpi_zscore <- renderText({
    sprintf("%.3f", qnorm(input$target_service_level))
  })
  
  output$kpi_safety_stock <- renderText({
    comma(sum(table_data()$safety_stock, na.rm = TRUE))
  })
  
  output$kpi_working_capital <- renderText({
    req(nrow(table_data()) > 0)
    total_ss <- sum(table_data()$safety_stock, na.rm = TRUE)
    dollar(total_ss * input$unit_cost, accuracy = 1)
  })
  
  output$kpi_holding_cost <- renderText({
    req(nrow(table_data()) > 0)
    total_ss <- sum(table_data()$safety_stock, na.rm = TRUE)
    carrying_cost <- (total_ss * input$unit_cost) * input$carrying_cost_rate
    dollar(carrying_cost, accuracy = 1)
  })
  
  output$kpi_demand <- renderText({
    comma(sum(table_data()$total_demand, na.rm = TRUE))
  })
  
  # Plot
  output$matrix_plot <- renderPlot({
    df <- optimized_data()
    req(nrow(df) > 0)
    
    ggplot(df, aes(x = abc_class, fill = xyz_class)) +
      geom_bar(position = "dodge", color = "black", alpha = 0.85) +
      scale_fill_brewer(palette = "Set1") +
      theme_minimal(base_size = 14) +
      theme(
        text = element_text(color = "white"),
        axis.text = element_text(color = "gray85"),
        panel.grid.major = element_line(color = "gray30"),
        panel.grid.minor = element_blank()
      ) +
      labs(
        title = "Dynamic ABC-XYZ Matrix Distribution",
        subtitle = paste0(
          "Service Level: ", input$target_service_level * 100, 
          "% | Z-Score: ", round(qnorm(input$target_service_level), 3)
        ),
        x = "ABC Classification (Volume Contribution)",
        y = "Count of SKUs",
        fill = "XYZ Volatility Tier"
      ) +
      scale_y_continuous(labels = comma)
  })
  
  # Summary Table
  output$matrix_summary_table <- renderTable({
    optimized_data() |>
      count(abc_class, xyz_class) |>
      pivot_wider(names_from = xyz_class, values_from = n, values_fill = 0) |>
      arrange(abc_class)
  }, striped = TRUE, hover = TRUE, bordered = TRUE)
  
  # Interactive SKU Table
  output$sku_table <- renderDT({
    table_data() |>
      mutate(
        tied_capital = safety_stock * input$unit_cost,
        annual_holding_cost = tied_capital * input$carrying_cost_rate
      ) |>
      select(
        `Item Code` = item_code,
        `Description` = item_desc,
        `Type` = item_type,
        `Segment` = segment,
        `Mean Monthly Demand` = mean_monthly_demand,
        `Safety Stock (Units)` = safety_stock,
        `Capital Tied Up ($)` = tied_capital,
        `Annual Holding Cost ($)` = annual_holding_cost,
        `Reorder Point (ROP)` = reorder_point
      ) |>
      datatable(
        options = list(pageLength = 10, autoWidth = TRUE),
        rownames = FALSE
      ) |>
      formatRound("Mean Monthly Demand", 1) |>
      formatCurrency(c("Capital Tied Up ($)", "Annual Holding Cost ($)"), "$", digits = 0) |>
      formatCurrency(c("Safety Stock (Units)", "Reorder Point (ROP)"), currency = "", mark = ",", digits = 0)
  })
}

# --- 4. Launch Application ---
shinyApp(ui = ui, server = server)
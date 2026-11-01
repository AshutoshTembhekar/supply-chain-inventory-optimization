# ==============================================================================
# Enterprise Supply Chain Analytics: ABC-XYZ & Inventory Optimization Engine
# Stack: R (tidyverse, lubridate, scales)
# ==============================================================================

# 1. Load Required Libraries
suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(lubridate)
  library(tidyr)
  library(ggplot2)
  library(scales)
})

# Define Output Directories
dir.create(path = "output", showWarnings = FALSE)

# ==============================================================================
# 2. Pipeline Configuration Parameters
# ==============================================================================
cfg <- list(
  input_path = "Warehouse_and_Retail_Sales.csv",
  target_service_level = 0.95,
  default_lead_time_months = 1.0,
  lead_time_std_months = 0.20
)

# Derive Z-score dynamically
z_score <- qnorm(cfg$target_service_level)
message(sprintf(
  "Target Service Level: %.1f%% (Z-score: %.3f)",
  cfg$target_service_level * 100,
  z_score
))

# ==============================================================================
# 3. Data Ingestion & Sanitization
# ==============================================================================
message("Ingesting raw transaction logs...")

raw_df <- read_csv(
  cfg$input_path,
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

message(sprintf(
  "Loaded %s records across %s unique SKUs.",
  comma(nrow(raw_df)),
  comma(n_distinct(raw_df$`ITEM CODE`))
))

# Clean and standardize column names & missing values
cleaned_df <- raw_df |>
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
  )

# ==============================================================================
# 4. ABC-XYZ Segmentation Engine
# ==============================================================================
message("Computing Monthly Demand & Volatility Metrics...")

# Aggregate to SKU-Month level
monthly_sku <- cleaned_df |>
  group_by(item_code, item_desc, item_type, supplier, period) |>
  summarize(
    monthly_outflow = sum(total_outflow, na.rm = TRUE),
    .groups = "drop"
  )

# Calculate Item-Level Statistical Moments
sku_stats <- monthly_sku |>
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
    cv = if_else(
      mean_monthly_demand > 0,
      std_monthly_demand / mean_monthly_demand,
      Inf
    )
  )

# --- Step 4a: ABC Classification (Pareto Demand Concentration) ---
total_system_volume <- sum(sku_stats$total_demand)

sku_abc_xyz <- sku_stats |>
  arrange(desc(total_demand)) |>
  mutate(
    cumulative_demand = cumsum(total_demand),
    cum_share = cumulative_demand / total_system_volume,
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
    segment = paste0(abc_class, xyz_class)
  )

# ==============================================================================
# 5. Stochastic Safety Stock & Reorder Point (ROP) Modeling
# ==============================================================================
message("Calculating Dynamic Safety Stock and Reorder Points...")

l_m <- cfg$default_lead_time_months
l_s <- cfg$lead_time_std_months

sku_optimized <- sku_abc_xyz |>
  mutate(
    var_demand = l_m * (std_monthly_demand^2),
    var_leadtime = (mean_monthly_demand^2) * (l_s^2),
    safety_stock = ceiling(z_score * sqrt(var_demand + var_leadtime)),
    reorder_point = ceiling((mean_monthly_demand * l_m) + safety_stock)
  ) |>
  select(-var_demand, -var_leadtime)

# ==============================================================================
# 6. Summary Reporting & Data Export
# ==============================================================================
matrix_summary <- sku_optimized |>
  count(abc_class, xyz_class) |>
  pivot_wider(names_from = xyz_class, values_from = n, values_fill = 0) |>
  arrange(abc_class)

message("\n=== ABC-XYZ SKU Distribution Matrix ===")
print(matrix_summary)

# Write Out CSVs
write_csv(sku_optimized, "output/sku_inventory_optimization.csv")
write_csv(matrix_summary, "output/abc_xyz_matrix_summary.csv")
message("\nProcessed dataset written to output/sku_inventory_optimization.csv")

# ==============================================================================
# 7. Visualization: Pareto Curve & ABC Breakdown
# ==============================================================================
p <- ggplot(sku_optimized, aes(x = abc_class, fill = xyz_class)) +
  geom_bar(position = "dodge", color = "black", alpha = 0.85) +
  scale_fill_brewer(palette = "Set1") +
  theme_minimal(base_size = 13) +
  labs(
    title = "Supply Chain Demand Segmentation: ABC-XYZ Matrix",
    subtitle = paste0(
      "Total SKUs: ", comma(nrow(sku_optimized)),
      " | Service Level: ", cfg$target_service_level * 100, "%"
    ),
    x = "ABC Classification (Volume Contribution)",
    y = "Count of SKUs",
    fill = "XYZ Volatility Tier"
  ) +
  scale_y_continuous(labels = comma)

ggsave(
  filename = "output/eda_abc_xyz_distribution.png",
  plot = p,
  width = 9,
  height = 6,
  dpi = 300
)
message("Saved chart: output/eda_abc_xyz_distribution.png")

# Supply Chain Inventory Optimization

### ABC-XYZ Demand Segmentation & Stochastic Inventory Policy Engine

An end-to-end R analytics pipeline and interactive Shiny application for SKU-level demand segmentation, stochastic Safety Stock calculation, dynamic Reorder Point (ROP) analysis, and inventory working-capital estimation.

The project uses historical warehouse and retail movement data to examine demand concentration, demand variability, and how different service-level and supplier lead-time assumptions affect inventory requirements.

---

## 1. Project Overview

Managing a large SKU portfolio creates a challenge for inventory planning.

High-volume products require careful replenishment planning to reduce stockout exposure. Meanwhile, products with low or unpredictable demand may require different inventory policies to avoid holding more stock than necessary.

This project develops an analytical workflow to:

- Analyze historical SKU-level outbound movement.
- Classify products using ABC analysis based on cumulative outbound volume.
- Evaluate demand variability using XYZ segmentation.
- Calculate Safety Stock using demand and supplier lead-time variability.
- Estimate Reorder Points based on target Cycle Service Levels.
- Explore inventory policy trade-offs through an interactive Shiny application.
- Estimate the working-capital implications of modeled safety-stock requirements.

**Project objective:** Build a data-driven inventory analysis framework that connects SKU demand characteristics with replenishment policy assumptions.

## 2. Executive Summary & Key Findings

The analysis covers **38,236 SKUs** and identifies substantial concentration in outbound volume, alongside variation in SKU-level demand predictability.

### Portfolio-level results

| Metric | Result |
|---|---:|
| Total SKUs analyzed | 38,236 |
| Class A SKUs | 1,486 |
| Class A share of catalog | 3.9% |
| Class AX SKUs | 1,182 |
| Class AY/AZ SKUs | 304 |
| Class C SKUs | 33,690 |
| Class C share of catalog | 88.1% |
| Class CZ SKUs | 4,499 |

### Key findings

**1. Demand concentration — Class A**

A total of 1,486 SKUs, representing approximately 3.9% of the catalog, account for over 80% of aggregate outbound volume.

Within this group, 1,182 SKUs are classified as AX, combining high volume contribution with relatively stable demand.

These products are candidates for closer replenishment monitoring and more consistent inventory policy evaluation.

**2. High-volume demand variability — AY/AZ**

A total of 304 SKUs fall into the AY and AZ segments.

These products have high volume contribution but comparatively greater demand variability. Their replenishment requirements may therefore be more sensitive to changes in demand and supplier lead times.

**3. Long-tail inventory — Class C**

Class C contains 33,690 SKUs, approximately 88.1% of the catalog, while contributing less than 5% of aggregate outbound volume.

Of these, 4,499 SKUs fall into the CZ segment, indicating low-volume and highly variable demand.

This segment is worth investigating for alternative replenishment approaches, subject to operational constraints and actual inventory costs.

> These findings describe the analyzed dataset. Suggested inventory strategies are analytical opportunities, not measured operational savings or guaranteed improvements.

---

## 3. Analytical Architecture

The workflow consists of a batch analytics pipeline followed by an interactive Shiny application.

```mermaid
flowchart TD
    A["Warehouse & Retail Transaction Data"] --> B["Data Ingestion & Cleaning"]
    B --> C["Monthly SKU Demand Aggregation"]
    C --> D["ABC Demand Segmentation"]
    C --> E["XYZ Variability Segmentation"]
    D --> F["Combined ABC-XYZ Classification"]
    E --> F
    F --> G["Safety Stock Calculation"]
    G --> H["Reorder Point Calculation"]
    H --> I["CSV Analytical Outputs"]
    H --> J["Shiny Simulation Application"]
    I --> K["Summary Tables & Visualization"]
    J --> L["Service-Level Analysis"]
    J --> M["Lead-Time Sensitivity"]
    J --> N["Working-Capital Estimates"]
    J --> O["SKU-Level Policy Explorer"]
```

### Pipeline components

| Component | Responsibility |
|---|---|
| Data ingestion | Loads and prepares transaction records |
| Demand aggregation | Aggregates SKU activity at monthly intervals |
| ABC analysis | Classifies SKUs by cumulative outbound volume |
| XYZ analysis | Evaluates demand variability using the Coefficient of Variation |
| Inventory modeling | Calculates Safety Stock and Reorder Points |
| Batch outputs | Generates classification summaries and SKU-level results |
| Shiny application | Allows interactive evaluation of inventory assumptions |

---


## 4. Methodology

The project follows a structured analytical workflow, moving from transaction-level data preparation to SKU classification, inventory policy calculations and financial scenario analysis.

### 4.1 End-to-End Analytical Workflow

```mermaid
flowchart TD
    A["Warehouse and Retail Transaction Data"]
    B["Data Cleaning and Preparation"]
    C["Monthly Outbound Demand Aggregation"]
    D["SKU-Level Demand Statistics"]
    E["ABC Classification"]
    F["XYZ Classification"]
    G["Combined ABC-XYZ Segmentation"]
    H["Safety Stock Calculation"]
    I["Reorder Point Calculation"]
    J["Inventory Cost Estimation"]
    K["CSV Analytical Outputs"]
    L["Interactive Shiny Application"]

    A --> B --> C --> D
    D --> E
    D --> F
    E --> G
    F --> G
    G --> H --> I
    I --> J
    I --> K
    J --> L
    K --> L
```

### 4.2 Data Preparation and Demand Aggregation

```mermaid
flowchart TD
    A["Raw Transaction Dataset"]
    B["Standardize Column Names"]
    C["Handle Selected Missing Values"]
    D["Calculate Total Outbound Movement"]
    E["Aggregate by Item Attributes and Month"]
    F["Calculate SKU Demand Statistics"]

    A --> B --> C --> D --> E --> F
```

The pipeline calculates outbound movement using retail sales, warehouse sales and retail transfers.

**Data limitation:** The current implementation aggregates months present in the transaction records. It does not explicitly generate missing SKU-month combinations with zero demand. This can affect demand variability estimates, particularly for intermittent products.

### 4.3 ABC Classification — Demand Concentration

ABC analysis ranks item groupings according to total outbound volume and assigns categories based on cumulative volume contribution.

```mermaid
flowchart TD
    A["Calculate Total Outbound Volume per Item"]
    B["Sort Items by Descending Volume"]
    C["Calculate Cumulative Volume Share"]
    D{"Cumulative Volume Share"}
    E["Class A: Up to 80%"]
    F["Class B: Above 80% to 95%"]
    G["Class C: Above 95%"]

    A --> B --> C --> D
    D -->|Up to 80%| E
    D -->|Above 80% to 95%| F
    D -->|Above 95%| G
```

| Class | Cumulative Volume Contribution | Interpretation |
|---|---:|---|
| A | First 80% | High-volume contributors |
| B | Next 15% | Medium-volume contributors |
| C | Remaining 5% | Low-volume contributors |

**Interpretation:** ABC classification is based on outbound volume, not revenue, profitability or inventory value. Actual category contributions may differ slightly from the nominal thresholds because classification is applied sequentially to ranked items.

### 4.4 XYZ Classification — Demand Variability

XYZ analysis evaluates the variability of observed monthly demand using the Coefficient of Variation.

```mermaid
flowchart TD
    A["Monthly SKU Demand Records"]
    B["Calculate Mean Monthly Demand"]
    C["Calculate Standard Deviation"]
    D["Calculate Coefficient of Variation"]
    E{"CV Threshold"}
    F["X: CV at or below 0.50"]
    G["Y: CV above 0.50 and at or below 1.00"]
    H["Z: CV above 1.00"]

    A --> B
    A --> C
    B --> D
    C --> D
    D --> E
    E -->|Stable| F
    E -->|Moderate Variability| G
    E -->|High Variability| H
```

| Class | CV Range | Interpretation |
|---|---|---|
| X | CV ≤ 0.50 | Relatively stable observed demand |
| Y | 0.50 < CV ≤ 1.00 | Moderately variable observed demand |
| Z | CV > 1.00 | Highly variable observed demand |

The project combines the ABC and XYZ classifications into nine segments:

```mermaid
flowchart TD
    A["ABC Classification"]
    B["XYZ Classification"]
    C["Combine Both Classifications"]
    D["AX | AY | AZ"]
    E["BX | BY | BZ"]
    F["CX | CY | CZ"]

    A --> C
    B --> C
    C --> D
    C --> E
    C --> F
```

**Data limitation:** Missing SKU-month combinations are not explicitly filled with zero demand in the current implementation. Intermittent demand may therefore be understated, affecting the resulting XYZ classifications.

### 4.5 Stochastic Safety Stock Calculation

The Safety Stock model accounts for two sources of uncertainty:

- Variation in monthly demand.
- Variation in supplier lead time.

```mermaid
flowchart TD
    A["Historical Monthly Demand"]
    B["Mean Monthly Demand"]
    C["Demand Standard Deviation"]
    D["Supplier Lead-Time Assumptions"]
    E["Average Lead Time"]
    F["Lead-Time Standard Deviation"]
    G["Target Cycle Service Level"]
    H["Calculate Z-Score"]
    I["Demand Variability Component"]
    J["Lead-Time Variability Component"]
    K["Combine Variance Components"]
    L["Calculate Safety Stock"]
    M["Round Up to Whole Units"]

    A --> B
    A --> C
    D --> E
    D --> F
    G --> H
    B --> I
    C --> I
    E --> I
    B --> J
    F --> J
    I --> K
    J --> K
    H --> L
    K --> L
    L --> M
```

The implemented model uses:

```r
z_score <- qnorm(target_service_level)

safety_stock <- ceiling(
  z_score * sqrt(
    avg_lead_time * demand_variance +
      mean_monthly_demand^2 * lead_time_variance
  )
)
```

The model assumes demand and lead-time variability can be combined using an independence approximation.

Demand is measured in units per month, while lead time and its standard deviation must be expressed in months.

The calculation uses a normal-quantile service-level multiplier and does not guarantee the realized service level.

### 4.6 Reorder Point Calculation

The Reorder Point combines expected demand during supplier lead time with the calculated Safety Stock.

```mermaid
flowchart TD
    A["Mean Monthly Demand"]
    B["Average Supplier Lead Time"]
    C["Expected Demand During Lead Time"]
    D["Calculated Safety Stock"]
    E["Combine Both Components"]
    F["Round Up to Whole Units"]
    G["Final Reorder Point"]

    A --> C
    B --> C
    C --> E
    D --> E
    E --> F
    F --> G
```

The batch pipeline uses configured baseline assumptions:

| Parameter | Baseline Value |
|---|---:|
| Target Cycle Service Level | 95% |
| Average Lead Time | 1.0 month |
| Lead-Time Standard Deviation | 0.20 months |

These are model configuration assumptions, not supplier-specific measurements.

### 4.7 Inventory Cost Estimation

The Shiny application estimates the financial implications of the calculated Safety Stock.

```mermaid
flowchart TD
    A["Calculated Safety Stock by Item"]
    B["Aggregate Safety Stock Units"]
    C["User-Entered Average Unit Cost"]
    D["Estimate Safety Stock Capital"]
    E["User-Selected Carrying-Cost Rate"]
    F["Estimate Annual Carrying Cost"]
    G["Display Financial Scenario Results"]

    A --> B
    B --> D
    C --> D
    D --> F
    E --> F
    F --> G
```

The application uses a single average unit-cost input across the selected items rather than SKU-specific purchase costs.

The carrying-cost rate is a scenario assumption. These outputs are illustrative estimates, not audited inventory valuation or measured working-capital savings.

### 4.8 Methodology Limitations

| Area | Limitation |
|---|---|
| Demand aggregation | Missing SKU-month combinations are not explicitly generated with zero demand |
| Item grouping | Item attributes can cause the same item code to be represented by multiple groupings |
| ABC classification | Actual category contributions can differ slightly from nominal thresholds |
| Lead-time modeling | Baseline calculations use configured assumptions rather than historical supplier-specific distributions |
| Statistical assumptions | Demand and lead-time variability use an independence approximation |
| Cost estimation | Financial estimates depend on a single average unit-cost input and an assumed carrying-cost rate |
| Historical data | Past outbound movement does not guarantee future demand behavior |

The framework is intended for analytical exploration and inventory policy evaluation. Operational deployment would require validation against complete demand histories, actual supplier lead times, SKU-level costs and realized inventory performance.

---

## 5. Interactive Shiny Simulation

The project includes an interactive Shiny application for exploring inventory policy assumptions and their effects on calculated inventory requirements.

### Simulation capabilities

**Cycle Service Level Control**

Adjust target service levels from 80% to 99.9% and examine how the Safety Stock requirement changes.

**Lead-Time Sensitivity**

Explore the effect of supplier lead-time assumptions and variability on replenishment requirements.

**Working Capital Analysis**

Examine estimated Safety Stock capital under different inventory policy assumptions.

**Holding Cost Evaluation**

Evaluate how different carrying-cost assumptions affect modeled annual holding costs.

**SKU-Level Policy Explorer**

Search and inspect individual SKU-level inventory outputs through an interactive DT data table.

The application is intended for analytical exploration. Its outputs depend on the input data and assumptions used in the underlying model.

---

## 6. Analytical Visualization

### ABC-XYZ Segmentation Distribution

![ABC-XYZ Distribution](eda_abc_xyz_distribution.png)

*Distribution of SKUs across ABC-XYZ demand segments.*

The visualization provides an overview of how the analyzed SKU portfolio is distributed across volume-contribution and demand-variability categories.

---

## 7. Dataset

The project uses the **Montgomery County Warehouse and Retail Sales** dataset.

The raw transaction file is not included in this repository because of its size.

**Dataset source:** Kaggle

To locate the dataset, search Kaggle for:

`Montgomery County Warehouse and Retail Sales`

Download the source file and place it in the project root directory.

The expected filename is:

`Warehouse_and_Retail_Sales.csv`

The pipeline requires the source file to be available locally before execution.

---

## Repository Structure

```mermaid
flowchart TD
    A["supply-chain-inventory-optimization/"] --> B["README.md"]
    A --> C["supply_chain_pipeline.R"]
    A --> D["app.R"]
    A --> E["sku_inventory_optimization.csv"]
    A --> F["abc_xyz_matrix_summary.csv"]
    A --> G["eda_abc_xyz_distribution.png"]
    A --> H[".lintr"]
```


---

| File | Description |
|---|---|
| `supply_chain_pipeline.R` | Data processing, demand segmentation, and inventory calculations |
| `app.R` | Interactive Shiny application |
| `abc_xyz_matrix_summary.csv` | ABC-XYZ classification summary |
| `eda_abc_xyz_distribution.png` | Segmentation distribution visualization |
| `sku_inventory_optimization.csv` | SKU-level inventory policy outputs |
| `.lintr` | R linting configuration |
| `README.md` | Project documentation |

**Note:** The source dataset, `Warehouse_and_Retail_Sales.csv`, must be downloaded separately and is not included in the repository.

---

## 9. Technology Stack

| Technology | Purpose |
|---|---|
| R | Core analytics and data processing |
| tidyverse | Data manipulation and transformation |
| lubridate | Date and time handling |
| scales | Visualization formatting |
| Shiny | Interactive application development |
| bslib | Dashboard interface and styling |
| DT | Interactive SKU-level data tables |
| bsicons | Interface icons |

---

## 10. Setup & Execution

### Prerequisites

- R version 4.2.0 or higher
- RStudio (recommended)
- Source dataset: `Warehouse_and_Retail_Sales.csv`

### Step 1 — Clone the repository

```bash
git clone https://github.com/AshutoshTembhekar/supply-chain-inventory-optimization.git

cd supply-chain-inventory-optimization
```

### Step 2 — Install dependencies

Open R or RStudio and execute:

```r
install.packages(c(
  "tidyverse",
  "lubridate",
  "scales",
  "shiny",
  "bslib",
  "DT",
  "bsicons"
))
```

### Step 3 — Add the source dataset

Download the Montgomery County Warehouse and Retail Sales dataset from Kaggle.

Place the downloaded CSV file in the repository root directory.

Ensure the filename is:

```text
Warehouse_and_Retail_Sales.csv
```

### Step 4 — Run the analytical pipeline

Execute:

```r
source("supply_chain_pipeline.R")
```

The pipeline processes the source data and generates the analytical outputs, including the ABC-XYZ summary, distribution visualization, and SKU-level inventory optimization results.

### Step 5 — Launch the Shiny application

Run:

```r
shiny::runApp("app.R")
```

The Shiny application should open in your default browser.

---

## 11. Limitations & Modeling Assumptions

The results should be interpreted in the context of the following limitations:

- The analysis depends on the quality, completeness, and temporal coverage of the source transaction data.
- ABC classifications are based on historical outbound volume, not revenue or profitability.
- XYZ classification depends on the monthly aggregation period and selected CV thresholds.
- Historical demand patterns may not represent future demand behavior.
- The stochastic Safety Stock formulation uses an independence approximation between demand and supplier lead-time variability.
- The model assumes compatible units for demand and lead-time inputs.
- Replenishment recommendations are analytical outputs and should be evaluated against actual supplier constraints, operational policies, and inventory conditions.
- Working-capital and holding-cost estimates depend on the unit-cost basis and carrying-cost assumptions.
- The model should be validated against actual replenishment and stockout history before being used for operational decisions.

---

## 12. Potential Extensions

Potential areas for further development include:

- Integrating demand forecasting into inventory planning.
- Introducing SKU-specific service-level policies.
- Comparing alternative Safety Stock and inventory optimization models.
- Adding supplier performance and lead-time reliability analysis.
- Extending the dashboard with historical demand trends and inventory risk monitoring.
- Evaluating replenishment policies through backtesting and simulated stockout scenarios.

---

## Author

**Ashutosh Tembhekar**

Supply Chain Analytics | Data Analytics | Statistical Modeling

- GitHub: [AshutoshTembhekar](https://github.com/AshutoshTembhekar)
- LinkedIn: [Ashutosh Tembhekar](https://www.linkedin.com/in/ashutoshtembhekar/)

---


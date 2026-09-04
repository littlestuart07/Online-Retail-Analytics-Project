library(DBI)
library(RSQLite)
library(dplyr)
library(readxl)
library(lubridate)

setwd("C:/Users/Suyash/Desktop/pods da/Digital Assignment 1")

# ============================================================
# REBUILD CLEANED DATA (same as DA1 pipeline)
# ============================================================
retail_2009_2010 <- read_excel("online_retail_II.xlsx", sheet = "Year 2009-2010")
retail_2010_2011 <- read_excel("online_retail_II.xlsx", sheet = "Year 2010-2011")
retail <- rbind(retail_2009_2010, retail_2010_2011)

retail_clean <- retail %>% filter(!is.na(`Customer ID`))
retail_clean <- retail_clean %>% distinct()
retail_clean <- retail_clean %>% filter(!grepl("^C", Invoice))
retail_clean <- retail_clean %>% filter(Quantity > 0, Price > 0)
retail_clean$InvoiceDate <- as_datetime(retail_clean$InvoiceDate)

Q1 <- quantile(retail_clean$Quantity, 0.25)
Q3 <- quantile(retail_clean$Quantity, 0.75)
IQR_val <- IQR(retail_clean$Quantity)
upper_bound <- Q3 + 1.5 * IQR_val
retail_clean <- retail_clean %>% mutate(Is_Outlier_Qty = ifelse(Quantity > upper_bound, 1L, 0L))

cat("Cleaned transactions:", nrow(retail_clean), "\n")

# ============================================================
# BUILD RFM + TARGETS
# ============================================================
cutoff_date <- max(retail_clean$InvoiceDate) - days(90)
pre_cutoff  <- retail_clean %>% filter(InvoiceDate <= cutoff_date)
post_cutoff <- retail_clean %>% filter(InvoiceDate > cutoff_date)
returned_customers <- unique(as.character(post_cutoff$`Customer ID`))

rfm <- pre_cutoff %>%
  group_by(`Customer ID`) %>%
  summarise(
    Recency       = as.numeric(difftime(cutoff_date, max(InvoiceDate), units = "days")),
    Frequency     = n_distinct(Invoice),
    Monetary      = sum(Quantity * Price),
    AvgOrderValue = Monetary / Frequency,
    AvgQuantity   = mean(Quantity),
    TotalQuantity = sum(Quantity),
    OutlierOrders = sum(Is_Outlier_Qty),
    Country       = names(sort(table(Country), decreasing = TRUE))[1],
    .groups = "drop"
  ) %>%
  mutate(
    Churn     = ifelse(as.character(`Customer ID`) %in% returned_customers, 0L, 1L),
    HighValue = ifelse(Monetary >= quantile(Monetary, 0.80), 1L, 0L)
  )

rfm_scaled <- scale(rfm[, c("Recency", "Frequency", "Monetary")])
set.seed(42)
km <- kmeans(rfm_scaled, centers = 4, nstart = 25)
rfm$Segment <- km$cluster

top_countries <- rfm %>% count(Country, sort = TRUE) %>% head(5) %>% pull(Country)
rfm <- rfm %>% mutate(CountryGroup = ifelse(Country %in% top_countries, Country, "Other"))

# ============================================================
# NORMALIZED SCHEMA DESIGN
# ============================================================
db_path <- "da2_retail_normalized.sqlite"
if (file.exists(db_path)) file.remove(db_path)
con <- dbConnect(RSQLite::SQLite(), db_path)

cat("\n=== CREATING NORMALIZED SCHEMA WITH PRIMARY & FOREIGN KEYS ===\n")

dbExecute(con, "
CREATE TABLE customers (
  customer_id    INTEGER PRIMARY KEY,
  country        TEXT NOT NULL,
  country_group  TEXT NOT NULL,
  recency        REAL,
  frequency      INTEGER,
  monetary       REAL,
  avg_order_value REAL,
  avg_quantity   REAL,
  total_quantity REAL,
  outlier_orders INTEGER,
  churn          INTEGER CHECK (churn IN (0,1)),
  high_value     INTEGER CHECK (high_value IN (0,1)),
  segment        INTEGER CHECK (segment BETWEEN 1 AND 4)
)")
cat("Created table: customers (PK = customer_id, CHECK constraints on targets)\n")

dbExecute(con, "
CREATE TABLE products (
  stock_code   TEXT PRIMARY KEY,
  description  TEXT,
  avg_price    REAL
)")
cat("Created table: products (PK = stock_code)\n")

dbExecute(con, "
CREATE TABLE transactions (
  transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoice        TEXT NOT NULL,
  stock_code     TEXT NOT NULL,
  customer_id    INTEGER NOT NULL,
  quantity       INTEGER NOT NULL CHECK (quantity > 0),
  price          REAL NOT NULL CHECK (price > 0),
  invoice_date   TEXT NOT NULL,
  revenue        REAL NOT NULL,
  is_outlier     INTEGER,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
  FOREIGN KEY (stock_code)  REFERENCES products(stock_code)
)")
cat("Created table: transactions (PK = transaction_id, FK -> customers, FK -> products)\n")

# ============================================================
# POPULATE TABLES
# ============================================================
customers_tbl <- rfm %>%
  transmute(
    customer_id     = as.integer(as.character(`Customer ID`)),
    country         = Country,
    country_group   = CountryGroup,
    recency         = Recency,
    frequency       = as.integer(Frequency),
    monetary        = Monetary,
    avg_order_value = AvgOrderValue,
    avg_quantity    = AvgQuantity,
    total_quantity  = TotalQuantity,
    outlier_orders  = as.integer(OutlierOrders),
    churn           = Churn,
    high_value      = HighValue,
    segment         = as.integer(Segment)
  )
dbWriteTable(con, "customers", as.data.frame(customers_tbl), append = TRUE, row.names = FALSE)
cat("\nPopulated customers:", nrow(customers_tbl), "rows\n")

products_tbl <- retail_clean %>%
  group_by(StockCode) %>%
  summarise(description = first(Description), avg_price = mean(Price), .groups = "drop") %>%
  transmute(stock_code = StockCode, description, avg_price)
dbWriteTable(con, "products", as.data.frame(products_tbl), append = TRUE, row.names = FALSE)
cat("Populated products:", nrow(products_tbl), "rows\n")

valid_customers <- customers_tbl$customer_id
transactions_tbl <- retail_clean %>%
  mutate(customer_id = as.integer(as.character(`Customer ID`))) %>%
  filter(customer_id %in% valid_customers) %>%
  transmute(
    invoice      = Invoice,
    stock_code   = StockCode,
    customer_id  = customer_id,
    quantity     = as.integer(Quantity),
    price        = Price,
    invoice_date = format(InvoiceDate, "%Y-%m-%d %H:%M:%S"),
    revenue      = Quantity * Price,
    is_outlier   = Is_Outlier_Qty
  )
dbWriteTable(con, "transactions", as.data.frame(transactions_tbl), append = TRUE, row.names = FALSE)
cat("Populated transactions:", nrow(transactions_tbl), "rows\n")

# ============================================================
# INDEXES + PERFORMANCE BENCHMARK
# ============================================================
cat("\n=== INDEX PERFORMANCE BENCHMARK ===\n")

bench_query <- "
SELECT c.segment, COUNT(DISTINCT t.customer_id) AS n_customers,
       ROUND(SUM(t.revenue), 2) AS total_revenue
FROM transactions t
JOIN customers c ON t.customer_id = c.customer_id
GROUP BY c.segment"

t0 <- Sys.time(); invisible(dbGetQuery(con, bench_query)); t_before <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cat(sprintf("Query time WITHOUT indexes: %.4f seconds\n", t_before))

dbExecute(con, "CREATE INDEX idx_trans_customer ON transactions(customer_id)")
dbExecute(con, "CREATE INDEX idx_trans_stock    ON transactions(stock_code)")
dbExecute(con, "CREATE INDEX idx_trans_date     ON transactions(invoice_date)")
dbExecute(con, "CREATE INDEX idx_cust_segment   ON customers(segment)")
dbExecute(con, "CREATE INDEX idx_cust_churn     ON customers(churn)")
cat("Created 5 indexes on join/filter columns\n")

t0 <- Sys.time(); invisible(dbGetQuery(con, bench_query)); t_after <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cat(sprintf("Query time WITH indexes:    %.4f seconds\n", t_after))
cat(sprintf("Speedup: %.2fx faster\n", t_before / t_after))

cat("\n=== SCHEMA SUMMARY ===\n")
print(dbGetQuery(con, "SELECT name, type FROM sqlite_master WHERE type IN ('table','index') ORDER BY type, name"))

dbDisconnect(con)
cat("\nNormalized database created: da2_retail_normalized.sqlite\n")
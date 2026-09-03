install.packages(c("DBI", "RSQLite"), type = "binary")
library(readxl)
library(dplyr)
library(lubridate)
library(DBI)
library(RSQLite)

setwd("C:/Users/Suyash/Desktop/pods da/Digital Assignment 1")
retail_2009_2010 <- read_excel("online_retail_II.xlsx", sheet = "Year 2009-2010")
retail_2010_2011 <- read_excel("online_retail_II.xlsx", sheet = "Year 2010-2011")
retail <- rbind(retail_2009_2010, retail_2010_2011)

retail_clean <- retail %>% filter(!is.na(`Customer ID`))
retail_clean <- retail_clean %>% distinct()
retail_clean <- retail_clean %>% filter(!grepl("^C", Invoice))
retail_clean <- retail_clean %>% filter(Quantity > 0, Price > 0)
retail_clean$InvoiceDate <- as_datetime(retail_clean$InvoiceDate)
retail_clean$`Customer ID` <- as.factor(retail_clean$`Customer ID`)

Q1 <- quantile(retail_clean$Quantity, 0.25)
Q3 <- quantile(retail_clean$Quantity, 0.75)
IQR_val <- IQR(retail_clean$Quantity)
upper_bound <- Q3 + 1.5 * IQR_val
retail_clean <- retail_clean %>%
  mutate(Is_Outlier_Qty = ifelse(Quantity > upper_bound, TRUE, FALSE))

dim(retail_clean)

cutoff_date <- max(retail_clean$InvoiceDate) - days(90)

pre_cutoff  <- retail_clean %>% filter(InvoiceDate <= cutoff_date)
post_cutoff <- retail_clean %>% filter(InvoiceDate > cutoff_date)
returned_customers <- unique(as.character(post_cutoff$`Customer ID`))

rfm <- pre_cutoff %>%
  group_by(`Customer ID`) %>%
  summarise(
    Recency        = as.numeric(difftime(cutoff_date, max(InvoiceDate), units = "days")),
    Frequency      = n_distinct(Invoice),
    Monetary       = sum(Quantity * Price),
    AvgOrderValue  = Monetary / Frequency,
    AvgQuantity    = mean(Quantity),
    TotalQuantity  = sum(Quantity),
    OutlierOrders  = sum(Is_Outlier_Qty),
    Country        = names(sort(table(Country), decreasing = TRUE))[1],
    .groups = "drop"
  )

dim(rfm)

rfm <- rfm %>% mutate(Churn = ifelse(as.character(`Customer ID`) %in% returned_customers, 0, 1))
table(rfm$Churn)

rfm <- rfm %>% mutate(HighValue = ifelse(Monetary >= quantile(Monetary, 0.80), 1, 0))
table(rfm$HighValue)

rfm_scaled <- scale(rfm[, c("Recency", "Frequency", "Monetary")])
set.seed(42)
km <- kmeans(rfm_scaled, centers = 4, nstart = 25)
rfm$Segment <- km$cluster
table(rfm$Segment)

top_countries <- rfm %>% count(Country, sort = TRUE) %>% head(5) %>% pull(Country)
rfm <- rfm %>% mutate(CountryGroup = ifelse(Country %in% top_countries, Country, "Other"))

db_path <- "da2_retail.sqlite"
if (file.exists(db_path)) file.remove(db_path)
con <- dbConnect(RSQLite::SQLite(), db_path)

dbWriteTable(con, "customer_features", as.data.frame(rfm), overwrite = TRUE)
dbWriteTable(con, "transactions_clean",
             as.data.frame(retail_clean %>% mutate(`Customer ID` = as.character(`Customer ID`))),
             overwrite = TRUE)

dbListTables(con)

check <- dbGetQuery(con, "SELECT COUNT(*) as n FROM customer_features")
print(check)

dbDisconnect(con)

write.csv(rfm, "customer_features.csv", row.names = FALSE)
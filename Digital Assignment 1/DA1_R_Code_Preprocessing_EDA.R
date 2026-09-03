# ============================================
# DA1 - Complete R Script
# Customer Segmentation Using the Online Retail II Dataset
# ============================================

# ---------------------------------------------
# SECTION 7: DATA PREPROCESSING
# ---------------------------------------------

# --- 7.1 Import Dataset ---
library(readxl)

retail_2009_2010 <- read_excel("online_retail_II.xlsx", sheet = "Year 2009-2010")
retail_2010_2011 <- read_excel("online_retail_II.xlsx", sheet = "Year 2010-2011")
retail <- rbind(retail_2009_2010, retail_2010_2011)

# --- 7.2 Load Required Libraries ---
library(dplyr)
library(tidyr)
library(lubridate)
library(ggplot2)
library(janitor)
library(DataExplorer)
library(corrplot)
library(scales)

# --- 7.3 View Dataset ---
View(retail)
head(retail, 10)

# --- 7.4 Check Structure ---
str(retail)
dim(retail)

# --- 7.5 Check Missing Values ---
colSums(is.na(retail))
plot_missing(retail)

# --- 7.6 Remove Missing Values ---
retail_clean <- retail %>% filter(!is.na(`Customer ID`))
dim(retail_clean)

# --- 7.7 Check Duplicate Records ---
sum(duplicated(retail_clean))
get_dupes(retail_clean)

# --- 7.8 Remove Duplicates ---
retail_clean <- retail_clean %>% distinct()
dim(retail_clean)

# --- 7.9 Remove Cancelled Orders ---
retail_clean <- retail_clean %>% filter(!grepl("^C", Invoice))
dim(retail_clean)

# --- 7.10 Remove Negative Quantity Records ---
retail_clean <- retail_clean %>% filter(Quantity > 0, Price > 0)
dim(retail_clean)
sum(retail_clean$Quantity <= 0)

# --- 7.11 Convert Invoice Date into Date Format ---
retail_clean$InvoiceDate <- as_datetime(retail_clean$InvoiceDate)
class(retail_clean$InvoiceDate)

# --- 7.12 Convert Customer ID into Factor (If Required) ---
retail_clean$`Customer ID` <- as.factor(retail_clean$`Customer ID`)
str(retail_clean$`Customer ID`)

# --- 7.13 Check Outliers ---
Q1 <- quantile(retail_clean$Quantity, 0.25)
Q3 <- quantile(retail_clean$Quantity, 0.75)
IQR_val <- IQR(retail_clean$Quantity)
upper_bound <- Q3 + 1.5 * IQR_val

sum(retail_clean$Quantity > upper_bound)
boxplot(retail_clean$Quantity, main = "Quantity Outlier Check")

# --- 7.14 Handle Outliers (If Applicable) ---
retail_clean <- retail_clean %>%
  mutate(Is_Outlier_Qty = ifelse(Quantity > upper_bound, TRUE, FALSE))
table(retail_clean$Is_Outlier_Qty)


# ---------------------------------------------
# SECTION 8: EXPLORATORY DATA ANALYSIS
# ---------------------------------------------

library(ggplot2)
library(dplyr)
library(lubridate)
library(corrplot)
theme_set(theme_minimal(base_size = 12))

# --- 8.1 Missing Values Visualization ---
missing_summary <- retail %>%
  summarise(across(everything(), ~sum(is.na(.)))) %>%
  tidyr::pivot_longer(everything(), names_to = "Column", values_to = "MissingCount")

ggplot(missing_summary, aes(x = reorder(Column, MissingCount), y = MissingCount)) +
  geom_col(fill = "#DE2D26") +
  coord_flip() +
  labs(title = "Missing Values by Column (Raw Data)", x = NULL, y = "Number of Missing Values")

# --- 8.2 Top 10 Selling Products ---
top_products <- retail_clean %>%
  group_by(Description) %>%
  summarise(TotalQty = sum(Quantity)) %>%
  arrange(desc(TotalQty)) %>%
  head(10)

ggplot(top_products, aes(x = reorder(Description, TotalQty), y = TotalQty)) +
  geom_col(fill = "#2C7FB8") +
  coord_flip() +
  labs(title = "Top 10 Best-Selling Products", x = NULL, y = "Total Quantity Sold")

# --- 8.3 Country-Wise Sales ---
country_sales <- retail_clean %>%
  group_by(Country) %>%
  summarise(Revenue = sum(Quantity * Price)) %>%
  arrange(desc(Revenue)) %>%
  head(10)

ggplot(country_sales, aes(x = reorder(Country, Revenue), y = Revenue)) +
  geom_col(fill = "#E6550D") +
  coord_flip() +
  labs(title = "Top 10 Countries by Sales Revenue", x = NULL, y = "Revenue (GBP)")

# --- 8.4 Monthly Sales Trend ---
retail_clean$Month <- as.Date(format(retail_clean$InvoiceDate, "%Y-%m-01"))
monthly_sales <- aggregate(Quantity * Price ~ Month, data = retail_clean, sum)
names(monthly_sales)[2] <- "Revenue"

ggplot(monthly_sales, aes(x = Month, y = Revenue)) +
  geom_line(color = "#238B45", linewidth = 1) +
  geom_point() +
  labs(title = "Monthly Sales Revenue Trend", x = NULL, y = "Revenue (GBP)")

# --- 8.5 Quantity Distribution Histogram ---
hist(retail_clean$Quantity[retail_clean$Quantity <= 100], breaks = 50,
     col = "#756BB1", main = "Quantity Distribution", xlab = "Quantity", ylab = "Frequency")

# --- 8.6 Unit Price Distribution ---
hist(retail_clean$Price[retail_clean$Price <= 50], breaks = 50,
     col = "#31A354", main = "Unit Price Distribution", xlab = "Unit Price (GBP)", ylab = "Frequency")

# --- 8.7 Boxplot for Quantity ---
boxplot(retail_clean$Quantity, ylim = c(0, 100), col = "#FDAE6B", main = "Boxplot of Quantity", ylab = "Quantity")

# --- 8.8 Boxplot for Unit Price ---
boxplot(retail_clean$Price, ylim = c(0, 50), col = "#9ECAE1", main = "Boxplot of Unit Price", ylab = "Price (GBP)")

# --- 8.9 Top Customers by Purchases ---
top_customers <- retail_clean %>%
  group_by(`Customer ID`) %>%
  summarise(TotalSpent = sum(Quantity * Price)) %>%
  arrange(desc(TotalSpent)) %>%
  head(10)

ggplot(top_customers, aes(x = reorder(`Customer ID`, TotalSpent), y = TotalSpent)) +
  geom_col(fill = "#756BB1") +
  coord_flip() +
  labs(title = "Top 10 Customers by Total Purchases", x = "Customer ID", y = "Total Spent (GBP)")

# --- 8.10 Correlation Heatmap ---
retail_clean$Revenue <- retail_clean$Quantity * retail_clean$Price
numeric_data <- retail_clean[, c("Quantity", "Price", "Revenue")]
corr_matrix <- cor(numeric_data)
corrplot(corr_matrix, method = "color", addCoef.col = "black",
         tl.col = "black", number.cex = 0.8,
         title = "Correlation Heatmap", mar = c(0,0,2,0))
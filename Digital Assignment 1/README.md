<div align="center">

# 🛍️ Customer Segmentation Analytics
### Data Preprocessing & Exploratory Analysis on the Online Retail II Dataset

![R](https://img.shields.io/badge/R-276DC3?style=for-the-badge&logo=r&logoColor=white)
![ggplot2](https://img.shields.io/badge/ggplot2-black?style=for-the-badge&logo=r)
![Status](https://img.shields.io/badge/Status-Complete-success?style=for-the-badge)
![License](https://img.shields.io/badge/Dataset-CC%20BY%204.0-blue?style=for-the-badge)

*Digital Assignment 1 — Programming for Data Science (BCSE207L)*

</div>

---

## 📋 Table of Contents
- [Dataset Overview](#-dataset-overview)
- [Data Preprocessing](#-data-preprocessing)
- [Exploratory Data Analysis](#-exploratory-data-analysis)
- [Key Findings](#-key-findings)
- [Repository Contents](#-repository-contents)
- [Tech Stack](#-tech-stack)

---

## 📦 Dataset Overview

| | |
|---|---|
| **Source** | [UCI Machine Learning Repository](https://archive.ics.uci.edu/dataset/502/online+retail+ii) |
| **Business** | UK-based online gift retailer |
| **Time Period** | 1 December 2009 – 9 December 2011 |
| **Raw Records** | 1,067,371 transactions |
| **Attributes** | Invoice, StockCode, Description, Quantity, InvoiceDate, Price, Customer ID, Country |

---

## 🧹 Data Preprocessing

### 1️⃣ Viewing the Raw Dataset
```r
View(retail)
head(retail, 10)
```
<img src="preprocess_01_view_retail_dataset.png" width="700">

### 2️⃣ Checking Missing Values
```r
colSums(is.na(retail))
plot_missing(retail)
```
<img src="preprocess_02_missing_values_diagnostic.png" width="700">

> **Finding:** Customer ID was missing in **22.77%** of rows (guest checkouts). These rows were removed since customer-level analysis requires a valid identifier.

### 3️⃣ Checking Outliers
```r
Q1 <- quantile(retail_clean$Quantity, 0.25)
Q3 <- quantile(retail_clean$Quantity, 0.75)
IQR_val <- IQR(retail_clean$Quantity)
upper_bound <- Q3 + 1.5 * IQR_val
boxplot(retail_clean$Quantity, main = "Quantity Outlier Check")
```
<img src="preprocess_03_outlier_boxplot.png" width="500">

> **Finding:** **51,119** transactions were flagged as outliers using the IQR method and **retained, not deleted** — this retailer's wholesale customers legitimately place bulk orders.

### 📊 Cleaning Pipeline Summary

| Stage | Rows Remaining | Rows Removed |
|---|---:|---:|
| Raw combined data | 1,067,371 | — |
| After removing missing Customer IDs | 824,364 | 243,007 |
| After removing duplicates | 797,885 | 26,479 |
| After removing cancelled orders | 779,495 | 18,390 |
| **Final cleaned dataset** | **779,425** | 70 |

---

## 📈 Exploratory Data Analysis

<table>
<tr>
<td width="50%">

**1. Missing Values by Column**
```r
ggplot(missing_summary, aes(x = reorder(Column, MissingCount),
       y = MissingCount)) +
  geom_col(fill = "#DE2D26") + coord_flip()
```
<img src="chart_01_missing_values.png" width="380">

</td>
<td width="50%">

**2. Top 10 Best-Selling Products**
```r
top_products <- retail_clean %>%
  group_by(Description) %>%
  summarise(TotalQty = sum(Quantity)) %>%
  arrange(desc(TotalQty)) %>% head(10)
```
<img src="chart_02_top_products.png" width="380">

</td>
</tr>
<tr>
<td width="50%">

**3. Top 10 Countries by Revenue**
```r
country_sales <- retail_clean %>%
  group_by(Country) %>%
  summarise(Revenue = sum(Quantity * Price))
```
<img src="chart_03_country_sales.png" width="380">

</td>
<td width="50%">

**4. Monthly Sales Revenue Trend**
```r
monthly_sales <- aggregate(Quantity * Price ~ Month,
                            data = retail_clean, sum)
```
<img src="chart_04_monthly_trend.png" width="380">

</td>
</tr>
<tr>
<td width="50%">

**5. Quantity Distribution**
```r
hist(retail_clean$Quantity[retail_clean$Quantity <= 100],
     breaks = 50, col = "#756BB1")
```
<img src="chart_05_quantity_distribution.png" width="380">

</td>
<td width="50%">

**6. Unit Price Distribution**
```r
hist(retail_clean$Price[retail_clean$Price <= 50],
     breaks = 50, col = "#31A354")
```
<img src="chart_06_price_distribution.png" width="380">

</td>
</tr>
<tr>
<td width="50%">

**7. Boxplot for Quantity**
```r
boxplot(retail_clean$Quantity, ylim = c(0, 100),
        col = "#FDAE6B")
```
<img src="chart_07_quantity_boxplot.png" width="380">

</td>
<td width="50%">

**8. Boxplot for Unit Price**
```r
boxplot(retail_clean$Price, ylim = c(0, 50),
        col = "#9ECAE1")
```
<img src="chart_08_price_boxplot.png" width="380">

</td>
</tr>
<tr>
<td width="50%">

**9. Top 10 Customers by Purchases**
```r
top_customers <- retail_clean %>%
  group_by(`Customer ID`) %>%
  summarise(TotalSpent = sum(Quantity * Price))
```
<img src="chart_09_top_customers.png" width="380">

</td>
<td width="50%">

**10. Correlation Heatmap**
```r
corrplot(corr_matrix, method = "color",
         addCoef.col = "black")
```
<img src="chart_10_correlation_heatmap.png" width="380">

</td>
</tr>
</table>

---

## 🔍 Key Findings

- 🇬🇧 **United Kingdom dominates sales**, generating ~£14–15M vs. distant second-place markets (Ireland, Netherlands, Germany)
- 📦 A **small set of products** drives disproportionate volume — top item exceeds 100,000 units sold
- 📅 **Clear seasonal peaks** in November each year, consistent with pre-Christmas gift buying
- 💰 **Two customers** (18102, 14646) each spent **£500,000+**, indicating wholesale accounts
- 📊 **Quantity and Revenue correlate strongly (0.83)**, while Price behaves largely independently

---

## 📁 Repository Contents

| File | Description |
|---|---|
| `DA1_Project_Report.docx` | Full written project report |
| `DA1_R_Code_Preprocessing_EDA.R` | Complete, runnable R script |
| `DA1_Presentation.pptx` | Presentation slide deck |
| `DA1_Study_Guide.md` | Step-by-step explanation of every method |
| `online_retail_II.xlsx` | Source dataset (UCI repository) |

---

## 🛠️ Tech Stack

![readxl](https://img.shields.io/badge/readxl-blue?style=flat-square)
![dplyr](https://img.shields.io/badge/dplyr-blue?style=flat-square)
![tidyr](https://img.shields.io/badge/tidyr-blue?style=flat-square)
![lubridate](https://img.shields.io/badge/lubridate-blue?style=flat-square)
![ggplot2](https://img.shields.io/badge/ggplot2-orange?style=flat-square)
![janitor](https://img.shields.io/badge/janitor-orange?style=flat-square)
![DataExplorer](https://img.shields.io/badge/DataExplorer-orange?style=flat-square)
![corrplot](https://img.shields.io/badge/corrplot-green?style=flat-square)

<div align="center">

---
*Programming for Data Science (BCSE207L) — Vellore Institute of Technology*

</div>

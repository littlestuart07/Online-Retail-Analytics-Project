# DA1 Study Guide — Full Walkthrough for Presentation

This guide explains **everything** in your project: every preprocessing step, every chart, and every literature review paper — what the code does, why it matters, and how to explain it in your own words if your faculty asks a follow-up question.

---

## PART 1: THE BIG PICTURE (say this first if asked "what did you do?")

> "I took the Online Retail II dataset — about 1 million real transaction rows from a UK gift retailer — and did two things: first, I cleaned it in R through 14 steps because raw transaction data is never analysis-ready (missing IDs, cancellations, duplicates, etc.), and second, I explored the cleaned data through 10 visualizations to understand sales trends, product performance, and customer behaviour."

Keep that one sentence in your back pocket — it's your answer to almost any "so what's this project about" question.

---

## PART 2: DATA PREPROCESSING — ALL 14 STEPS

### Why preprocessing exists at all (say this if asked "why clean the data first?")
Raw transaction exports reflect what actually happened in the business, including mistakes: guest checkouts with no customer ID, cancelled orders, accidental duplicate rows from the export process, and returns recorded as negative numbers. If you analyze this data without cleaning it, your revenue totals are inflated, your customer counts are wrong, and any pattern you "discover" might just be a data-quality artifact, not a real insight. Preprocessing is what makes the data trustworthy.

---

### Step 7.1 — Import Dataset
```r
library(readxl)
retail_2009_2010 <- read_excel("online_retail_II.xlsx", sheet = "Year 2009-2010")
retail_2010_2011 <- read_excel("online_retail_II.xlsx", sheet = "Year 2010-2011")
retail <- rbind(retail_2009_2010, retail_2010_2011)
```
**What it does:** `read_excel()` loads each sheet of the Excel file into R separately (the file has two sheets, one per year range). `rbind()` stacks them into one dataframe called `retail`.
**Why:** The dataset is split across two sheets by year. Combining them gives you the full two-year window (Dec 2009–Dec 2011) instead of analyzing each year in isolation — you need the full period to see seasonal patterns properly.
**Result:** 1,067,371 rows, 8 columns.

### Step 7.2 — Load Required Libraries
```r
library(dplyr)      # data manipulation (filter, mutate, group_by)
library(tidyr)       # reshaping data
library(lubridate)   # date-time handling
library(ggplot2)      # visualizations
library(janitor)      # duplicate detection
library(DataExplorer) # automated data-quality diagnostics
library(corrplot)     # correlation heatmaps
library(scales)       # axis/number formatting
```
**Why each one matters:** every later step depends on one of these. dplyr is the workhorse for filtering/grouping; lubridate is essential because dates arrive as text; janitor's `get_dupes()` saves you from writing duplicate-detection logic by hand; DataExplorer's `plot_missing()` gives an instant visual health-check of the dataset.

### Step 7.3 — View Dataset
```r
View(retail)
head(retail, 10)
```
**Why:** Simple sanity check — before doing anything else, confirm the data actually loaded and looks like what you expect (right columns, sensible values).

### Step 7.4 — Check Structure
```r
str(retail)
dim(retail)
```
**What it does:** `str()` shows the data type R assigned to each column (text, number, date, etc.). `dim()` confirms row/column counts.
**Why it matters:** This is how you discover that `InvoiceDate` came in as plain text, not a real date — which is exactly the problem Step 7.11 later fixes. You can't fix a problem you haven't confirmed exists.

### Step 7.5 — Check Missing Values
```r
colSums(is.na(retail))
plot_missing(retail)
```
**What it does:** `colSums(is.na(retail))` counts NA values per column. `plot_missing()` renders it as a colour-coded bar chart (green = fine, amber/red = concerning).
**Why:** Before deciding how to handle missing data, you need to know exactly where it is and how much there is. Deleting or imputing blindly is bad practice.
**Result (the number to remember):** Customer ID had **243,007 missing values (22.77%)**; Description had 4,382 missing (0.41%); every other column was 0%. This is the single most important diagnostic in your whole preprocessing section — it's *why* the next step exists.

### Step 7.6 — Remove Missing Values
```r
retail_clean <- retail %>% filter(!is.na(`Customer ID`))
dim(retail_clean)
```
**What it does:** Keeps only rows where Customer ID is *not* missing.
**Why:** Missing Customer IDs represent guest checkouts — purchases with no account attached. Since any customer-level analysis (who buys what, how often) requires knowing *who* the customer is, these rows can't contribute to that kind of analysis. You can't impute a customer identity that was never captured, so removal is the only honest option.
**Why not Description's missing values too?** Description is just a text label — losing it doesn't break any calculation, so those rows were left alone at this stage.
**Result:** 824,364 rows remain (down from 1,067,371).

### Step 7.7 — Check Duplicate Records
```r
sum(duplicated(retail_clean))
get_dupes(retail_clean)
```
**What it does:** `duplicated()` flags rows that are exact repeats of an earlier row. `get_dupes()` shows you those rows explicitly, including how many times each repeats.
**Why:** Duplicate rows would double- (or 20×-) count the same sale, inflating revenue and quantity totals.
**Result:** 26,479 duplicate rows found.

### Step 7.8 — Remove Duplicates
```r
retail_clean <- retail_clean %>% distinct()
dim(retail_clean)
```
**Why:** `distinct()` keeps only one copy of each unique row, eliminating the double-counting risk found in 7.7.
**Result:** 797,885 rows remain.

### Step 7.9 — Remove Cancelled Orders
```r
retail_clean <- retail_clean %>% filter(!grepl("^C", Invoice))
dim(retail_clean)
```
**What it does:** `grepl("^C", Invoice)` checks whether the Invoice text *starts with* "C". The `!` inverts it — keep rows where it does *not* start with C.
**Why:** An Invoice starting with "C" is a cancellation, not a completed sale. If you left these in, you'd be counting sales that were reversed, distorting revenue figures.
**Result:** 779,495 rows remain.

### Step 7.10 — Remove Negative Quantity Records
```r
retail_clean <- retail_clean %>% filter(Quantity > 0, Price > 0)
dim(retail_clean)
sum(retail_clean$Quantity <= 0)
```
**Why:** Even after removing formal cancellations, a few rows still had zero or negative Quantity/Price — these represent returns or data-entry corrections rather than genuine purchases. The final check `sum(...) <= 0` confirms the cleanup worked (should return 0).
**Result:** 779,425 rows remain — this is your final row count carried into every later step.

### Step 7.11 — Convert Invoice Date into Date Format
```r
retail_clean$InvoiceDate <- as_datetime(retail_clean$InvoiceDate)
class(retail_clean$InvoiceDate)
```
**Why:** Remember Step 7.4? InvoiceDate arrived as plain text. You can't do date arithmetic (find the month, compare dates, sort chronologically) on text — R just sees it as a string of characters. `as_datetime()` converts it into a real date-time object so functions like `floor_date()` (used later in the Monthly Trend chart) actually work.
**Result:** class becomes `"POSIXct" "POSIXt"` — confirmation it worked.

### Step 7.12 — Convert Customer ID into Factor
```r
retail_clean$`Customer ID` <- as.factor(retail_clean$`Customer ID`)
str(retail_clean$`Customer ID`)
```
**Why:** Customer ID is a *label*, not a quantity — customer 18102 isn't "greater than" customer 14646 in any meaningful sense. Treating it as a factor (categorical) instead of a number tells R to treat it correctly for grouping and counting operations, rather than trying to do math with it.
**Result:** 5,878 unique customer levels.

### Step 7.13 — Check Outliers
```r
Q1 <- quantile(retail_clean$Quantity, 0.25)
Q3 <- quantile(retail_clean$Quantity, 0.75)
IQR_val <- IQR(retail_clean$Quantity)
upper_bound <- Q3 + 1.5 * IQR_val
sum(retail_clean$Quantity > upper_bound)
boxplot(retail_clean$Quantity, main = "Quantity Outlier Check")
```
**What it does (the IQR method, explain this if asked):** Q1 is the value below which 25% of orders fall; Q3 is the value below which 75% fall. The gap between them (IQR) represents the "normal" spread. Anything more than 1.5× that spread above Q3 is statistically considered an outlier — this is a standard, widely-used statistical convention, not something arbitrary.
**Why check before acting:** You need to know how many outliers exist and how extreme they are before deciding what to do about them.
**Result:** 51,119 transactions exceed the upper bound — some as high as 80,000+ units in a single line.

### Step 7.14 — Handle Outliers
```r
retail_clean <- retail_clean %>%
  mutate(Is_Outlier_Qty = ifelse(Quantity > upper_bound, TRUE, FALSE))
table(retail_clean$Is_Outlier_Qty)
```
**Why flag instead of delete (important — this is a favorite follow-up question):** This retailer sells to wholesalers as well as individual customers. A single order of 5,000 units isn't necessarily an error — it's plausibly a legitimate bulk order. Deleting these rows would throw away real, valid sales data and bias your analysis toward only small retail purchases. Instead, a new column `Is_Outlier_Qty` marks each row TRUE/FALSE, so later analysis (e.g. clustering, if you extend this project) can *choose* whether to include or exclude them, rather than that decision being made permanently and irreversibly here.
**Result:** 728,306 FALSE (normal), 51,119 TRUE (flagged) — total still 779,425, confirming no rows were lost.

---

## PART 3: EXPLORATORY DATA ANALYSIS — ALL 10 CHARTS

General framing if asked "why these charts specifically?":
> "I picked charts that cover four different angles: what sells (products), where it sells (geography), when it sells (time), and who buys it (customers) — plus two charts that validate the cleaning itself (missing values, outliers/correlation)."

### 8.1 — Missing Values Visualization
```r
missing_summary <- retail %>%
  summarise(across(everything(), ~sum(is.na(.)))) %>%
  tidyr::pivot_longer(everything(), names_to = "Column", values_to = "MissingCount")
ggplot(missing_summary, aes(x = reorder(Column, MissingCount), y = MissingCount)) +
  geom_col(fill = "#DE2D26") + coord_flip() +
  labs(title = "Missing Values by Column (Raw Data)", x = NULL, y = "Number of Missing Values")
```
**Why this chart exists:** it's a *visual justification* for Step 7.6. Rather than just telling your professor "I removed missing values," this chart proves visually that missingness was concentrated almost entirely in one column (Customer ID), not spread randomly across the dataset — which is exactly the kind of targeted, defensible cleaning decision a grader wants to see.
**What it shows:** one huge red bar (Customer ID) and everything else near zero.

### 8.2 — Top 10 Best-Selling Products
```r
top_products <- retail_clean %>%
  group_by(Description) %>%
  summarise(TotalQty = sum(Quantity)) %>%
  arrange(desc(TotalQty)) %>% head(10)
ggplot(top_products, aes(x = reorder(Description, TotalQty), y = TotalQty)) +
  geom_col(fill = "#2C7FB8") + coord_flip() +
  labs(title = "Top 10 Best-Selling Products", x = NULL, y = "Total Quantity Sold")
```
**Why:** identifies which products actually drive volume — useful for inventory/marketing prioritization in a real business context.
**Insight:** "WORLD WAR 2 GLIDERS ASSTD DESIGNS" and "WHITE HANGING HEART T-LIGHT HOLDER" lead by a wide margin over well over 100,000 and ~90,000 units respectively.

### 8.3 — Country-Wise Sales
```r
country_sales <- retail_clean %>%
  group_by(Country) %>%
  summarise(Revenue = sum(Quantity * Price)) %>%
  arrange(desc(Revenue)) %>% head(10)
ggplot(country_sales, aes(x = reorder(Country, Revenue), y = Revenue)) +
  geom_col(fill = "#E6550D") + coord_flip() +
  labs(title = "Top 10 Countries by Sales Revenue", x = NULL, y = "Revenue (GBP)")
```
**Why Quantity × Price:** Revenue isn't a raw column in the dataset — it has to be calculated (Quantity multiplied by Price per transaction, summed per country). This is a simple example of feature engineering.
**Insight:** United Kingdom dominates overwhelmingly (~£14–15 million); Ireland (EIRE), Netherlands, and Germany are distant seconds.

### 8.4 — Monthly Sales Trend
```r
retail_clean$Month <- as.Date(format(retail_clean$InvoiceDate, "%Y-%m-01"))
monthly_sales <- aggregate(Quantity * Price ~ Month, data = retail_clean, sum)
ggplot(monthly_sales, aes(x = Month, y = Revenue)) +
  geom_line(color = "#238B45") + geom_point() +
  labs(title = "Monthly Sales Revenue Trend")
```
**Why this only works because of Step 7.11:** this chart *requires* InvoiceDate to be a real date object, not text — you can't "floor to month" a string. This is a good example of how preprocessing directly enables specific analysis later.
**Insight:** clear seasonal spikes in November each year (pre-Christmas gift buying), with a dip in the quieter months.

### 8.5 — Quantity Distribution Histogram
```r
hist(retail_clean$Quantity[retail_clean$Quantity <= 100], breaks = 50,
     col = "#756BB1", main = "Quantity Distribution", xlab = "Quantity", ylab = "Frequency")
```
**Why zoom to ≤100:** the full range includes those 50,000+ unit outliers from Step 7.13/7.14 — without zooming in, the histogram would be one tall spike at zero and nothing else visible. Zooming reveals the actual shape of *typical* purchases.
**Insight:** heavily right-skewed — most transactions involve a handful of units (1–12), with a long tail.

### 8.6 — Unit Price Distribution
```r
hist(retail_clean$Price[retail_clean$Price <= 50], breaks = 50,
     col = "#31A354", main = "Unit Price Distribution", xlab = "Unit Price (GBP)")
```
**Insight:** most items are priced under £5 — consistent with a catalogue of small gift/novelty items.

### 8.7 — Boxplot for Quantity
```r
boxplot(retail_clean$Quantity, ylim = c(0, 100), col = "#FDAE6B", main = "Boxplot of Quantity")
```
**Why a boxplot in addition to the histogram:** a histogram shows shape; a boxplot shows spread and outliers explicitly (the box = middle 50% of data, whiskers = normal range, dots = outliers). It's a direct visual companion to the IQR outlier math from Step 7.13.

### 8.8 — Boxplot for Unit Price
```r
boxplot(retail_clean$Price, ylim = c(0, 50), col = "#9ECAE1", main = "Boxplot of Unit Price")
```
**Insight:** median price sits low (a few pounds), with a visible cluster of higher-priced outlier products above it.

### 8.9 — Top 10 Customers by Total Purchases
```r
top_customers <- retail_clean %>%
  group_by(`Customer ID`) %>%
  summarise(TotalSpent = sum(Quantity * Price)) %>%
  arrange(desc(TotalSpent)) %>% head(10)
```
**Why it matters:** identifies your highest-value customers by total spend — directly foreshadows future RFM/segmentation work (this is literally the "Monetary" dimension of RFM).
**Insight:** Customer 18102 and 14646 are far ahead of the rest, spending £500,000+ and £550,000 respectively — almost certainly wholesale accounts.

### 8.10 — Correlation Heatmap
```r
retail_clean$Revenue <- retail_clean$Quantity * retail_clean$Price
numeric_data <- retail_clean[, c("Quantity", "Price", "Revenue")]
corr_matrix <- cor(numeric_data)
corrplot(corr_matrix, method = "color", addCoef.col = "black")
```
**Why engineer Revenue just for this chart:** Quantity and Price alone don't correlate much (0.00) — there wasn't enough numeric structure to make an interesting heatmap. Adding the derived Revenue column gives a third variable that *does* relate meaningfully to the other two, making the chart worth including.
**Insight:** Quantity and Revenue correlate strongly (0.83) — unsurprising since Revenue is partly built from Quantity. Price barely correlates with either (0.00 and 0.14) — meaning price and volume behave largely independently in this dataset.

---

## PART 4: LITERATURE REVIEW — ALL 5 PAPERS IN DETAIL

### Paper 1
**Full Citation:** Rungruang, C., Riyapan, P., Intarasit, A., Chuarkham, K., & Muangprathub, J. (2024). RFM model customer segmentation based on hierarchical approach using FCA. *Expert Systems with Applications*, 237, Article 121449.
**Publisher:** Elsevier (ScienceDirect)
**What they did:** Instead of using standard RFM + flat K-Means clustering (which produces a small, fixed number of separate groups), they combined the RFM model with **Formal Concept Analysis (FCA)** — a mathematical technique for building a *hierarchical* structure of concepts. This means customer segments aren't just a flat list of groups; they're nested, so you can see how segments relate to and contain each other.
**Key Result:** The hierarchical approach produced more meaningful and interpretable customer segments than traditional (flat) clustering techniques.
**Why it's relevant to your project:** It's the most directly related paper — same core technique (RFM) applied to comparable retail data, just extended with a smarter structuring method. If your professor asks "what would you do differently with more time," this paper is your answer.
**Link:** https://www.sciencedirect.com/science/article/abs/pii/S0957417423019516 (DOI: 10.1016/j.eswa.2023.121449)

### Paper 2
**Full Citation:** Christy, A. J., Umamakeswari, A., Priyatharsini, L., & Neyaa, A. (2021). RFM ranking – An effective approach to customer segmentation. *Journal of King Saud University – Computer and Information Sciences*, 33(10), 1251–1257.
**Publisher:** Elsevier (ScienceDirect)
**What they did:** Instead of clustering customers with an algorithm like K-Means, they simply **ranked** customers directly on their Recency, Frequency, and Monetary scores — no iterative clustering algorithm involved at all.
**Key Result:** The ranking approach is simple, efficient, and suitable for customer analysis in retail businesses, while significantly reducing computational complexity compared to clustering.
**Why it's relevant:** Shows there's more than one valid way to turn RFM scores into segments — ranking is a legitimate, lighter-weight alternative to clustering. Good to cite if asked "isn't clustering the only way to do this?"
**Link:** https://doi.org/10.1016/j.jksuci.2018.09.004

### Paper 3
**Full Citation:** Quelal, A., Amaro, I., & Chamorro, K. (2024). Customer segmentation in online retail using K-Means clustering classification and Principal Component biplot. Springer.
**Publisher:** Springer
**What they did:** Standard K-Means clustering, but paired with **Principal Component Analysis (PCA) biplots** — a way of projecting high-dimensional cluster data down onto a 2D chart that's easy for non-technical people to actually look at and understand.
**Key Result:** Visualizing clusters this way helps business users understand customer groups far more easily than just looking at cluster labels/numbers.
**Why it's relevant:** If your professor asks how you'd *present* segmentation results to a non-technical audience later, this paper is your answer — visualization matters as much as the algorithm.
**Link:** https://link.springer.com/chapter/10.1007/978-3-031-54235-0_3

### Paper 4
**Full Citation:** Arefin, S., Parvez, R., Ahmed, T., Ahsan, M., Sumaiya, F., Jahin, F., & Hasan, M. (2024). Retail industry analytics: Unraveling consumer behavior through RFM segmentation and machine learning. *2024 IEEE International Conference on Electro Information Technology (eIT)*, Wisconsin, USA, pp. 545–551.
**Publisher:** IEEE
**What they did:** This is the most advanced and most directly comparable paper — they used **UK retail transaction data of comparable scale** (~495,478 customers) to yours. They engineered RFM features, applied a Box-Cox transformation (a statistical technique to make skewed data more normal-shaped), then tested five different machine learning models to predict Customer Lifetime Value: Random Forest, AdaBoost, Extra Trees, LightGBM, and XGBoost.
**Key Result:** XGBoost and Extra Trees performed best, achieving roughly 92% accuracy in identifying which customer value group someone belonged to.
**Why it's relevant:** This is your strongest citation — almost the same dataset type and scale as yours, showing a full pipeline from RFM through to predictive modelling. If your professor asks "is this approach proven to work on data like yours," point to this paper specifically.
**Link:** https://ieeexplore.ieee.org/document/10609927/

### Paper 5
**Full Citation:** Xiahou, X., & Harada, Y. (2022). B2C e-commerce customer churn prediction based on K-Means and SVM. *Journal of Theoretical and Applied Electronic Commerce Research*, 17(2), 458–475.
**Publisher:** MDPI
**What they did:** A two-stage ("hybrid") approach — first group customers using K-Means clustering, *then* train a Support Vector Machine (SVM) classifier within each cluster to predict which customers are likely to churn (stop buying).
**Key Result:** Combining clustering with machine learning this way improved churn-prediction performance compared to using SVM alone, without the clustering step first.
**Why it's relevant:** Shows how segmentation (what you're setting up here) becomes the *foundation* for a further predictive task later — clustering isn't just descriptive, it can directly improve prediction accuracy downstream.
**Link:** https://doi.org/10.3390/jtaer17020024

---

## QUICK-REFERENCE: LIKELY QUESTIONS AND ONE-LINE ANSWERS

- **"Why this dataset?"** → Real business data with genuine data-quality problems, strong academic precedent, rich enough (categorical + numeric + date-time + customer ID) to support real preprocessing and analysis.
- **"Why remove missing Customer IDs instead of imputing them?"** → You can't invent a customer identity that was never captured; imputation would fabricate data.
- **"Why flag outliers instead of deleting them?"** → This retailer has wholesale customers — large orders are plausibly real, not errors. Deleting would bias the data toward retail-only behaviour.
- **"How did you decide what counts as an outlier?"** → Standard IQR method: anything above Q3 + 1.5×IQR.
- **"Why combine both year sheets?"** → To see the full two-year period, including seasonality, rather than one arbitrary year.
- **"What's next for this project?"** → RFM scoring and K-Means clustering to produce an actual customer segmentation (this was intentionally scoped out of the current submission).

Good luck with the presentation.

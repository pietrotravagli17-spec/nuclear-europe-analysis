# Nuclear Power in Europe (2010–2025)

How has nuclear power changed across 14 European countries, and can the data be trusted?

**Tools:** BigQuery (SQL) · Python · Power BI
---

## Main findings

- Europe's nuclear output **fell 18%** since 2010, mostly because Germany phased out.
- **France** gets 73% of its electricity from nuclear, the highest share in Europe.
- Only **Finland** and **Slovakia** are growing nuclear, thanks to new reactors.
- **11 records (4.9%)** in the dataset don't add up, and some figures differ from official sources.

---

## What I did

**1. SQL (BigQuery)**
- Checked the data: no missing values, no impossible numbers.
- Calculated new metrics, such as capacity factor and year-over-year change.
- Flagged records where generation and share contradict each other.

**2. Python**
- Summarised each country's profile (share, trend, size).
- Tried KMeans clustering: it found only two outliers (France and Germany), not three clear groups.
- Grouped countries by how much they rely on nuclear and whether it's growing or declining.

**3. Power BI**
- Built a 3-page dashboard: Overview, Country comparison, Data quality.

---

## Data quality

I compared the flagged records with official sources (IAEA, European Nuclear Society):

| Country | Year | Dataset | Official |
|---|---|---|---|
| France | 2022 | 440 TWh | 279 TWh |
| Germany | 2021 | 32 TWh | 65 TWh |
| Netherlands | 2020 | 0.5% share | 3.3% share |

**Takeaway:** the dataset is fine for practising analysis, but real conclusions should be checked against official data.

---

## Files

| Folder | Content |
|---|---|
| `data/` | original dataset, cleaned tables, official figures |
| `sql/` | BigQuery queries |
| `notebooks/` | Python analysis |
| `powerbi/` | dashboard file and theme |

# RedFlag-FraudDetection
"Fraud detection engine using pure SQL"

A pure-SQL fraud detection system built on 200,000 synthetic transactions from a simulated Indian payment aggregator. Detects 12 distinct fraud patterns — velocity fraud, card testing, money laundering, mule accounts, merchant collusion, and more — using GROUP BY, HAVING, correlated subqueries, CTEs, and window functions (no Python, no ML).

## Sample Output

<img width="761" height="820" alt="image" src="https://github.com/user-attachments/assets/a1f94a6c-5f5b-40ce-ab5f-5efe8e3fcb11" />

## Patterns Detected

**Tier 1 (Week 3 skills):**
1. Velocity Fraud — 30+ transactions/user/day
2. Round-Amount Clustering — money laundering signature
3. Card Testing — 30+ sub-₹10 transactions in one day
4. Failed-Then-Succeeded — automated card-testing retries
5. Odd-Hour Concentration — bot activity 2-5 AM

**Tier 2 (joins/subqueries):**
6. Mule Accounts — rapid credit-then-debit behavior
7. Refund Abuse — chargeback exploitation
8. Merchant Collusion — concentrated volume from few users
9. Just-Under-Threshold — KYC structuring at ₹9,999
10. Dormant-Then-Active — account takeover signature

**Tier 3 (window functions):**
11. Velocity Spike — 5x+ monthly transaction spike
12. Geographic Impossibility — same user, different cities, <60 min apart

## Tech Stack

MySQL 8.0 — pure SQL only (no Python, no ML libraries)

## Files

- `RedFlag_Jeevika.sql` — final submission with all 12 detection queries
- `screenshots/` — sample query outputs

## Dataset

The dataset file (`redflag_transactions.sql`, ~18MB, 200,000 rows) is not included in this repo due to size. Available on request, or download here:

https://drive.google.com/file/d/1xCmEPx5XwePnxPncLbJImMmjh82GqOrr/view?usp=sharing

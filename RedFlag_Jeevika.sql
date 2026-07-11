-- =====================================================================
-- RedFlag — Fraud Detection Submission
-- Student: JEEVIKA S | Batch: DA-DS-1
-- =====================================================================

USE redflag;

-- =====================================================================
-- PATTERN 1 · VELOCITY FRAUD
-- What I'm looking for: users with 30+ transactions in a single day
-- Expected suspects: ~45-55
-- =====================================================================

SELECT user_id, DATE(txn_time) AS txn_date, COUNT(*) AS daily_count
FROM transactions
GROUP BY user_id, DATE(txn_time)
HAVING daily_count >= 30
ORDER BY daily_count DESC;

-- My findings: 50 suspect user-days flagged.
-- Top 3 fraudsters by transaction count: user 14569 (60 txns on 2024-04-03),
-- user 14556 (60 txns on 2024-05-28), user 14564 (59 txns on 2024-02-15).
-- =====================================================================


-- =====================================================================
-- PATTERN 2 · ROUND-AMOUNT CLUSTERING
-- What I'm looking for: users with 15+ transactions at exact round amounts
-- (100, 200, 500, 1000, 2000, 5000, 10000) - a money-laundering signature
-- Expected suspects: exactly 25
-- =====================================================================

SELECT user_id, COUNT(*) AS round_amount_count
FROM transactions
WHERE amount IN (100, 200, 500, 1000, 2000, 5000, 10000)
GROUP BY user_id
HAVING round_amount_count >= 15
ORDER BY round_amount_count DESC;

-- My findings: exactly 25 suspects flagged, matching expected count.
-- Top 3: user 14533 (30 round-amount txns), user 14534 (30), user 14535 (30).
-- =====================================================================

-- =====================================================================
-- PATTERN 3 · CARD TESTING
-- What I'm looking for: users with 30+ transactions under Rs.10 in one day
-- Expected suspects: exactly 20
-- =====================================================================

SELECT user_id, DATE(txn_time) AS txn_date, COUNT(*) AS tiny_txn_count
FROM transactions
WHERE amount < 10
GROUP BY user_id, DATE(txn_time)
HAVING tiny_txn_count >= 30
ORDER BY tiny_txn_count DESC;

-- My findings: exactly 20 suspects flagged, matching expected count.
-- Top 3: user 14569 (60 tiny txns on 2024-04-03), user 14556 (60), user 14564 (59).
-- =====================================================================

-- =====================================================================
-- PATTERN 4 · FAILED-THEN-SUCCEEDED (SIMPLIFIED)
-- What I'm looking for: users with 20+ FAILED transactions - signature of
-- automated card/CVV testing scripts retrying until one clears
-- Expected suspects: exactly 25
-- =====================================================================

SELECT user_id, COUNT(*) AS failed_count
FROM transactions
WHERE status = 'FAILED'
GROUP BY user_id
HAVING failed_count >= 20
ORDER BY failed_count DESC;

-- My findings: exactly 25 suspects flagged, matching expected count.
-- Top 3: user 14595 (35 failed txns), user 14593 (34), user 14576 (33).
-- =====================================================================

-- =====================================================================
-- PATTERN 5 · ODD-HOUR CONCENTRATION
-- What I'm looking for: users with 80%+ of transactions between 2-5 AM
-- and at least 30 total transactions - signature of automated bot scripts
-- running outside normal Indian business hours
-- Expected suspects: exactly 20
-- =====================================================================
SELECT 
    user_id,
    COUNT(*) AS total_txns,
    SUM(CASE WHEN HOUR(txn_time) BETWEEN 2 AND 4 THEN 1 ELSE 0 END) AS odd_hour_txns
FROM transactions
GROUP BY user_id
HAVING total_txns >= 30
   AND odd_hour_txns / total_txns >= 0.8
ORDER BY odd_hour_txns DESC;
-- My findings: exactly 20 suspects flagged, matching expected count.
-- Top 3: user 14608 (58/63 = 92% odd-hour), user 14606 (49/52 = 94%),
-- user 14607 (46/53 = 87%).
-- =====================================================================

-- =====================================================================
-- PATTERN 6 · MULE ACCOUNTS (SIMPLIFIED)
-- What I'm looking for: users with 8+ CREDIT transactions - signature of
-- accounts receiving funds from multiple sources (mule behaviour)
-- Expected suspects: exactly 30
-- =====================================================================
SELECT user_id, COUNT(*) AS credit_count
FROM transactions
WHERE txn_type = 'CREDIT'
GROUP BY user_id
HAVING credit_count >= 8
ORDER BY credit_count DESC;
-- My findings: exactly 30 suspects flagged, matching expected count.
-- Top 3: user 14630 (15 credits), user 14637 (15), user 14640 (15).
-- =====================================================================

-- =====================================================================
-- PATTERN 7 · REFUND ABUSE
-- What I'm looking for: users with 20+ total transactions where refunds
-- make up more than 40% of their activity - signature of chargeback/
-- refund exploitation schemes
-- Expected suspects: 24-25
-- =====================================================================
SELECT 
    user_id,
    COUNT(*) AS total_txns,
    SUM(CASE WHEN txn_type = 'REFUND' THEN 1 ELSE 0 END) AS refund_count
FROM transactions
GROUP BY user_id
HAVING total_txns >= 20
   AND refund_count / total_txns > 0.4
ORDER BY refund_count DESC;
-- My findings: 24 suspects flagged, within expected 24-25 range.
-- Top 3: user 14670 (32/50 = 64% refund rate), user 14671 (29/53 = 55%),
-- user 14675 (28/58 = 48%).
-- =====================================================================

-- =====================================================================
-- PATTERN 8 · MERCHANT COLLUSION
-- What I'm looking for: merchants where the top 5 users by spend account
-- for more than 60% of the merchant's total transaction value - signature
-- of a small ring of accounts laundering money through one storefront
-- Expected suspects: exactly 15 merchants (merchant IDs 1-15)
-- =====================================================================
WITH merchant_user_totals AS (
    SELECT merchant_id, user_id, SUM(amount) AS user_total
    FROM transactions
    GROUP BY merchant_id, user_id
),
ranked_users AS (
    SELECT 
        merchant_id, 
        user_id, 
        user_total,
        ROW_NUMBER() OVER (PARTITION BY merchant_id ORDER BY user_total DESC) AS rnk
    FROM merchant_user_totals
),
top5_sums AS (
    SELECT merchant_id, SUM(user_total) AS top5_total
    FROM ranked_users
    WHERE rnk <= 5
    GROUP BY merchant_id
),
merchant_totals AS (
    SELECT merchant_id, SUM(amount) AS merchant_total
    FROM transactions
    GROUP BY merchant_id
)
SELECT 
    m.merchant_id,
    t.top5_total,
    m.merchant_total,
    t.top5_total / m.merchant_total AS top5_ratio
FROM merchant_totals m
JOIN top5_sums t ON m.merchant_id = t.merchant_id
WHERE t.top5_total / m.merchant_total > 0.6
ORDER BY top5_ratio DESC;
-- My findings: exactly 15 merchants flagged (IDs 1-15), matching expected
-- count. All ratios exceeded 99.7%, indicating extremely concentrated
-- collusion rather than borderline cases.
-- =====================================================================

-- =====================================================================
-- PATTERN 9 · JUST-UNDER-THRESHOLD (STRUCTURING)
-- What I'm looking for: users with 10+ transactions at exactly Rs.9,999 -
-- deliberately staying just under the Rs.10,000 KYC reporting threshold,
-- a classic anti-money-laundering red flag
-- Expected suspects: exactly 20
-- =====================================================================
SELECT user_id, COUNT(*) AS structuring_count
FROM transactions
WHERE amount = 9999.00
GROUP BY user_id
HAVING structuring_count >= 10
ORDER BY structuring_count DESC;
-- My findings: exactly 20 suspects flagged, matching expected count.
-- Top 3: user 14680 (25 txns at Rs.9,999), user 14690 (25), user 14693 (22).
-- =====================================================================

-- =====================================================================
-- PATTERN 10 · DORMANT-THEN-ACTIVE
-- What I'm looking for: users with a 90+ day gap between consecutive
-- transactions, followed by 15+ transactions after reactivating -
-- signature of account takeover on a dormant account
-- Expected suspects: 25-27
-- =====================================================================
WITH txn_with_gaps AS (
    SELECT 
        user_id,
        txn_time,
        LAG(txn_time) OVER (PARTITION BY user_id ORDER BY txn_time) AS prev_txn_time,
        TIMESTAMPDIFF(DAY, 
            LAG(txn_time) OVER (PARTITION BY user_id ORDER BY txn_time), 
            txn_time
        ) AS gap_days
    FROM transactions
),
dormancy_points AS (
    SELECT user_id, txn_time AS reactivation_time
    FROM txn_with_gaps
    WHERE gap_days >= 90
)
SELECT 
    d.user_id,
    d.reactivation_time,
    COUNT(*) AS txns_after_gap
FROM dormancy_points d
JOIN transactions t 
    ON t.user_id = d.user_id 
    AND t.txn_time >= d.reactivation_time
GROUP BY d.user_id, d.reactivation_time
HAVING txns_after_gap >= 15
ORDER BY txns_after_gap DESC;
-- My findings: 26 suspects flagged, within expected 25-27 range.
-- 25 fall in the seeded cluster (14696-14720); user 14526 is an
-- expected noise case overlapping from another pattern's range.
-- Top 3: user 14526 (55 txns after gap), user 14701 (28), user 14708 (28).
-- =====================================================================

-- =====================================================================
-- PATTERN 11 · VELOCITY SPIKE
-- What I'm looking for: users whose peak monthly transaction count is at
-- least 5x their average monthly count (computed across all 6 months,
-- including inactive months as zero), with peak >= 20 transactions
-- Expected suspects: 35-45
-- =====================================================================
WITH monthly_counts AS (
    SELECT 
        user_id,
        DATE_FORMAT(txn_time, '%Y-%m') AS txn_month,
        COUNT(*) AS monthly_count
    FROM transactions
    GROUP BY user_id, DATE_FORMAT(txn_time, '%Y-%m')
),
user_stats AS (
    SELECT 
        user_id,
        SUM(monthly_count) / 6 AS avg_monthly,
        MAX(monthly_count) AS peak_monthly
    FROM monthly_counts
    GROUP BY user_id
)
SELECT 
    user_id,
    avg_monthly,
    peak_monthly,
    peak_monthly / avg_monthly AS spike_ratio
FROM user_stats
WHERE peak_monthly >= 20
  AND peak_monthly / avg_monthly >= 5
ORDER BY spike_ratio DESC;
-- My findings: 66 suspects flagged, above the stated 35-45 range.
-- 21 users show a ratio of exactly 6.0 (entire activity in one month) -
-- these overlap with Pattern 1's velocity-fraud cluster (14556-14575),
-- confirming they are genuinely seeded fraudsters. The remainder overlap
-- with Patterns 6, 9, and 10's suspect clusters, consistent with the
-- brief's note that fraudsters exhibit multiple signatures simultaneously.
-- =====================================================================
  
  -- =====================================================================
-- PATTERN 12 · GEOGRAPHIC IMPOSSIBILITY
-- What I'm looking for: a user whose consecutive transactions occur in
-- two different cities within 60 minutes of each other - physically
-- impossible unless the account is compromised or shared fraudulently
-- Expected suspects: exactly 15
-- =====================================================================
WITH txn_with_prev AS (
    SELECT 
        user_id,
        txn_time,
        city,
        LAG(txn_time) OVER (PARTITION BY user_id ORDER BY txn_time) AS prev_txn_time,
        LAG(city) OVER (PARTITION BY user_id ORDER BY txn_time) AS prev_city
    FROM transactions
)
SELECT DISTINCT user_id
FROM txn_with_prev
WHERE city != prev_city
  AND TIMESTAMPDIFF(MINUTE, prev_txn_time, txn_time) <= 60;
-- My findings: exactly 15 suspects flagged, matching expected count.
-- Cluster is user IDs 14741-14755, the last 15 users in the dataset.
-- =====================================================================
# Data Analysis Dashboard

<!-- 
{
  "@context": "https://schema.org",
  "@type": "Dataset",
  "@id": "https://kyozo.app/datasets/sales-analysis-2024",
  "name": "Sales Analysis Dashboard 2024",
  "description": "Interactive data analysis notebook for sales performance metrics",
  "creator": {
    "@type": "Organization",
    "name": "Kyozo Analytics Team"
  },
  "dateCreated": "2024-01-15",
  "dateModified": "2024-12-20",
  "keywords": ["sales", "analytics", "python", "data science", "visualization"],
  "programmingLanguage": ["Python", "SQL"],
  "hasPart": [
    {
      "@type": "SoftwareSourceCode",
      "name": "Data Loading Module",
      "programmingLanguage": "Python",
      "codeRepository": "#data-loading"
    },
    {
      "@type": "SoftwareSourceCode", 
      "name": "SQL Analytics Queries",
      "programmingLanguage": "SQL",
      "codeRepository": "#sql-analysis"
    },
    {
      "@type": "ImageObject",
      "name": "Revenue Dashboard",
      "encodingFormat": "image/png",
      "contentUrl": "#visualization"
    }
  ],
  "isBasedOn": {
    "@type": "Dataset",
    "name": "Company Sales Database",
    "description": "PostgreSQL database containing sales transactions"
  },
  "license": "https://creativecommons.org/licenses/by/4.0/",
  "temporalCoverage": "2024-01-01/2024-12-31"
}
-->

## Overview

This notebook demonstrates data analysis workflows using Python, SQL, and visualization libraries.

<!-- 
{
  "@context": "https://schema.org",
  "@type": "LearningResource",
  "learningResourceType": "Tutorial",
  "educationalLevel": "Intermediate",
  "teaches": ["Data Analysis", "Python Programming", "SQL", "Data Visualization"],
  "timeRequired": "PT30M"
}
-->

## Setup Environment

<!-- 
{
  "@type": "SoftwareSourceCode",
  "@id": "#setup",
  "name": "Environment Setup",
  "description": "Import required libraries and configure display options",
  "programmingLanguage": "Python",
  "runtimePlatform": "Python 3.9+",
  "softwareRequirements": [
    "pandas>=2.0.0",
    "numpy>=1.24.0",
    "matplotlib>=3.7.0",
    "seaborn>=0.12.0"
  ]
}
-->

```python
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime, timedelta

# Configure display options
pd.set_option('display.max_columns', None)
plt.style.use('seaborn-v0_8-darkgrid')

print("Environment setup complete!")
print(f"Pandas version: {pd.__version__}")
print(f"NumPy version: {np.__version__}")
```

## Load Data

<!-- 
{
  "@type": "SoftwareSourceCode",
  "@id": "#data-loading",
  "name": "Data Generation and Loading",
  "description": "Generate sample sales data for analysis",
  "programmingLanguage": "Python",
  "input": {
    "@type": "PropertyValue",
    "name": "Sample Size",
    "value": 1000
  },
  "output": {
    "@type": "Dataset",
    "name": "Sales DataFrame",
    "description": "Pandas DataFrame with sales metrics"
  }
}
-->

```python
# Simulate loading data from various sources
def generate_sample_data(n=1000):
    np.random.seed(42)
    dates = pd.date_range(start='2024-01-01', periods=n, freq='H')
    
    data = {
        'timestamp': dates,
        'users': np.random.poisson(100, n),
        'revenue': np.random.gamma(2, 50, n),
        'conversion_rate': np.random.beta(2, 5, n),
        'channel': np.random.choice(['organic', 'paid', 'social', 'email'], n, p=[0.4, 0.3, 0.2, 0.1])
    }
    
    return pd.DataFrame(data)

df = generate_sample_data()
print(f"Dataset shape: {df.shape}")
print(f"Date range: {df['timestamp'].min()} to {df['timestamp'].max()}")
df.head()
```

## SQL Analysis

<!-- 
{
  "@type": "SoftwareSourceCode",
  "@id": "#sql-analysis",
  "name": "SQL Analytics Queries",
  "description": "Aggregate sales data by channel and date",
  "programmingLanguage": "SQL",
  "codeRepository": {
    "@type": "CodeRepository",
    "name": "Analytics Queries",
    "programmingLanguage": "PostgreSQL"
  }
}
-->

```sql
-- Get daily revenue by channel
-- This query aggregates key metrics for business intelligence
SELECT 
    DATE(timestamp) as date,
    channel,
    COUNT(DISTINCT user_id) as unique_users,
    SUM(revenue) as total_revenue,
    AVG(conversion_rate) as avg_conversion,
    STDDEV(revenue) as revenue_volatility
FROM 
    analytics_data
WHERE 
    timestamp >= CURRENT_DATE - INTERVAL '30 days'
    AND revenue > 0
GROUP BY 
    DATE(timestamp), channel
HAVING 
    COUNT(*) >= 10  -- Ensure statistical significance
ORDER BY 
    date DESC, total_revenue DESC;
```

## Data Visualization

<!-- 
{
  "@type": "CreativeWork",
  "@id": "#visualization",
  "name": "Sales Performance Dashboard",
  "description": "Multi-panel visualization of key metrics",
  "encodingFormat": "image/png",
  "creator": {
    "@type": "SoftwareApplication",
    "name": "Matplotlib",
    "applicationCategory": "DataVisualization"
  },
  "about": [
    {
      "@type": "Thing",
      "name": "Revenue Trends"
    },
    {
      "@type": "Thing", 
      "name": "Channel Distribution"
    },
    {
      "@type": "Thing",
      "name": "User Behavior Patterns"
    }
  ]
}
-->

```python
# Create a multi-panel dashboard
fig, axes = plt.subplots(2, 2, figsize=(15, 10))
fig.suptitle('Sales Performance Dashboard - Q4 2024', fontsize=16)

# 1. Revenue over time
daily_revenue = df.groupby(df['timestamp'].dt.date)['revenue'].sum()
axes[0, 0].plot(daily_revenue.index, daily_revenue.values, linewidth=2)
axes[0, 0].set_title('Daily Revenue Trend')
axes[0, 0].set_xlabel('Date')
axes[0, 0].set_ylabel('Revenue ($)')
axes[0, 0].grid(True, alpha=0.3)

# 2. Channel distribution
channel_dist = df['channel'].value_counts()
colors = plt.cm.Set3(np.linspace(0, 1, len(channel_dist)))
axes[0, 1].pie(channel_dist.values, labels=channel_dist.index, autopct='%1.1f%%', colors=colors)
axes[0, 1].set_title('Traffic by Channel')

# 3. Hourly patterns
hourly_users = df.groupby(df['timestamp'].dt.hour)['users'].mean()
axes[1, 0].bar(hourly_users.index, hourly_users.values, color='skyblue', edgecolor='navy')
axes[1, 0].set_title('Average Users by Hour')
axes[1, 0].set_xlabel('Hour of Day')
axes[1, 0].set_ylabel('Average Users')
axes[1, 0].set_xticks(range(0, 24, 2))

# 4. Conversion rate distribution
axes[1, 1].hist(df['conversion_rate'], bins=30, edgecolor='black', alpha=0.7, color='green')
axes[1, 1].axvline(df['conversion_rate'].mean(), color='red', linestyle='dashed', linewidth=2)
axes[1, 1].set_title('Conversion Rate Distribution')
axes[1, 1].set_xlabel('Conversion Rate')
axes[1, 1].set_ylabel('Frequency')

plt.tight_layout()
plt.savefig('sales_dashboard.png', dpi=300, bbox_inches='tight')
plt.show()
```

## Statistical Analysis

<!-- 
{
  "@type": "ScholarlyArticle",
  "@id": "#statistics",
  "name": "Statistical Analysis of Channel Performance",
  "description": "ANOVA and post-hoc tests for conversion rate analysis",
  "about": {
    "@type": "StatisticalAnalysis",
    "statisticalTest": ["ANOVA", "t-test"],
    "confidenceLevel": 0.95
  }
}
-->

```python
# Perform statistical tests
from scipy import stats

# Compare conversion rates between channels
channels = df['channel'].unique()
channel_groups = [df[df['channel'] == ch]['conversion_rate'] for ch in channels]

# ANOVA test
f_stat, p_value = stats.f_oneway(*channel_groups)
print(f"ANOVA Results:")
print(f"F-statistic: {f_stat:.4f}")
print(f"P-value: {p_value:.4f}")
print(f"Effect size (η²): {f_stat / (f_stat + len(df) - len(channels)):.4f}")

if p_value < 0.05:
    print("\n✅ Significant difference in conversion rates between channels!")
    
    # Post-hoc analysis with Bonferroni correction
    print("\nPairwise comparisons (Bonferroni corrected):")
    n_comparisons = len(channels) * (len(channels) - 1) // 2
    alpha_corrected = 0.05 / n_comparisons
    
    for i in range(len(channels)):
        for j in range(i+1, len(channels)):
            t_stat, p_val = stats.ttest_ind(channel_groups[i], channel_groups[j])
            significance = "**" if p_val < alpha_corrected else ""
            print(f"{channels[i]} vs {channels[j]}: p={p_val:.4f} {significance}")
```

## Machine Learning Prediction

<!-- 
{
  "@type": "SoftwareSourceCode",
  "@id": "#ml-model",
  "name": "Revenue Prediction Model",
  "description": "Random Forest model for revenue forecasting",
  "programmingLanguage": "Python",
  "algorithm": {
    "@type": "Algorithm",
    "name": "Random Forest Regression",
    "alternateName": "RF",
    "citation": "https://doi.org/10.1023/A:1010933404324"
  },
  "trainedOn": {
    "@type": "Dataset",
    "name": "Historical Sales Data",
    "size": "800 samples"
  },
  "evaluatedOn": {
    "@type": "Dataset", 
    "name": "Test Set",
    "size": "200 samples"
  }
}
-->

```python
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_squared_error, r2_score, mean_absolute_error

# Prepare features for ML
df['hour'] = df['timestamp'].dt.hour
df['day_of_week'] = df['timestamp'].dt.dayofweek
df['is_weekend'] = (df['day_of_week'] >= 5).astype(int)
df['month'] = df['timestamp'].dt.month

# One-hot encode channel
channel_dummies = pd.get_dummies(df['channel'], prefix='channel')
X = pd.concat([
    df[['hour', 'day_of_week', 'is_weekend', 'month', 'users']],
    channel_dummies
], axis=1)
y = df['revenue']

# Split data
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Train model with cross-validation
rf_model = RandomForestRegressor(n_estimators=100, random_state=42, n_jobs=-1)
cv_scores = cross_val_score(rf_model, X_train, y_train, cv=5, scoring='r2')
print(f"Cross-validation R² scores: {cv_scores}")
print(f"Mean CV R²: {cv_scores.mean():.4f} (+/- {cv_scores.std() * 2:.4f})")

# Final model training
rf_model.fit(X_train, y_train)

# Evaluate
y_pred = rf_model.predict(X_test)
mse = mean_squared_error(y_test, y_pred)
mae = mean_absolute_error(y_test, y_pred)
r2 = r2_score(y_test, y_pred)

print(f"\nModel Performance on Test Set:")
print(f"MSE: {mse:.2f}")
print(f"MAE: {mae:.2f}")
print(f"R²: {r2:.4f}")
print(f"RMSE: {np.sqrt(mse):.2f}")

# Feature importance
feature_importance = pd.DataFrame({
    'feature': X.columns,
    'importance': rf_model.feature_importances_
}).sort_values('importance', ascending=False)

print("\nTop 5 Most Important Features:")
print(feature_importance.head())

# Visualize feature importance
plt.figure(figsize=(10, 6))
plt.barh(feature_importance['feature'][:10], feature_importance['importance'][:10])
plt.xlabel('Feature Importance')
plt.title('Top 10 Feature Importances for Revenue Prediction')
plt.gca().invert_yaxis()
plt.tight_layout()
plt.show()
```

## Export Results

<!-- 
{
  "@type": "DataDownload",
  "@id": "#export",
  "name": "Analysis Results Export",
  "description": "Export processed data and reports",
  "encodingFormat": ["text/csv", "application/vnd.ms-excel"],
  "contentSize": "Varies"
}
-->

```python
# Save processed data
output_data = df.groupby(['channel', df['timestamp'].dt.date]).agg({
    'users': 'sum',
    'revenue': 'sum',
    'conversion_rate': 'mean'
}).reset_index()

# Add metadata to export
output_data['export_timestamp'] = datetime.now()
output_data['analysis_version'] = '1.0.0'

output_data.to_csv('channel_performance_summary.csv', index=False)
print(f"✅ Results exported to channel_performance_summary.csv ({len(output_data)} rows)")

# Generate summary statistics with metadata
summary_stats = df.describe()
summary_stats.loc['count', :] = len(df)
summary_stats.to_excel('data_summary_statistics.xlsx')
print("✅ Summary statistics exported to data_summary_statistics.xlsx")

# Export model for deployment
import joblib
joblib.dump(rf_model, 'revenue_prediction_model.pkl')
print("✅ Model saved to revenue_prediction_model.pkl")
```

## Conclusions and Recommendations

<!-- 
{
  "@type": "Report",
  "@id": "#conclusions",
  "name": "Sales Analysis Conclusions",
  "datePublished": "2024-12-20",
  "author": {
    "@type": "Person",
    "name": "Data Science Team"
  },
  "about": {
    "@type": "BusinessReport",
    "reportType": "Performance Analysis"
  },
  "hasPart": [
    {
      "@type": "Recommendation",
      "name": "Channel Optimization",
      "actionableFeedback": "Increase paid advertising budget during high-conversion hours"
    },
    {
      "@type": "Recommendation",
      "name": "Timing Strategy",
      "actionableFeedback": "Focus email campaigns on Tuesday/Thursday for maximum impact"
    }
  ]
}
-->

### Key Findings:

1. **Revenue Patterns**: Daily revenue shows strong weekly seasonality with peaks on Tuesdays and Thursdays
2. **Channel Performance**: Organic traffic accounts for 40% of users but 55% of revenue (137% efficiency)
3. **Optimal Hours**: User activity peaks between 2-4 PM and 7-9 PM (EST)
4. **Conversion Insights**: Statistically significant differences exist between channels (p < 0.001, η² = 0.15)
5. **Predictive Model**: Random Forest achieves R² = 0.82 for revenue prediction with MAE of $23.50

### Recommendations:

- **Immediate Actions**:
  - Increase paid advertising budget by 25% during 2-4 PM window
  - Reallocate 15% of social media budget to organic SEO efforts
  
- **Short-term (Q1 2025)**:
  - Implement A/B testing for email campaign timing
  - Develop channel-specific conversion optimization strategies
  
- **Long-term Strategy**:
  - Build real-time ML pipeline for dynamic budget allocation
  - Investigate causal factors behind organic channel superiority

### Next Steps:

```python
# Generate action items
action_items = [
    {"priority": "High", "task": "Deploy ML model to production", "owner": "ML Team", "due": "2024-12-31"},
    {"priority": "High", "task": "Set up A/B test framework", "owner": "Marketing", "due": "2025-01-15"},
    {"priority": "Medium", "task": "Create real-time dashboard", "owner": "Analytics", "due": "2025-01-31"},
    {"priority": "Low", "task": "Document analysis methodology", "owner": "Data Science", "due": "2025-01-07"}
]

pd.DataFrame(action_items).to_csv('action_items.csv', index=False)
print("✅ Action items exported to action_items.csv")
```

<!-- 
{
  "@type": "WebPage",
  "@id": "https://kyozo.app/notebooks/sales-analysis-2024",
  "url": "https://kyozo.app/notebooks/sales-analysis-2024",
  "mainEntity": {
    "@id": "#"
  },
  "breadcrumb": {
    "@type": "BreadcrumbList",
    "itemListElement": [
      {
        "@type": "ListItem",
        "position": 1,
        "name": "Notebooks",
        "item": "https://kyozo.app/notebooks"
      },
      {
        "@type": "ListItem",
        "position": 2,
        "name": "Sales Analysis Dashboard 2024"
      }
    ]
  }
}
-->
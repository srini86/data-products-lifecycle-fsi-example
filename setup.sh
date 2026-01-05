#!/bin/bash
# ============================================================================
# Data Products for FSI - Setup Script
# ============================================================================
# This script helps you deploy the sample data product to your Snowflake
# account. It can be run interactively or with environment variables.
#
# Usage:
#   ./setup.sh              # Interactive mode
#   ./setup.sh --help       # Show help
#   ./setup.sh --snowsql    # Generate SnowSQL commands
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
DEFAULT_DATABASE="RETAIL_BANKING_DB"
DEFAULT_WAREHOUSE="COMPUTE_WH"

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${CYAN}$1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}▶${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

show_help() {
    cat << EOF
Data Products for FSI - Setup Script

USAGE:
    ./setup.sh [OPTIONS]

OPTIONS:
    --help          Show this help message
    --snowsql       Generate SnowSQL commands (copy-paste to run)
    --dry-run       Show what would be done without executing
    --skip-data     Skip sample data creation
    --skip-dbt      Skip dbt model deployment info
    --skip-monitor  Skip monitoring setup

ENVIRONMENT VARIABLES:
    SNOWFLAKE_ACCOUNT     Your Snowflake account identifier
    SNOWFLAKE_USER        Your Snowflake username
    SNOWFLAKE_WAREHOUSE   Warehouse to use (default: COMPUTE_WH)
    SNOWFLAKE_DATABASE    Database name (default: RETAIL_BANKING_DB)

EXAMPLES:
    # Interactive setup
    ./setup.sh

    # Generate commands for SnowSQL
    ./setup.sh --snowsql > commands.sql

    # Set environment and run
    export SNOWFLAKE_ACCOUNT="xy12345.us-east-1"
    ./setup.sh

EOF
}

# ============================================================================
# Check Prerequisites
# ============================================================================

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local all_good=true
    
    # Check for SnowSQL (optional)
    if command -v snowsql &> /dev/null; then
        print_success "SnowSQL CLI found"
        SNOWSQL_AVAILABLE=true
    else
        print_info "SnowSQL CLI not found (optional - you can run SQL manually)"
        SNOWSQL_AVAILABLE=false
    fi
    
    # Check for required files
    local required_files=(
        "03_deliver/03a_create_sample_data.sql"
        "03_deliver/03c_output_examples/retail_customer_churn_risk.sql"
        "03_deliver/03c_output_examples/masking_policies.sql"
        "03_deliver/03d_semantic_view_marketplace.sql"
        "04_operate/monitoring_observability.sql"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$SCRIPT_DIR/$file" ]]; then
            print_success "Found: $file"
        else
            print_error "Missing: $file"
            all_good=false
        fi
    done
    
    if [[ "$all_good" == false ]]; then
        print_error "Some required files are missing. Please ensure you have the complete repository."
        exit 1
    fi
    
    echo ""
}

# ============================================================================
# Collect Configuration
# ============================================================================

collect_config() {
    print_header "Configuration"
    
    # Use environment variables or prompt
    if [[ -z "$SNOWFLAKE_DATABASE" ]]; then
        read -p "Database name [$DEFAULT_DATABASE]: " SNOWFLAKE_DATABASE
        SNOWFLAKE_DATABASE=${SNOWFLAKE_DATABASE:-$DEFAULT_DATABASE}
    fi
    
    if [[ -z "$SNOWFLAKE_WAREHOUSE" ]]; then
        read -p "Warehouse name [$DEFAULT_WAREHOUSE]: " SNOWFLAKE_WAREHOUSE
        SNOWFLAKE_WAREHOUSE=${SNOWFLAKE_WAREHOUSE:-$DEFAULT_WAREHOUSE}
    fi
    
    echo ""
    print_info "Configuration:"
    echo "  Database:  $SNOWFLAKE_DATABASE"
    echo "  Warehouse: $SNOWFLAKE_WAREHOUSE"
    echo ""
}

# ============================================================================
# Generate SnowSQL Commands
# ============================================================================

generate_snowsql_commands() {
    print_header "SnowSQL Commands"
    
    cat << EOF
-- ============================================================================
-- DATA PRODUCTS FOR FSI - SNOWFLAKE SETUP
-- ============================================================================
-- Run these commands in Snowflake Snowsight or SnowSQL
-- Generated: $(date)
-- ============================================================================

-- Step 1: Set context
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE ${SNOWFLAKE_WAREHOUSE:-COMPUTE_WH};

-- ============================================================================
-- STEP 1: CREATE SAMPLE DATA
-- ============================================================================
-- Run the contents of: 03_deliver/03a_create_sample_data.sql
-- This creates the database, schemas, and sample data

-- ============================================================================
-- STEP 2: CREATE DATA PRODUCTS SCHEMA
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS ${SNOWFLAKE_DATABASE:-RETAIL_BANKING_DB}.DATA_PRODUCTS;
USE SCHEMA ${SNOWFLAKE_DATABASE:-RETAIL_BANKING_DB}.DATA_PRODUCTS;

-- ============================================================================
-- STEP 3: DEPLOY DBT MODEL
-- ============================================================================
-- Option A: Copy SQL from 03_deliver/03c_output_examples/retail_customer_churn_risk.sql
-- Option B: Use dbt Core or Snowflake dbt Projects

-- ============================================================================
-- STEP 4: APPLY MASKING POLICIES
-- ============================================================================
-- Run the contents of: 03_deliver/03c_output_examples/masking_policies.sql

-- ============================================================================
-- STEP 5: RUN BUSINESS RULES TESTS
-- ============================================================================
-- Run the contents of: 03_deliver/03c_output_examples/business_rules_tests.sql

-- ============================================================================
-- STEP 6: CREATE SEMANTIC VIEW & MARKETPLACE
-- ============================================================================
-- Run the contents of: 03_deliver/03d_semantic_view_marketplace.sql

-- ============================================================================
-- STEP 7: SET UP MONITORING
-- ============================================================================
-- Run the contents of: 04_operate/monitoring_observability.sql

-- ============================================================================
-- STEP 8: (OPTIONAL) DEPLOY STREAMLIT APP
-- ============================================================================
-- Upload the Streamlit app for contract-driven code generation

CREATE STAGE IF NOT EXISTS ${SNOWFLAKE_DATABASE:-RETAIL_BANKING_DB}.RAW.APP_STAGE;

-- Upload using SnowSQL:
-- PUT file://${SCRIPT_DIR}/03_deliver/03b_dbt_generator_app.py @${SNOWFLAKE_DATABASE:-RETAIL_BANKING_DB}.RAW.APP_STAGE;

CREATE OR REPLACE STREAMLIT ${SNOWFLAKE_DATABASE:-RETAIL_BANKING_DB}.RAW.DBT_CODE_GENERATOR
  ROOT_LOCATION = '@${SNOWFLAKE_DATABASE:-RETAIL_BANKING_DB}.RAW.APP_STAGE'
  MAIN_FILE = '03b_dbt_generator_app.py'
  QUERY_WAREHOUSE = ${SNOWFLAKE_WAREHOUSE:-COMPUTE_WH};

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check sample data
SELECT 'CUSTOMERS' as table_name, COUNT(*) as row_count FROM ${SNOWFLAKE_DATABASE:-RETAIL_BANKING_DB}.RAW.CUSTOMERS
UNION ALL
SELECT 'ACCOUNTS', COUNT(*) FROM ${SNOWFLAKE_DATABASE:-RETAIL_BANKING_DB}.RAW.ACCOUNTS
UNION ALL
SELECT 'TRANSACTIONS', COUNT(*) FROM ${SNOWFLAKE_DATABASE:-RETAIL_BANKING_DB}.RAW.TRANSACTIONS
UNION ALL
SELECT 'DIGITAL_ENGAGEMENT', COUNT(*) FROM ${SNOWFLAKE_DATABASE:-RETAIL_BANKING_DB}.RAW.DIGITAL_ENGAGEMENT
UNION ALL
SELECT 'COMPLAINTS', COUNT(*) FROM ${SNOWFLAKE_DATABASE:-RETAIL_BANKING_DB}.RAW.COMPLAINTS;

-- Check data product
SELECT 
    COUNT(*) as total_customers,
    COUNT(CASE WHEN risk_tier = 'LOW' THEN 1 END) as low_risk,
    COUNT(CASE WHEN risk_tier = 'MEDIUM' THEN 1 END) as medium_risk,
    COUNT(CASE WHEN risk_tier = 'HIGH' THEN 1 END) as high_risk,
    COUNT(CASE WHEN risk_tier = 'CRITICAL' THEN 1 END) as critical_risk
FROM ${SNOWFLAKE_DATABASE:-RETAIL_BANKING_DB}.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK;

-- ============================================================================
-- SETUP COMPLETE!
-- ============================================================================
EOF
}

# ============================================================================
# Interactive Setup Steps
# ============================================================================

step_create_sample_data() {
    print_header "Step 1: Create Sample Data"
    
    print_info "This step creates the database, schemas, and sample data."
    print_info "Source: 03_deliver/03a_create_sample_data.sql"
    echo ""
    
    if [[ "$SNOWSQL_AVAILABLE" == true ]]; then
        read -p "Run with SnowSQL? (y/n): " run_snowsql
        if [[ "$run_snowsql" == "y" || "$run_snowsql" == "Y" ]]; then
            print_step "Running 03a_create_sample_data.sql..."
            snowsql -f "$SCRIPT_DIR/03_deliver/03a_create_sample_data.sql"
            print_success "Sample data created!"
        else
            print_info "Please run manually in Snowsight:"
            echo "  File: 03_deliver/03a_create_sample_data.sql"
        fi
    else
        print_info "To create sample data, run in Snowflake Snowsight:"
        echo ""
        echo "  1. Open Snowsight (https://app.snowflake.com)"
        echo "  2. Go to Worksheets"
        echo "  3. Create new worksheet"
        echo "  4. Copy contents of: 03_deliver/03a_create_sample_data.sql"
        echo "  5. Run all"
    fi
    
    echo ""
    read -p "Press Enter when ready to continue..."
}

step_deploy_dbt_model() {
    print_header "Step 2: Deploy dbt Model"
    
    print_info "The dbt model creates the RETAIL_CUSTOMER_CHURN_RISK table."
    echo ""
    
    echo "Choose deployment method:"
    echo "  1. Copy SQL directly to Snowflake (simplest)"
    echo "  2. Use Snowflake dbt Projects"
    echo "  3. Use dbt Core locally"
    echo ""
    
    read -p "Enter choice (1/2/3): " dbt_choice
    
    case $dbt_choice in
        1)
            print_info "Copy the SQL from these files to Snowflake:"
            echo "  - 03_deliver/03c_output_examples/retail_customer_churn_risk.sql"
            echo ""
            echo "Wrap in CREATE TABLE AS:"
            echo ""
            echo "  CREATE OR REPLACE TABLE ${SNOWFLAKE_DATABASE}.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK AS"
            echo "  <paste the SELECT statement>"
            ;;
        2)
            print_info "For Snowflake dbt Projects:"
            echo "  1. Create new dbt project in Snowflake"
            echo "  2. Upload these files:"
            echo "     - 03c_output_examples/retail_customer_churn_risk.sql → models/"
            echo "     - 03c_output_examples/schema.yml → models/"
            echo "  3. Run: dbt run --select retail_customer_churn_risk"
            ;;
        3)
            print_info "For dbt Core:"
            echo ""
            echo "  # Copy files"
            echo "  cp 03_deliver/03c_output_examples/retail_customer_churn_risk.sql ~/dbt_project/models/"
            echo "  cp 03_deliver/03c_output_examples/schema.yml ~/dbt_project/models/"
            echo ""
            echo "  # Configure profiles.yml for Snowflake"
            echo "  # Run dbt"
            echo "  dbt run --select retail_customer_churn_risk"
            echo "  dbt test --select retail_customer_churn_risk"
            ;;
    esac
    
    echo ""
    read -p "Press Enter when ready to continue..."
}

step_apply_masking() {
    print_header "Step 3: Apply Masking Policies"
    
    print_info "This step creates and applies masking policies for PII protection."
    print_info "Source: 03_deliver/03c_output_examples/masking_policies.sql"
    echo ""
    
    if [[ "$SNOWSQL_AVAILABLE" == true ]]; then
        read -p "Run with SnowSQL? (y/n): " run_snowsql
        if [[ "$run_snowsql" == "y" || "$run_snowsql" == "Y" ]]; then
            print_step "Running masking_policies.sql..."
            snowsql -f "$SCRIPT_DIR/03_deliver/03c_output_examples/masking_policies.sql"
            print_success "Masking policies applied!"
        else
            print_info "Please run manually in Snowsight:"
            echo "  File: 03_deliver/03c_output_examples/masking_policies.sql"
        fi
    else
        print_info "Run in Snowflake Snowsight:"
        echo "  File: 03_deliver/03c_output_examples/masking_policies.sql"
    fi
    
    echo ""
    read -p "Press Enter when ready to continue..."
}

step_run_tests() {
    print_header "Step 4: Run Business Rules Tests"
    
    print_info "This step validates the data against business rules."
    print_info "Source: 03_deliver/03c_output_examples/business_rules_tests.sql"
    echo ""
    
    print_info "Run in Snowflake Snowsight to see test results:"
    echo "  File: 03_deliver/03c_output_examples/business_rules_tests.sql"
    echo ""
    echo "Expected results: All tests should PASS"
    
    echo ""
    read -p "Press Enter when ready to continue..."
}

step_semantic_view() {
    print_header "Step 5: Create Semantic View & Marketplace"
    
    print_info "This step creates the Semantic View and Internal Marketplace listing."
    print_info "Source: 03_deliver/03d_semantic_view_marketplace.sql"
    echo ""
    
    print_warning "Note: Some features may require Enterprise Edition"
    
    echo ""
    print_info "Run in Snowflake Snowsight:"
    echo "  File: 03_deliver/03d_semantic_view_marketplace.sql"
    
    echo ""
    read -p "Press Enter when ready to continue..."
}

step_monitoring() {
    print_header "Step 6: Set Up Monitoring"
    
    print_info "This step creates monitoring views, tasks, and alerts."
    print_info "Source: 04_operate/monitoring_observability.sql"
    echo ""
    
    if [[ "$SNOWSQL_AVAILABLE" == true ]]; then
        read -p "Run with SnowSQL? (y/n): " run_snowsql
        if [[ "$run_snowsql" == "y" || "$run_snowsql" == "Y" ]]; then
            print_step "Running monitoring_observability.sql..."
            snowsql -f "$SCRIPT_DIR/04_operate/monitoring_observability.sql"
            print_success "Monitoring set up!"
        else
            print_info "Please run manually in Snowsight:"
            echo "  File: 04_operate/monitoring_observability.sql"
        fi
    else
        print_info "Run in Snowflake Snowsight:"
        echo "  File: 04_operate/monitoring_observability.sql"
    fi
    
    echo ""
    read -p "Press Enter when ready to continue..."
}

step_streamlit_app() {
    print_header "Step 7: (Optional) Deploy Streamlit App"
    
    print_info "The Streamlit app generates dbt code from data contracts."
    print_info "Source: 03_deliver/03b_dbt_generator_app.py"
    echo ""
    
    read -p "Deploy Streamlit app? (y/n): " deploy_app
    
    if [[ "$deploy_app" == "y" || "$deploy_app" == "Y" ]]; then
        print_info "To deploy the Streamlit app:"
        echo ""
        echo "  1. Create a stage:"
        echo "     CREATE STAGE IF NOT EXISTS ${SNOWFLAKE_DATABASE}.RAW.APP_STAGE;"
        echo ""
        echo "  2. Upload the Python file (using Snowsight or SnowSQL PUT):"
        echo "     PUT file://$SCRIPT_DIR/03_deliver/03b_dbt_generator_app.py @${SNOWFLAKE_DATABASE}.RAW.APP_STAGE;"
        echo ""
        echo "  3. Create the Streamlit app:"
        echo "     CREATE STREAMLIT ${SNOWFLAKE_DATABASE}.RAW.DBT_CODE_GENERATOR"
        echo "       ROOT_LOCATION = '@${SNOWFLAKE_DATABASE}.RAW.APP_STAGE'"
        echo "       MAIN_FILE = '03b_dbt_generator_app.py'"
        echo "       QUERY_WAREHOUSE = ${SNOWFLAKE_WAREHOUSE};"
    else
        print_info "Skipping Streamlit app deployment."
    fi
    
    echo ""
}

show_summary() {
    print_header "Setup Complete!"
    
    echo -e "${GREEN}Your data product environment is ready!${NC}"
    echo ""
    echo "What was created:"
    echo "  ✓ Database: ${SNOWFLAKE_DATABASE}"
    echo "  ✓ Schemas: RAW, DATA_PRODUCTS, MONITORING"
    echo "  ✓ Sample data: ~1,000 customers, ~50,000 transactions"
    echo "  ✓ Data product: RETAIL_CUSTOMER_CHURN_RISK"
    echo "  ✓ Masking policies: customer_name_mask"
    echo "  ✓ Monitoring: Quality checks, freshness, usage"
    echo ""
    echo "Next steps:"
    echo "  1. Query the data product:"
    echo "     SELECT * FROM ${SNOWFLAKE_DATABASE}.DATA_PRODUCTS.RETAIL_CUSTOMER_CHURN_RISK LIMIT 10;"
    echo ""
    echo "  2. Check monitoring status:"
    echo "     SELECT * FROM MONITORING.data_product_health_summary;"
    echo ""
    echo "  3. Explore the data contract:"
    echo "     cat 02_design/churn_risk_data_contract.yaml"
    echo ""
    print_info "For questions: retail-data-support@bank.com"
    echo ""
}

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                show_help
                exit 0
                ;;
            --snowsql)
                collect_config
                generate_snowsql_commands
                exit 0
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-data)
                SKIP_DATA=true
                shift
                ;;
            --skip-dbt)
                SKIP_DBT=true
                shift
                ;;
            --skip-monitor)
                SKIP_MONITOR=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Welcome banner
    clear
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                                ║${NC}"
    echo -e "${CYAN}║   🏦  Data Products for FSI - Setup Wizard                    ║${NC}"
    echo -e "${CYAN}║                                                                ║${NC}"
    echo -e "${CYAN}║   This wizard will help you deploy the sample data product   ║${NC}"
    echo -e "${CYAN}║   to your Snowflake account.                                  ║${NC}"
    echo -e "${CYAN}║                                                                ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Run setup steps
    check_prerequisites
    collect_config
    
    if [[ "$SKIP_DATA" != true ]]; then
        step_create_sample_data
    fi
    
    if [[ "$SKIP_DBT" != true ]]; then
        step_deploy_dbt_model
    fi
    
    step_apply_masking
    step_run_tests
    step_semantic_view
    
    if [[ "$SKIP_MONITOR" != true ]]; then
        step_monitoring
    fi
    
    step_streamlit_app
    show_summary
}

# Run main function
main "$@"


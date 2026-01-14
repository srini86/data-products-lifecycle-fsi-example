"""
============================================================================
DBT CODE GENERATOR - Streamlit in Snowflake (SiS) App
============================================================================
This app takes a Data Contract YAML as input and generates:
- dbt model SQL (transformation logic) - AI-generated via Cortex
- schema.yml (documentation and tests) - Template-based
- masking_policies.sql (Snowflake masking policies) - Template-based
- dmf_setup.sql (Data Metric Functions) - Template-based

The contract's English definitions (derivation, behavior) are interpreted
by Cortex LLM to produce Snowflake-native SQL for transformations.
Other outputs use deterministic template parsing.

Deploy to Snowflake:
1. Upload this file to a Snowflake stage
2. Create a Streamlit app pointing to this file
3. Grant appropriate permissions for Cortex access
============================================================================
"""

import streamlit as st
import yaml
import json
from datetime import datetime
from typing import Dict, List, Optional
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark import Session

# ============================================================================
# PAGE CONFIGURATION
# ============================================================================
st.set_page_config(
    page_title="DBT Code Generator",
    page_icon="🛠️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS
st.markdown("""
<style>
    .main-header {
        font-size: 2.2rem;
        font-weight: bold;
        color: #1e3a8a;
        text-align: center;
        margin-bottom: 1.5rem;
        padding: 1rem;
        background: linear-gradient(90deg, #dbeafe 0%, #ede9fe 100%);
        border-radius: 0.5rem;
    }
    .section-header {
        font-size: 1.3rem;
        font-weight: bold;
        color: #374151;
        margin-top: 1.5rem;
        margin-bottom: 0.75rem;
        border-bottom: 2px solid #e5e7eb;
        padding-bottom: 0.5rem;
    }
    .contract-card {
        background-color: #f0f9ff;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #0ea5e9;
        margin: 0.5rem 0;
    }
    .success-box {
        background-color: #ecfdf5;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #10b981;
        margin: 0.5rem 0;
    }
    .output-card {
        background-color: #fefce8;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #eab308;
        margin: 0.5rem 0;
    }
</style>
""", unsafe_allow_html=True)


# ============================================================================
# SESSION INITIALIZATION
# ============================================================================
def initialize_session():
    """Initialize Snowflake session"""
    if 'session' not in st.session_state:
        try:
            st.session_state.session = get_active_session()
            session_info = st.session_state.session.sql("""
                SELECT 
                    CURRENT_USER() as user,
                    CURRENT_DATABASE() as database,
                    CURRENT_SCHEMA() as schema,
                    CURRENT_WAREHOUSE() as warehouse
            """).collect()[0]
            st.session_state.session_info = {
                'user': session_info['USER'],
                'database': session_info['DATABASE'],
                'schema': session_info['SCHEMA'],
                'warehouse': session_info['WAREHOUSE']
            }
        except Exception as e:
            st.error(f"Failed to connect to Snowflake: {str(e)}")
            st.session_state.session = None


def execute_sql(sql: str, session: Session) -> List[Dict]:
    """Execute SQL and return results as list of dicts"""
    try:
        result = session.sql(sql).collect()
        return [row.as_dict() for row in result]
    except Exception as e:
        st.warning(f"SQL Error: {str(e)}")
        return []


# ============================================================================
# CONTRACT PARSING
# ============================================================================
def parse_contract(contract_yaml: str) -> Optional[Dict]:
    """Parse YAML contract and extract key information"""
    try:
        contract = yaml.safe_load(contract_yaml)
        return contract
    except yaml.YAMLError as e:
        st.error(f"Invalid YAML: {str(e)}")
        return None


def extract_contract_info(contract: Dict) -> Dict:
    """Extract key information from contract for display and generation"""
    metadata = contract.get('metadata', {})
    spec = contract.get('spec', {})
    source = spec.get('source', {})
    destination = spec.get('destination', {})
    schema = spec.get('schema', {})
    
    # Extract columns from schema properties with derivation info
    columns = []
    properties = schema.get('properties', {})
    for col_name, col_spec in properties.items():
        columns.append({
            'name': col_name,
            'type': col_spec.get('type', 'string'),
            'description': col_spec.get('description', ''),
            'derivation': col_spec.get('derivation', col_spec.get('source', '')),
            'required': col_spec.get('constraints', {}).get('required', False),
            'pii': col_spec.get('pii', False),
            'tags': col_spec.get('tags', []),
            'masking_policy': col_spec.get('masking_policy')
        })
    
    # Extract upstream tables with their details
    upstream_tables = source.get('upstream_tables', [])
    if isinstance(upstream_tables, list) and len(upstream_tables) > 0:
        if isinstance(upstream_tables[0], dict):
            # New format with details
            source_tables = upstream_tables
        else:
            # Old format - just strings
            source_tables = [{'name': t.split('.')[-1], 'location': t} for t in upstream_tables]
    else:
        source_tables = []
    
    return {
        'name': metadata.get('name', 'unknown'),
        'version': metadata.get('version', '1.0.0'),
        'title': spec.get('info', {}).get('title', ''),
        'description': spec.get('info', {}).get('description', ''),
        'owner': spec.get('info', {}).get('owner', {}),
        'source_tables': source_tables,
        'target_database': destination.get('database', ''),
        'target_schema': destination.get('schema', ''),
        'target_table': destination.get('table', ''),
        'materialization': destination.get('materialization', 'table'),
        'columns': columns,
        'grain': schema.get('grain', ''),
        'primary_key': schema.get('primary_key', ''),
        'data_quality': spec.get('data_quality', {}),
        'business_rules': spec.get('data_quality', {}).get('business_rules', []),
        'masking_policies': spec.get('masking_policies', {}),
        'access_control': spec.get('access_control', {}),
        'sla': spec.get('sla', {})
    }


# ============================================================================
# DBT MODEL GENERATION
# ============================================================================
def generate_dbt_model_prompt(contract_info: Dict) -> str:
    """Create prompt for Cortex to generate dbt model based on contract derivations"""
    
    # Build column specifications with derivation logic
    columns_with_derivations = []
    for col in contract_info['columns']:
        derivation = col.get('derivation', '')
        if derivation:
            columns_with_derivations.append(
                f"  - {col['name']} ({col['type']}): {col['description']}\n"
                f"    DERIVATION: {derivation}"
            )
        else:
            columns_with_derivations.append(
                f"  - {col['name']} ({col['type']}): {col['description']}"
            )
    
    columns_desc = "\n".join(columns_with_derivations)
    
    # Build source table information
    source_info = []
    for table in contract_info['source_tables']:
        if isinstance(table, dict):
            name = table.get('name', '')
            location = table.get('location', '')
            key_cols = table.get('key_columns', [])
            filter_cond = table.get('filter', '')
            source_info.append(
                f"  - {name} ({location})\n"
                f"    Key columns: {', '.join(key_cols) if key_cols else 'N/A'}\n"
                f"    Filter: {filter_cond if filter_cond else 'None'}"
            )
        else:
            source_info.append(f"  - {table}")
    
    source_tables = "\n".join(source_info)
    
    prompt = f"""You are an expert dbt developer generating Snowflake SQL. 
Generate a production-ready dbt model based on this data contract.

IMPORTANT: Generate ONLY valid SQL code. No explanations, just the complete dbt model.

DATA CONTRACT:
- Name: {contract_info['name']}
- Title: {contract_info['title']}
- Grain: {contract_info['grain']}
- Primary Key: {contract_info['primary_key']}

SOURCE TABLES:
{source_tables}

OUTPUT COLUMNS (with derivation logic):
{columns_desc}

REQUIREMENTS:
1. Start with dbt config block: materialized='{contract_info['materialization']}', unique_key='{contract_info['primary_key']}'
2. Use Snowflake SQL syntax
3. Use CTEs for each source table and aggregation step
4. Use dbt source() function for source tables: source('raw', 'table_name')
5. Implement ALL derivation logic exactly as specified
6. Handle NULLs with COALESCE where appropriate
7. Include comments for complex calculations
8. Output all specified columns in the final SELECT

Generate the complete SQL now:"""

    return prompt


def generate_masking_policy_prompt(policy_name: str, policy_def: Dict, contract_info: Dict) -> str:
    """Create prompt for Cortex to generate Snowflake masking policy"""
    
    authorized_roles = policy_def.get('authorized_roles', 
                                      contract_info.get('access_control', {}).get('authorized_roles', []))
    
    prompt = f"""Generate a Snowflake masking policy SQL based on this specification.

POLICY NAME: {policy_name}
DATA TYPE: {policy_def.get('data_type', 'STRING')}
APPLIES TO: {policy_def.get('applies_to', '')}
DESCRIPTION: {policy_def.get('description', '')}

BEHAVIOR:
{policy_def.get('behavior', 'Show full value for authorized roles, mask for others')}

AUTHORIZED ROLES:
{', '.join(authorized_roles)}

Generate ONLY the CREATE MASKING POLICY statement using Snowflake native functions.
Use CURRENT_ROLE() for role checking.
Use LEFT(), CONCAT() for string manipulation - no regex.
Include a COMMENT ON MASKING POLICY statement.

SQL:"""
    
    return prompt


def generate_schema_yml(contract_info: Dict) -> str:
    """Generate dbt schema.yml with tests and documentation from contract"""
    
    model_name = contract_info['target_table'].lower()
    
    # Build source definitions
    sources_yaml = {
        'version': 2,
        'sources': [{
            'name': 'raw',
            'database': contract_info['target_database'],
            'schema': 'RAW',
            'tables': []
        }]
    }
    
    for table in contract_info['source_tables']:
        if isinstance(table, dict):
            table_def = {
                'name': table.get('name', '').lower(),
                'description': table.get('description', '')
            }
        else:
            table_def = {'name': table.split('.')[-1].lower()}
        sources_yaml['sources'][0]['tables'].append(table_def)
    
    # Build column definitions with tests from contract
    columns_yaml = []
    for col in contract_info['columns']:
        col_def = {
            'name': col['name'],
            'description': col['description']
        }
        
        # Add tests based on constraints
        tests = []
        if col['name'] == contract_info['primary_key']:
            tests.extend(['unique', 'not_null'])
        elif col['required']:
            tests.append('not_null')
        
        # Add enum validation if present
        # (Would need to extract from constraints)
        
        if tests:
            col_def['tests'] = tests
        
        if col['tags']:
            col_def['tags'] = col['tags']
        
        columns_yaml.append(col_def)
    
    # Build model definition
    models_yaml = {
        'version': 2,
        'models': [{
            'name': model_name,
            'description': contract_info['description'],
            'config': {
                'materialized': contract_info['materialization'],
                'tags': ['data_product', 'generated_from_contract']
            },
            'meta': {
                'owner': contract_info['owner'].get('email', ''),
                'sla': contract_info['sla'].get('data_freshness', ''),
                'contract_version': contract_info['version']
            },
            'columns': columns_yaml
        }]
    }
    
    # Combine sources and models
    combined = "# ============================================================================\n"
    combined += "# SOURCES\n"
    combined += "# ============================================================================\n"
    combined += yaml.dump(sources_yaml, default_flow_style=False, sort_keys=False)
    combined += "\n\n"
    combined += "# ============================================================================\n"
    combined += "# MODELS\n"
    combined += "# ============================================================================\n"
    combined += yaml.dump(models_yaml, default_flow_style=False, sort_keys=False)
    
    return combined


def generate_masking_policies_sql(contract_info: Dict, session: Session = None, use_cortex: bool = False, model: str = "claude-3-5-sonnet") -> str:
    """Generate Snowflake masking policies SQL from contract"""
    
    masking_policies = contract_info.get('masking_policies', {})
    if not masking_policies:
        return "-- No masking policies defined in contract"
    
    sql_parts = [
        "-- ============================================================================",
        "-- MASKING POLICIES: Generated from Data Contract",
        "-- ============================================================================",
        f"-- Contract: {contract_info['name']} v{contract_info['version']}",
        f"-- Generated: {datetime.now().isoformat()}",
        "-- ============================================================================",
        "",
        f"USE ROLE ACCOUNTADMIN;",
        f"USE DATABASE {contract_info['target_database']};",
        f"USE SCHEMA {contract_info['target_schema']};",
        ""
    ]
    
    for policy_name, policy_def in masking_policies.items():
        # Get authorized roles
        authorized_roles = policy_def.get('authorized_roles', 
                                          contract_info.get('access_control', {}).get('authorized_roles', []))
        
        # Format roles for SQL
        roles_sql = ", ".join([f"'{role.upper()}'" for role in authorized_roles])
        
        applies_to = policy_def.get('applies_to', '')
        description = policy_def.get('description', '')
        behavior = policy_def.get('behavior', '')
        data_type = policy_def.get('data_type', 'STRING')
        
        sql_parts.extend([
            f"-- ============================================================================",
            f"-- MASKING POLICY: {policy_name}",
            f"-- ============================================================================",
            f"-- Applies to: {applies_to}",
            f"-- Description: {description}",
            f"-- ============================================================================",
            "",
            f"CREATE OR REPLACE MASKING POLICY {policy_name.lower()}",
            f"AS (val {data_type})",
            f"RETURNS {data_type} ->",
            f"    CASE",
            f"        -- Authorized roles can see full value",
            f"        WHEN CURRENT_ROLE() IN ({roles_sql}) THEN val",
            f"        -- All other roles see masked value",
            f"        ELSE CONCAT(LEFT(val, 1), '****')",
            f"    END;",
            "",
            f"COMMENT ON MASKING POLICY {policy_name.lower()} IS",
            f"'{description}. Contract: {contract_info['name']} v{contract_info['version']}';",
            ""
        ])
        
        # Apply to table if exists
        if applies_to:
            sql_parts.extend([
                f"-- Apply masking policy to column",
                f"ALTER TABLE IF EXISTS {contract_info['target_database']}.{contract_info['target_schema']}.{contract_info['target_table']}",
                f"    MODIFY COLUMN {applies_to}",
                f"    SET MASKING POLICY {policy_name.lower()};",
                ""
            ])
    
    return "\n".join(sql_parts)


def generate_dmf_sql(contract_info: Dict) -> str:
    """Generate Data Metric Functions SQL from contract quality rules (Template-based)"""
    
    full_table_name = f"{contract_info['target_database']}.{contract_info['target_schema']}.{contract_info['target_table']}"
    
    sql_parts = [
        "-- ============================================================================",
        "-- DATA METRIC FUNCTIONS: Generated from Data Contract",
        "-- ============================================================================",
        f"-- Contract: {contract_info['name']} v{contract_info['version']}",
        f"-- Generated: {datetime.now().isoformat()}",
        "-- Template-based generation from contract quality rules",
        "-- ============================================================================",
        "",
        "USE ROLE ACCOUNTADMIN;",
        f"USE DATABASE {contract_info['target_database']};",
        f"USE SCHEMA {contract_info['target_schema']};",
        "",
        "-- ============================================================================",
        "-- PART 1: SET DMF SCHEDULE",
        "-- ============================================================================",
        "",
        f"ALTER TABLE {full_table_name}",
        "    SET DATA_METRIC_SCHEDULE = 'USING CRON 0,30 * * * * UTC';",
        ""
    ]
    
    # Part 2: NULL_COUNT for required columns
    sql_parts.extend([
        "-- ============================================================================",
        "-- PART 2: COMPLETENESS CHECKS (NULL_COUNT)",
        "-- ============================================================================",
        "-- Columns with required: true in contract must not have nulls",
        ""
    ])
    
    required_columns = [col['name'] for col in contract_info['columns'] if col.get('required')]
    # Also check data_quality.completeness for 100% columns
    completeness = contract_info.get('data_quality', {}).get('completeness', {})
    for col_name, pct in completeness.items():
        if pct == 100 and col_name not in required_columns:
            required_columns.append(col_name)
    
    # Always include primary key
    pk = contract_info.get('primary_key', '')
    if pk and pk not in required_columns:
        required_columns.insert(0, pk)
    
    for col_name in required_columns:
        expectation_name = f"no_null_{col_name}".lower()
        sql_parts.extend([
            f"ALTER TABLE {full_table_name}",
            f"    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT",
            f"    ON ({col_name})",
            f"    EXPECTATION {expectation_name} (VALUE = 0);",
            ""
        ])
    
    # Part 3: DUPLICATE_COUNT for primary key
    if pk:
        sql_parts.extend([
            "-- ============================================================================",
            "-- PART 3: UNIQUENESS CHECK (DUPLICATE_COUNT)",
            "-- ============================================================================",
            f"-- Primary key ({pk}) must be unique per contract",
            "",
            f"ALTER TABLE {full_table_name}",
            f"    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT",
            f"    ON ({pk})",
            f"    EXPECTATION no_duplicate_{pk.lower()} (VALUE = 0);",
            ""
        ])
    
    # Part 4: UNIQUE_COUNT for key dimensions (informational)
    dimension_columns = []
    for col in contract_info['columns']:
        tags = col.get('tags', [])
        col_type = col.get('type', '')
        # Include columns tagged as classification, segment, tier, or string enums
        if any(tag in tags for tag in ['classification', 'segment', 'tier', 'risk_tier', 'geography']):
            dimension_columns.append(col['name'])
        elif 'enum' in str(col.get('constraints', {})):
            dimension_columns.append(col['name'])
    
    if dimension_columns:
        sql_parts.extend([
            "-- ============================================================================",
            "-- PART 4: CARDINALITY TRACKING (UNIQUE_COUNT)",
            "-- ============================================================================",
            "-- Track distinct values for key dimensions (informational)",
            ""
        ])
        for col_name in dimension_columns:
            sql_parts.extend([
                f"ALTER TABLE {full_table_name}",
                f"    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.UNIQUE_COUNT",
                f"    ON ({col_name});",
                ""
            ])
    
    # Part 5: FRESHNESS based on SLA
    # Find timestamp column
    timestamp_cols = [col['name'] for col in contract_info['columns'] 
                      if col.get('type') in ['timestamp', 'timestamp_ntz', 'timestamp_ltz']
                      or 'timestamp' in col.get('tags', [])
                      or 'calculated_at' in col['name'].lower()]
    
    freshness_config = contract_info.get('data_quality', {}).get('freshness', {})
    max_age = freshness_config.get('max_age', '25 hours')
    
    # Convert to seconds (simple parsing)
    if 'hour' in max_age.lower():
        try:
            hours = int(''.join(filter(str.isdigit, max_age)))
            max_seconds = hours * 3600
        except:
            max_seconds = 86400  # Default 24 hours
    else:
        max_seconds = 86400
    
    if timestamp_cols:
        ts_col = timestamp_cols[0]
        sql_parts.extend([
            "-- ============================================================================",
            "-- PART 5: FRESHNESS SLA",
            "-- ============================================================================",
            f"-- Contract SLA: {max_age} (max {max_seconds} seconds)",
            "",
            f"ALTER TABLE {full_table_name}",
            f"    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS",
            f"    ON ({ts_col})",
            f"    EXPECTATION freshness_sla (VALUE <= {max_seconds});",
            ""
        ])
    
    # Part 6: ROW_COUNT threshold
    monitoring = contract_info.get('data_quality', {}).get('monitoring', {})
    row_threshold = 500  # Default
    
    # Try to extract from monitoring.metrics
    metrics = monitoring.get('metrics', [])
    for metric in metrics:
        if isinstance(metric, dict) and metric.get('name') == 'row_count':
            threshold_str = metric.get('threshold', '')
            try:
                row_threshold = int(''.join(filter(str.isdigit, threshold_str)))
            except:
                pass
    
    sql_parts.extend([
        "-- ============================================================================",
        "-- PART 6: ROW COUNT THRESHOLD",
        "-- ============================================================================",
        f"-- Minimum expected rows: {row_threshold}",
        "",
        f"ALTER TABLE {full_table_name}",
        f"    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT",
        f"    ON ()",
        f"    EXPECTATION min_row_count (VALUE >= {row_threshold});",
        ""
    ])
    
    # Part 7: Verification queries
    sql_parts.extend([
        "-- ============================================================================",
        "-- PART 7: VERIFY DMF CONFIGURATION",
        "-- ============================================================================",
        "",
        "-- View all DMFs applied",
        "SELECT",
        "    metric_name,",
        "    ref_arguments AS columns,",
        "    schedule,",
        "    schedule_status",
        "FROM TABLE(",
        "    INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(",
        f"        REF_ENTITY_NAME => '{full_table_name}',",
        "        REF_ENTITY_DOMAIN => 'TABLE'",
        "    )",
        ")",
        "ORDER BY metric_name;",
        "",
        "-- Run initial quality check",
        "SELECT * FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS(",
        f"    REF_ENTITY_NAME => '{full_table_name}'));",
        "",
        "-- ============================================================================",
        "-- SETUP COMPLETE",
        "-- ============================================================================",
    ])
    
    return "\n".join(sql_parts)


def call_cortex(session: Session, prompt: str, model: str = "claude-3-5-sonnet") -> str:
    """Call Cortex LLM to generate code"""
    try:
        escaped_prompt = prompt.replace("'", "''")
        sql = f"SELECT SNOWFLAKE.CORTEX.COMPLETE('{model}', '{escaped_prompt}') as response"
        result = session.sql(sql).collect()
        
        if result and result[0]['RESPONSE']:
            return result[0]['RESPONSE']
        return "-- Error: No response from Cortex"
    except Exception as e:
        return f"-- Error generating code: {str(e)}"


# ============================================================================
# MAIN APPLICATION
# ============================================================================

# Initialize session
initialize_session()

# Header
st.markdown('<div class="main-header">🛠️ DBT Code Generator from Data Contract</div>', unsafe_allow_html=True)

if st.session_state.session is None:
    st.error("❌ Unable to connect to Snowflake. Please check your environment.")
    st.stop()

# Sidebar - Session Info
with st.sidebar:
    st.header("❄️ Connection")
    if hasattr(st.session_state, 'session_info'):
        info = st.session_state.session_info
        st.write(f"**User:** {info['user']}")
        st.write(f"**Database:** {info['database']}")
        st.write(f"**Warehouse:** {info['warehouse']}")
    
    st.divider()
    
    st.header("🧠 Generation Settings")
    use_cortex = st.checkbox("Use Cortex LLM", value=True, 
                             help="Use Cortex AI to generate transformation code from contract derivations.")
    
    if use_cortex:
        cortex_model = st.selectbox(
            "Cortex Model",
            ["claude-3-5-sonnet", "llama3.1-70b", "mixtral-8x7b"],
            help="Select the LLM model for code generation"
        )
    else:
        cortex_model = None
        st.warning("⚠️ Without Cortex, only basic templates will be generated.")
    
    st.divider()
    
    st.header("📤 Outputs Generated")
    st.markdown("""
    The generator produces:
    - `model.sql` - dbt transformation (🧠 AI)
    - `schema.yml` - documentation & tests (📋 Template)
    - `masking_policies.sql` - PII protection (📋 Template)
    - `dmf_setup.sql` - Data quality rules (📋 Template)
    """)
    
    st.divider()
    
    st.header("ℹ️ How It Works")
    st.markdown("""
    1. **Input**: Data Contract YAML
    2. **Parse**: Extract derivations & rules
    3. **Generate**: Cortex creates SQL from English definitions
    4. **Output**: Download files for dbt project
    """)

# Main content
st.markdown('<div class="section-header">📋 Step 1: Provide Data Contract</div>', unsafe_allow_html=True)

# Contract input options
input_method = st.radio(
    "How would you like to provide the contract?",
    ["📝 Paste YAML", "📁 Upload File", "☁️ Load from Stage"],
    horizontal=True
)

contract_yaml = None

if input_method == "📝 Paste YAML":
    contract_yaml = st.text_area(
        "Paste your Data Contract YAML here:",
        height=300,
        placeholder="apiVersion: v1\nkind: DataContract\nmetadata:\n  name: my-data-product\n..."
    )
    
elif input_method == "📁 Upload File":
    uploaded_file = st.file_uploader("Upload YAML file", type=['yaml', 'yml'])
    if uploaded_file:
        contract_yaml = uploaded_file.read().decode('utf-8')
        st.success(f"✅ Loaded: {uploaded_file.name}")

elif input_method == "☁️ Load from Stage":
    col1, col2 = st.columns(2)
    with col1:
        stage_path = st.text_input(
            "Stage Path",
            placeholder="DATABASE.SCHEMA.STAGE_NAME",
            help="e.g., RETAIL_BANKING_DB.GOVERNANCE.DATA_CONTRACTS"
        )
    with col2:
        file_name = st.text_input(
            "File Name",
            placeholder="contract.yaml"
        )
    
    if stage_path and file_name and st.button("Load from Stage"):
        try:
            session = st.session_state.session
            sql = f"""
                SELECT $1 as content 
                FROM @{stage_path}/{file_name}
                (FILE_FORMAT => (TYPE = 'CSV' FIELD_DELIMITER = NONE))
            """
            result = session.sql(sql).collect()
            if result:
                contract_yaml = '\n'.join([row['CONTENT'] for row in result])
                st.success(f"✅ Loaded from stage: {file_name}")
        except Exception as e:
            st.error(f"Error loading from stage: {str(e)}")

# Parse and display contract info
if contract_yaml:
    contract = parse_contract(contract_yaml)
    
    if contract:
        contract_info = extract_contract_info(contract)
        
        st.markdown('<div class="section-header">📊 Step 2: Review Contract Information</div>', unsafe_allow_html=True)
        
        # Display contract summary
        col1, col2 = st.columns(2)
        
        with col1:
            st.markdown('<div class="contract-card">', unsafe_allow_html=True)
            st.markdown("**📌 Contract Details**")
            st.write(f"**Name:** {contract_info['name']}")
            st.write(f"**Version:** {contract_info['version']}")
            st.write(f"**Title:** {contract_info['title']}")
            st.write(f"**Owner:** {contract_info['owner'].get('name', 'N/A')}")
            st.markdown('</div>', unsafe_allow_html=True)
        
        with col2:
            st.markdown('<div class="contract-card">', unsafe_allow_html=True)
            st.markdown("**🎯 Target Configuration**")
            st.write(f"**Database:** {contract_info['target_database']}")
            st.write(f"**Schema:** {contract_info['target_schema']}")
            st.write(f"**Table:** {contract_info['target_table']}")
            st.write(f"**Materialization:** {contract_info['materialization']}")
            st.markdown('</div>', unsafe_allow_html=True)
        
        # Source tables
        with st.expander("📥 Source Tables", expanded=True):
            for table in contract_info['source_tables']:
                if isinstance(table, dict):
                    st.write(f"• **{table.get('name')}** (`{table.get('location')}`)")
                    if table.get('filter'):
                        st.write(f"  Filter: _{table.get('filter')}_")
                else:
                    st.write(f"• `{table}`")
        
        # Columns with derivations
        with st.expander(f"📋 Output Columns ({len(contract_info['columns'])} columns)", expanded=False):
            for col in contract_info['columns']:
                pii_badge = "🔒 PII" if col['pii'] else ""
                derivation = col.get('derivation', '')
                st.write(f"• **{col['name']}** ({col['type']}) {pii_badge}")
                st.write(f"  _{col['description']}_")
                if derivation:
                    st.info(f"  📐 Derivation: {derivation[:200]}...")
        
        # Masking policies
        if contract_info.get('masking_policies'):
            with st.expander("🔐 Masking Policies", expanded=False):
                for name, policy in contract_info['masking_policies'].items():
                    st.write(f"• **{name}**")
                    st.write(f"  _{policy.get('description', '')}_")
        
        # Business rules
        if contract_info.get('business_rules'):
            with st.expander("📏 Business Rules", expanded=False):
                for rule in contract_info['business_rules']:
                    if isinstance(rule, dict):
                        st.write(f"• **{rule.get('rule_id', 'N/A')}**: {rule.get('name', '')}")
                        st.write(f"  _{rule.get('description', '')}_")
        
        # Generate button
        st.markdown('<div class="section-header">🚀 Step 3: Generate dbt Code</div>', unsafe_allow_html=True)
        
        if st.button("Generate All Outputs", type="primary", use_container_width=True):
            with st.spinner("Generating code from contract..."):
                
                # Generate dbt model SQL
                if use_cortex:
                    prompt = generate_dbt_model_prompt(contract_info)
                    dbt_model_code = call_cortex(
                        st.session_state.session, 
                        prompt, 
                        cortex_model
                    )
                else:
                    dbt_model_code = f"-- Cortex disabled. Enable Cortex LLM for full generation.\n-- Contract: {contract_info['name']}"
                
                # Generate schema.yml
                schema_yml = generate_schema_yml(contract_info)
                
                # Generate masking policies
                masking_sql = generate_masking_policies_sql(contract_info)
                
                # Generate DMF setup (template-based)
                dmf_sql = generate_dmf_sql(contract_info)
                
                # Store in session state
                st.session_state.generated_model = dbt_model_code
                st.session_state.generated_schema = schema_yml
                st.session_state.generated_masking = masking_sql
                st.session_state.generated_dmf = dmf_sql
                st.session_state.model_name = contract_info['target_table'].lower()
        
        # Display generated code
        if hasattr(st.session_state, 'generated_model'):
            st.markdown('<div class="success-box">', unsafe_allow_html=True)
            st.markdown("✅ **All outputs generated successfully!**")
            st.markdown('</div>', unsafe_allow_html=True)
            
            tab1, tab2, tab3, tab4 = st.tabs(["📄 dbt Model SQL", "📋 schema.yml", "🔐 masking_policies.sql", "📊 dmf_setup.sql"])
            
            with tab1:
                st.caption("🧠 AI-Generated via Cortex LLM")
                st.code(st.session_state.generated_model, language='sql')
                st.download_button(
                    "📥 Download Model SQL",
                    st.session_state.generated_model,
                    file_name=f"{st.session_state.model_name}.sql",
                    mime="text/plain"
                )
            
            with tab2:
                st.caption("📋 Template-based from contract metadata")
                st.code(st.session_state.generated_schema, language='yaml')
                st.download_button(
                    "📥 Download schema.yml",
                    st.session_state.generated_schema,
                    file_name="schema.yml",
                    mime="text/plain"
                )
            
            with tab3:
                st.caption("📋 Template-based from contract policies")
                st.code(st.session_state.generated_masking, language='sql')
                st.download_button(
                    "📥 Download masking_policies.sql",
                    st.session_state.generated_masking,
                    file_name="masking_policies.sql",
                    mime="text/plain"
                )
            
            with tab4:
                st.caption("📋 Template-based from contract quality rules")
                st.code(st.session_state.generated_dmf, language='sql')
                st.download_button(
                    "📥 Download dmf_setup.sql",
                    st.session_state.generated_dmf,
                    file_name="dmf_setup.sql",
                    mime="text/plain"
                )
            
            # Usage instructions
            st.markdown('<div class="section-header">📖 Next Steps</div>', unsafe_allow_html=True)
            
            st.markdown('<div class="output-card">', unsafe_allow_html=True)
            st.markdown(f"""
**Deploy to your dbt project:**

1. **Model SQL** → `models/data_products/{st.session_state.model_name}.sql`
2. **Schema** → `models/data_products/schema.yml`
3. **Masking** → Run `masking_policies.sql` in Snowflake
4. **DMF Setup** → Run `dmf_setup.sql` in Snowflake (for quality monitoring)

**Run dbt:**
```bash
dbt run --select {st.session_state.model_name}
dbt test --select {st.session_state.model_name}
```

**Verify quality:**
```sql
SELECT * FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS(
    REF_ENTITY_NAME => '{contract_info['target_database']}.{contract_info['target_schema']}.{contract_info['target_table']}'));
```
            """)
            st.markdown('</div>', unsafe_allow_html=True)

else:
    st.info("👆 Please provide a data contract to get started.")
    
    # Show example
    with st.expander("📚 Example Contract Structure"):
        st.code("""
apiVersion: v1
kind: DataContract
metadata:
  name: retail-customer-churn-risk
  version: "1.0.0"
spec:
  info:
    title: "Retail Customer Churn Risk"
    description: "Churn risk scores for retail customers"
  source:
    upstream_tables:
      - name: "CUSTOMERS"
        location: "DB.RAW.CUSTOMERS"
        key_columns: ["customer_id", "name"]
        filter: "status = 'ACTIVE'"
  destination:
    database: "ANALYTICS_DB"
    schema: "DATA_PRODUCTS"
    table: "CUSTOMER_CHURN_RISK"
  schema:
    grain: "One row per customer"
    primary_key: "customer_id"
    properties:
      customer_id:
        type: "string"
        description: "Unique customer identifier"
        source: "CUSTOMERS.customer_id"
      churn_risk_score:
        type: "integer"
        description: "Risk score 0-100"
        derivation: |
          Calculate based on:
          - Balance decline: +20 points
          - Low engagement: +15 points
          Cap at 100
  masking_policies:
    NAME_MASK:
      description: "Mask name for unauthorized users"
      applies_to: "customer_name"
      data_type: "STRING"
      behavior: "Show first initial + asterisks for unauthorized roles"
      authorized_roles:
        - "analyst"
        - "manager"
        """, language='yaml')

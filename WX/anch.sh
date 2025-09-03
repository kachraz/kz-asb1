#!/bin/bash

# =============================================
# CONFIGURATION - SET TO FALSE TO DISABLE FUNCTIONS
# =============================================

ENABLE_ANCHOR_CLEAN=true
ENABLE_ANCHOR_BUILD=true
ENABLE_ANCHOR_DEPLOY=true
ENABLE_ANCHOR_TEST=true

# =============================================
# WALLET CONFIGURATION
# =============================================

WALLET_DIR="pee"  # Default Solana wallet directory
WALLET_FILE="wallet_1.json"              # Default wallet file name

# =============================================
# NETWORK CONFIGURATION - SET TO DEVNET
# =============================================

DEFAULT_CLUSTER="devnet"
RPC_URL="https://api.devnet.solana.com"

# =============================================
# COLOR DEFINITIONS
# =============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
BG_BLUE='\033[44m'
NC_BG='\033[49m'

# =============================================
# UTILITY FUNCTIONS
# =============================================

print_header() {
    echo -e "${BG_BLUE}${WHITE}=============================================${NC}${NC_BG}"
    echo -e "${BG_BLUE}${WHITE}           ANCHOR DEVNET DEPLOY MANAGER       ${NC}${NC_BG}"
    echo -e "${BG_BLUE}${WHITE}=============================================${NC}${NC_BG}"
    echo
}

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

get_balance() {
    solana balance --url $RPC_URL 2>/dev/null | awk '{print $1}' || echo "0"
}

show_balance() {
    local balance=$(get_balance)
    echo -e "${CYAN}Current balance: ${GREEN}$balance SOL${NC}"
    echo "$balance"
}

request_airdrop() {
    local amount=${1:-2}
    echo -e "${CYAN}Requesting airdrop of $amount SOL...${NC}"
    solana airdrop "$amount" --url $RPC_URL
    
    if [ $? -eq 0 ]; then
        print_status "Airdrop successful"
        show_balance
    else
        print_error "Airdrop failed"
        return 1
    fi
}

check_anchor_installed() {
    if ! command -v anchor &> /dev/null; then
        print_error "Anchor CLI is not installed. Please install it first." 
        print_info "Installation instructions: https://www.anchor-lang.com/docs/installation"
        print_info "Quick install: cargo install --git https://github.com/coral-xyz/anchor avm --force && avm install latest && avm use latest"
        exit 1
    fi
}

check_solana_installed() {
    if ! command -v solana &> /dev/null; then
        print_error "Solana CLI is not installed. Please install it first." 
        print_info "Installation instructions: https://solana.com/docs/intro/installation"
        print_info "Quick install: sh -c \"\$(curl -sSfL https://release.anza.xyz/stable/install)\""
        exit 1
    fi
}

check_node_installed() {
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install it first." 
        print_info "Installation instructions: https://nodejs.org/"
        return 1
    fi
    return 0
}

check_yarn_installed() {
    if ! command -v yarn &> /dev/null; then
        print_error "Yarn is not installed. Please install it first." 
        print_info "Installation instructions: https://yarnpkg.com/getting-started/install"
        return 1
    fi
    return 0
}

check_wallet() {
    local wallet_path="$WALLET_DIR/$WALLET_FILE"
    
    if [ ! -f "$wallet_path" ]; then
        print_error "Wallet not found: $wallet_path"
        print_info "Available wallets in $WALLET_DIR:"
        ls -la "$WALLET_DIR"/*.json 2>/dev/null || echo "No wallet files found"
        return 1
    fi
    
    # Set the wallet
    solana config set --keypair "$wallet_path"
    solana config set --url $RPC_URL
    
    local pubkey=$(solana-keygen pubkey "$wallet_path")
    print_status "Using wallet: ${GREEN}$pubkey${NC}"
    print_status "Wallet file: ${BLUE}$wallet_path${NC}"
    
    return 0
}

ensure_min_balance() {
    local min_balance=${1:-1.5}
    local balance=$(get_balance)
    
    # Simple numeric comparison without bc
    if [ $(echo "$balance < $min_balance" | awk '{print ($1 < $3)}') -eq 1 ]; then
        print_warning "Low balance: $balance SOL (minimum recommended: $min_balance SOL)"
        echo -e -n "${CYAN}Request airdrop? (y/N): ${NC}"
        read confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            request_airdrop 2
        fi
    else
        print_info "Balance sufficient: ${GREEN}$balance SOL${NC}"
    fi
}

# Function to extract program ID from source files
get_program_id() {
    local program_id=""
    
    # Try to get program ID from Rust source files
    if [ -d "programs" ]; then
        program_id=$(grep -E '^declare_id!\("([^"]+)"\)' programs/*/src/lib.rs 2>/dev/null | head -1 | cut -d'"' -f2)
    fi
    
    # If not found in source, try to get from Anchor.toml
    if [ -z "$program_id" ] && [ -f "Anchor.toml" ]; then
        program_id=$(grep -E '^\[programs\.' Anchor.toml 2>/dev/null | head -1 | cut -d'.' -f2 | cut -d']' -f1)
        if [ -n "$program_id" ]; then
            # Get the actual program ID value
            program_id=$(grep -A1 "\[programs\.$program_id\]" Anchor.toml 2>/dev/null | grep -E '^\s*id\s*=' | cut -d'=' -f2 | tr -d ' "')
        fi
    fi
    
    # If still not found, try to get from target/idl
    if [ -z "$program_id" ] && [ -d "target/idl" ]; then
        local idl_file=$(ls target/idl/*.json 2>/dev/null | head -1)
        if [ -n "$idl_file" ] && [ -f "$idl_file" ]; then
            program_id=$(jq -r '.metadata.address' "$idl_file" 2>/dev/null)
        fi
    fi
    
    echo "$program_id"
}

# Function to display program ID with formatting
show_program_id() {
    local program_id=$(get_program_id)
    if [ -n "$program_id" ]; then
        echo -e "${MAGENTA}Program ID: ${GREEN}$program_id${NC}"
        echo -e "${MAGENTA}Explorer: ${BLUE}https://explorer.solana.com/address/$program_id?cluster=devnet${NC}"
    else
        echo -e "${YELLOW}Program ID not found${NC}"
    fi
    echo
}

# Function to update program ID in Anchor.toml and lib.rs
update_program_id() {
    local new_program_id="$1"
    local program_name="$2"
    
    if [ -z "$new_program_id" ]; then
        print_error "No program ID provided for update"
        return 1
    fi
    
    # Update Anchor.toml
    if [ -f "Anchor.toml" ]; then
        if [ -n "$program_name" ]; then
            # Update specific program
            sed -i.bak "s/^\[programs\.$program_name\]$/\[programs\.$program_name\]\nid = \"$new_program_id\"/" Anchor.toml
        else
            # Update first program found
            sed -i.bak "0,/^\[programs\.[^]]*\]$/{s/^\[programs\.[^]]*\]$/&\nid = \"$new_program_id\"/}" Anchor.toml
        fi
        print_status "Updated Anchor.toml with program ID: $new_program_id"
    fi
    
    # Update lib.rs files
    if [ -d "programs" ]; then
        for lib_file in programs/*/src/lib.rs; do
            if [ -f "$lib_file" ]; then
                sed -i.bak "s/declare_id!(\"[^\"]*\")/declare_id!(\"$new_program_id\")/" "$lib_file"
                print_status "Updated $lib_file with program ID: $new_program_id"
            fi
        done
    fi
    
    # Clean up backup files
    rm -f Anchor.toml.bak programs/*/src/lib.rs.bak 2>/dev/null
}

# Function to generate a new program ID
generate_program_id() {
    local program_name="$1"
    local keypair_file="target/deploy/${program_name}-keypair.json"
    
    # Generate keypair if it doesn't exist
    if [ ! -f "$keypair_file" ]; then
        solana-keygen new --outfile "$keypair_file" --no-passphrase --force
        if [ $? -ne 0 ]; then
            print_error "Failed to generate keypair for $program_name"
            return 1
        fi
    fi
    
    # Get the public key from the keypair
    local pubkey=$(solana-keygen pubkey "$keypair_file" 2>/dev/null)
    if [ -n "$pubkey" ]; then
        echo "$pubkey"
        return 0
    else
        print_error "Failed to get public key from keypair file"
        return 1
    fi
}

# Function to setup program ID before operations
setup_program_id() {
    echo -e "${CYAN}Setting up program ID...${NC}"
    
    # Check if we already have a program ID
    local current_program_id=$(get_program_id)
    if [ -n "$current_program_id" ]; then
        echo -e "${GREEN}Current program ID: $current_program_id${NC}"
        echo -e -n "${CYAN}Keep current program ID? (Y/n): ${NC}"
        read keep_current
        if [[ "$keep_current" =~ ^[Nn]$ ]]; then
            # User wants to generate new program ID
            current_program_id=""
        fi
    fi
    
    # If no program ID or user wants new one, generate it
    if [ -z "$current_program_id" ]; then
        # Get program name (first program directory found)
        local program_name=$(ls programs/ 2>/dev/null | head -1)
        if [ -z "$program_name" ]; then
            print_error "No program directories found in programs/"
            return 1
        fi
        
        print_info "Generating new program ID for $program_name"
        local new_program_id=$(generate_program_id "$program_name")
        if [ $? -eq 0 ]; then
            update_program_id "$new_program_id" "$program_name"
            print_status "Program ID setup complete: $new_program_id"
        else
            print_error "Failed to generate program ID"
            return 1
        fi
    fi
    
    return 0
}

# Function to install yarn dependencies
yarn_install() {
    echo -e "${CYAN}Installing yarn dependencies...${NC}"
    
    if ! check_node_installed; then
        print_warning "Node.js not installed, skipping yarn install"
        return 1
    fi
    
    if ! check_yarn_installed; then
        print_warning "Yarn not installed, skipping yarn install"
        return 1
    fi
    
    if [ -f "package.json" ]; then
        print_info "Running yarn install"
        yarn install
        
        if [ $? -eq 0 ]; then
            print_status "Yarn dependencies installed successfully"
        else
            print_error "Yarn install failed"
            return 1
        fi
    else
        print_warning "No package.json found, skipping yarn install"
    fi
    
    return 0
}

# =============================================
# ANCHOR FUNCTIONS
# =============================================

anchor_clean() {
    if [ "$ENABLE_ANCHOR_CLEAN" = false ]; then
        print_warning "Anchor clean is disabled"
        return
    fi
    
    echo -e "${CYAN}Cleaning Anchor project...${NC}"
    
    # Show program ID before cleaning
    echo -e "${MAGENTA}Current Program ID:${NC}"
    show_program_id
    
    # Show balance before
    local start_balance=$(show_balance)
    
    # Clean target directory
    if [ -d "target" ]; then
        print_info "Removing target directory"
        rm -rf target/
        print_status "Target directory removed"
    fi
    
    # Clean node_modules if exists
    if [ -d "node_modules" ]; then
        print_info "Removing node_modules directory"
        rm -rf node_modules/
        print_status "Node modules removed"
    fi
    
    # Clean any other build artifacts
    print_info "Cleaning cargo build artifacts"
    cargo clean
    
    if [ $? -eq 0 ]; then
        print_status "Project cleaned successfully"
    else
        print_error "Failed to clean project"
        return 1
    fi
    
    # Show balance after
    local end_balance=$(show_balance)
    echo -e "${CYAN}Balance change: ${GREEN}$start_balance${NC} → ${GREEN}$end_balance${NC} SOL${NC}"
}

anchor_build() {
    if [ "$ENABLE_ANCHOR_BUILD" = false ]; then
        print_warning "Anchor build is disabled"
        return
    fi
    
    echo -e "${CYAN}Building Anchor project...${NC}"
    
    # Setup program ID first
    if ! setup_program_id; then
        print_error "Failed to setup program ID, cannot build"
        return 1
    fi
    
    # Show balance before
    local start_balance=$(show_balance)
    
    # Build the project
    print_info "Running anchor build"
    anchor build
    
    if [ $? -eq 0 ]; then
        print_status "Project built successfully"
        
        # Show program ID after build
        echo -e "${MAGENTA}Generated Program ID:${NC}"
        show_program_id
        
        # Also try to get program ID from keypair files
        local keypair_files=$(ls target/deploy/*-keypair.json 2>/dev/null)
        if [ -n "$keypair_files" ]; then
            for keypair in $keypair_files; do
                local program_name=$(basename "$keypair" | sed 's/-keypair.json//')
                local program_pubkey=$(solana-keygen pubkey "$keypair" 2>/dev/null)
                if [ -n "$program_pubkey" ]; then
                    echo -e "${MAGENTA}Program '$program_name' keypair: ${GREEN}$program_pubkey${NC}"
                fi
            done
        fi
    else
        print_error "Build failed"
        return 1
    fi
    
    # Show balance after
    local end_balance=$(show_balance)
    echo -e "${CYAN}Balance change: ${GREEN}$start_balance${NC} → ${GREEN}$end_balance${NC} SOL${NC}"
}

anchor_deploy() {
    if [ "$ENABLE_ANCHOR_DEPLOY" = false ]; then
        print_warning "Anchor deploy is disabled"
        return
    fi
    
    echo -e "${CYAN}Deploying Anchor project to DevNet...${NC}"
    
    # Setup program ID first
    if ! setup_program_id; then
        print_error "Failed to setup program ID, cannot deploy"
        return 1
    fi
    
    # Show program ID before deployment
    echo -e "${MAGENTA}Program to be deployed:${NC}"
    show_program_id
    
    # Ensure minimum balance
    ensure_min_balance 1.5
    
    # Show balance before
    local start_balance=$(show_balance)
    
    # Deploy the project
    print_info "Running anchor deploy --provider.cluster devnet" 
    anchor deploy --provider.cluster devnet
    
    if [ $? -eq 0 ]; then
        print_status "Project deployed successfully to DevNet!"
        
        # Show program ID after deployment
        echo -e "${MAGENTA}Deployed Program ID:${NC}"
        show_program_id
        
        # Verify on-chain deployment
        local program_id=$(get_program_id)
        if [ -n "$program_id" ]; then
            print_info "Verifying on-chain deployment..."
            solana program show "$program_id" --url $RPC_URL
            
            if [ $? -eq 0 ]; then
                print_status "Program verified on-chain!"
            else
                print_warning "Program deployed but not found on-chain yet (may need to wait for confirmation)"
            fi
        fi
    else
        print_error "Deployment failed"
        
        # Check for common deployment issues 
        local deploy_output=$(anchor deploy --provider.cluster devnet 2>&1)
        
        if echo "$deploy_output" | grep -q "buffer"; then
            print_info "Buffer account issue detected. You may need to close hanging buffer accounts:"
            print_info "Run: solana program show --buffers --url $RPC_URL"
            print_info "Then: solana program close <BUFFER_ADDRESS> --url $RPC_URL" 
        fi
        
        if echo "$deploy_output" | grep -q "insufficient funds"; then
            print_info "Insufficient funds. Request more SOL with: solana airdrop 2 --url $RPC_URL" 
        fi
        
        return 1
    fi
    
    # Show balance after
    local end_balance=$(show_balance)
    local balance_change=$(echo "$start_balance - $end_balance" | bc -l 2>/dev/null || echo "$start_balance - $end_balance" | awk '{print $1 - $3}')
    echo -e "${CYAN}Balance change: ${GREEN}$start_balance${NC} → ${GREEN}$end_balance${NC} SOL (Cost: ${RED}$balance_change${NC} SOL)${NC}"
}

anchor_test() {
    if [ "$ENABLE_ANCHOR_TEST" = false ]; then
        print_warning "Anchor test is disabled"
        return
    fi
    
    echo -e "${CYAN}Testing Anchor project on DevNet...${NC}"
    
    # Install yarn dependencies first (required for tests)
    yarn_install
    
    # Show program ID being tested
    echo -e "${MAGENTA}Testing Program ID:${NC}"
    show_program_id
    
    # Show balance before
    local start_balance=$(show_balance)
    
    # Run tests
    print_info "Running anchor test --provider.cluster devnet"
    anchor test --provider.cluster devnet
    
    if [ $? -eq 0 ]; then
        print_status "Tests passed successfully on DevNet"
    else
        print_error "Tests failed on DevNet"
        return 1
    fi
    
    # Show balance after
    local end_balance=$(show_balance)
    local balance_change=$(echo "$start_balance - $end_balance" | bc -l 2>/dev/null || echo "$start_balance - $end_balance" | awk '{print $1 - $3}')
    echo -e "${CYAN}Balance change: ${GREEN}$start_balance${NC} → ${GREEN}$end_balance${NC} SOL (Cost: ${RED}$balance_change${NC} SOL)${NC}"
}

show_program_details() {
    # Show detailed program information
    echo -e "${MAGENTA}Program Details:${NC}"
    show_program_id
    
    # Show keypair files if they exist
    local keypair_files=$(ls target/deploy/*-keypair.json 2>/dev/null)
    if [ -n "$keypair_files" ]; then
        echo -e "${MAGENTA}Available program keypairs:${NC}"
        for keypair in $keypair_files; do
            local program_name=$(basename "$keypair" | sed 's/-keypair.json//')
            local program_pubkey=$(solana-keygen pubkey "$keypair" 2>/dev/null)
            if [ -n "$program_pubkey" ]; then
                echo -e "  ${GREEN}$program_name${NC}: ${BLUE}$program_pubkey${NC}"
                echo -e "    Keypair: ${YELLOW}$keypair${NC}"
            fi
        done
    fi
    
    # Try to verify on-chain status
    local program_id=$(get_program_id)
    if [ -n "$program_id" ]; then
        echo
        echo -e "${MAGENTA}On-chain verification:${NC}"
        solana program show "$program_id" --url $RPC_URL 2>/dev/null
        if [ $? -ne 0 ]; then
            echo -e "${YELLOW}Program not found on-chain${NC}"
        fi
    fi
}

# =============================================
# MAIN MENU
# =============================================

show_menu() {
    echo
    echo -e "${CYAN}Select Anchor operations to run (DevNet):${NC}"
    echo
    
    # Show current program ID in menu
    local current_program_id=$(get_program_id)
    if [ -n "$current_program_id" ]; then
        echo -e "${MAGENTA}Current Program ID: ${GREEN}$current_program_id${NC}"
        echo
    fi
    
    if [ "$ENABLE_ANCHOR_CLEAN" = true ]; then
        echo -e "  ${GREEN}1${NC}) Clean project"
    fi
    
    if [ "$ENABLE_ANCHOR_BUILD" = true ]; then
        echo -e "  ${GREEN}2${NC}) Build project"
    fi
    
    if [ "$ENABLE_ANCHOR_DEPLOY" = true ]; then
        echo -e "  ${GREEN}3${NC}) Deploy to DevNet"
    fi
    
    if [ "$ENABLE_ANCHOR_TEST" = true ]; then
        echo -e "  ${GREEN}4${NC}) Test on DevNet"
    fi
    
    echo -e "  ${GREEN}5${NC}) Run all operations"
    echo -e "  ${GREEN}6${NC}) Request airdrop"
    echo -e "  ${GREEN}7${NC}) Check balance"
    echo -e "  ${GREEN}8${NC}) Change wallet directory"
    echo -e "  ${GREEN}9${NC}) Show program details"
    echo -e "  ${GREEN}10${NC}) Setup program ID"
    echo -e "  ${GREEN}11${NC}) Install yarn dependencies"
    echo -e "  ${GREEN}0${NC}) Exit"
    echo
    echo -e -n "${CYAN}Your choice (comma-separated for multiple, e.g., 1,2,3): ${NC}"
}

# =============================================
# SCRIPT INITIALIZATION
# =============================================

# Initialize
check_anchor_installed
check_solana_installed

# Clear screen and print header
clear
print_header

# Check and set wallet
if ! check_wallet; then
    echo -e -n "${CYAN}Enter full path to your wallet file: ${NC}"
    read custom_wallet
    if [ -f "$custom_wallet" ]; then
        WALLET_DIR=$(dirname "$custom_wallet")
        WALLET_FILE=$(basename "$custom_wallet")
        check_wallet
    else
        print_error "Wallet file not found: $custom_wallet"
        exit 1
    fi
fi

# Show initial balance
show_balance

# Setup program ID automatically at start
echo
print_info "Setting up program ID automatically..."
if setup_program_id; then
    print_status "Program ID setup complete"
else
    print_warning "Program ID setup failed, you may need to set it up manually"
fi

# Show initial program ID if available
echo
show_program_id

# =============================================
# MAIN EXECUTION
# =============================================

while true; do
    show_menu
    read choices

    # Convert comma-separated choices to array
    IFS=',' read -ra choices_array <<< "$choices"

    # Check if we should exit
    for choice in "${choices_array[@]}"; do
        if [ "$choice" = "0" ]; then
            print_status "Goodbye!"
            exit 0
        fi
    done

    # Run selected operations
    for choice in "${choices_array[@]}"; do
        case $choice in
            1)
                anchor_clean
                ;;
            2)
                anchor_build
                ;;
            3)
                anchor_deploy
                ;;
            4)
                anchor_test
                ;;
            5)
                # Run all operations in sequence
                if [ "$ENABLE_ANCHOR_CLEAN" = true ]; then
                    anchor_clean
                    echo
                fi
                
                if [ "$ENABLE_ANCHOR_BUILD" = true ]; then
                    anchor_build
                    echo
                fi
                
                if [ "$ENABLE_ANCHOR_DEPLOY" = true ]; then
                    anchor_deploy
                    echo
                fi
                
                if [ "$ENABLE_ANCHOR_TEST" = true ]; then
                    anchor_test
                    echo
                fi
                ;;
            6)
                request_airdrop 2
                ;;
            7)
                show_balance
                ;;
            8)
                echo -e -n "${CYAN}Enter new wallet directory: ${NC}"
                read new_dir
                if [ -d "$new_dir" ]; then
                    WALLET_DIR="$new_dir"
                    echo -e -n "${CYAN}Enter wallet file name: ${NC}"
                    read new_file
                    if [ -f "$WALLET_DIR/$new_file" ]; then
                        WALLET_FILE="$new_file"
                        check_wallet
                    else
                        print_error "Wallet file not found: $WALLET_DIR/$new_file"
                    fi
                else
                    print_error "Directory not found: $new_dir"
                fi
                ;;
            9)
                show_program_details
                ;;
            10)
                setup_program_id
                ;;
            11)
                yarn_install
                ;;
            *)
                print_error "Invalid option: $choice"
                ;;
        esac
        
        # Add spacing between operations
        echo
    done

    print_info "Operations completed"
    print_info "Final balance: $(get_balance) SOL"
    print_info "Explorer: https://explorer.solana.com/?cluster=devnet"

    # Show final status
    echo -e "${GREEN}=============================================${NC}"
    echo -e "${GREEN}DevNet deployment script execution finished${NC}"
    echo -e "${GREEN}=============================================${NC}"
    
    echo
    echo -e -n "${CYAN}Run another operation? (y/N): ${NC}"
    read continue_choice
    if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
        break
    fi
    echo
done

print_status "Goodbye!"
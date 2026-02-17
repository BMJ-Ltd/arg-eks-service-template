#!/bin/bash
# verify-configuration.sh
# Validates EKS service template configuration
# Version: 1.0.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
ERRORS=0
WARNINGS=0
CHECKS=0

# Functions
error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
    ((ERRORS++))
}

warning() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}"
    ((WARNINGS++))
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((CHECKS++))
}

info() {
    echo -e "ℹ $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo "================================================="
echo "EKS Service Template Configuration Validator"
echo "Version 1.0.0"
echo "================================================="
echo ""

# Check prerequisites
info "Checking prerequisites..."

if ! command_exists kustomize; then
    error "kustomize not found. Install: brew install kustomize"
else
    success "kustomize found"
fi

if ! command_exists kubectl; then
    warning "kubectl not found. Some validation checks will be skipped."
else
    success "kubectl found"
fi

if ! command_exists kubeseal; then
    warning "kubeseal not found. Sealed secrets validation will be limited."
else
    success "kubeseal found"
fi

echo ""

# Find all service directories (directories with base/ subdirectory)
info "Scanning for service directories..."
SERVICES=$(find . -type d -name "base" | sed 's|/base||' | sed 's|./||')

if [ -z "$SERVICES" ]; then
    error "No service directories found (directories with base/ subdirectory)"
    exit 1
fi

for SERVICE in $SERVICES; do
    echo ""
    echo "================================================="
    echo "Validating: $SERVICE"
    echo "================================================="
    
    # Check base directory structure
    if [ ! -d "$SERVICE/base" ]; then
        error "$SERVICE/base directory not found"
        continue
    fi
    
    if [ ! -f "$SERVICE/base/kustomization.yaml" ]; then
        error "$SERVICE/base/kustomization.yaml not found"
        continue
    fi
    
    success "Base directory structure exists"
    
    # Check for placeholders in base
    info "Checking for placeholders in base manifests..."
    if grep -r "{{" "$SERVICE/base" >/dev/null 2>&1; then
        PLACEHOLDER_COUNT=$(grep -r "{{" "$SERVICE/base" | wc -l)
        warning "Found $PLACEHOLDER_COUNT placeholders in $SERVICE/base"
        grep -r "{{" "$SERVICE/base" | head -5
        if [ "$PLACEHOLDER_COUNT" -gt 5 ]; then
            echo "  ... and $(($PLACEHOLDER_COUNT - 5)) more"
        fi
    else
        success "No placeholders found in base"
    fi
    
    # Validate kustomize build for base
    info "Validating kustomize build for base..."
    if kustomize build "$SERVICE/base" >/dev/null 2>&1; then
        success "Base kustomize build successful"
    else
        error "Base kustomize build failed"
        kustomize build "$SERVICE/base" 2>&1 | head -10
    fi
    
    # Check overlays
    if [ ! -d "$SERVICE/overlays" ]; then
        warning "No overlays directory found for $SERVICE"
        continue
    fi
    
    # Check each environment overlay
    for ENV in dev stg live; do
        if [ ! -d "$SERVICE/overlays/$ENV" ]; then
            warning "Overlay $SERVICE/overlays/$ENV not found (optional)"
            continue
        fi
        
        echo ""
        info "Validating overlay: $ENV"
        
        # Check kustomization.yaml exists
        if [ ! -f "$SERVICE/overlays/$ENV/kustomization.yaml" ]; then
            error "$SERVICE/overlays/$ENV/kustomization.yaml not found"
            continue
        fi
        
        # Check for placeholders in overlay
        if grep -r "{{" "$SERVICE/overlays/$ENV" >/dev/null 2>&1; then
            PLACEHOLDER_COUNT=$(grep -r "{{" "$SERVICE/overlays/$ENV" | wc -l)
            warning "Found $PLACEHOLDER_COUNT placeholders in $SERVICE/overlays/$ENV"
        else
            success "No placeholders in $ENV overlay"
        fi
        
        # Validate kustomize build
        if kustomize build "$SERVICE/overlays/$ENV" >/dev/null 2>&1; then
            success "Kustomize build successful for $ENV"
            
            # Check for secrets in built manifest
            BUILD_OUTPUT=$(kustomize build "$SERVICE/overlays/$ENV")
            if echo "$BUILD_OUTPUT" | grep -i "kind: Secret" >/dev/null 2>&1; then
                if echo "$BUILD_OUTPUT" | grep -v "SealedSecret" | grep -i "kind: Secret" >/dev/null 2>&1; then
                    error "Plain Kubernetes Secret found in $ENV (should use SealedSecret)"
                fi
            fi
            
            # Check for required labels
            if echo "$BUILD_OUTPUT" | grep -q "team:"; then
                success "Team label found in $ENV"
            else
                warning "Team label not found in $ENV manifest"
            fi
            
            if echo "$BUILD_OUTPUT" | grep -q "costcentre:"; then
                success "Cost centre label found in $ENV"
            else
                warning "Cost centre label not found in $ENV manifest"
            fi
            
            # Check IAM role ARN for environment
            case $ENV in
                dev)
                    EXPECTED_ACCOUNT="109227185188"
                    ;;
                stg)
                    EXPECTED_ACCOUNT="138832992068"
                    ;;
                live)
                    EXPECTED_ACCOUNT="721468132385"
                    ;;
            esac
            
            if echo "$BUILD_OUTPUT" | grep -q "$EXPECTED_ACCOUNT"; then
                success "Correct AWS account ID for $ENV ($EXPECTED_ACCOUNT)"
            else
                warning "AWS account ID for $ENV might be incorrect (expected $EXPECTED_ACCOUNT)"
            fi
            
        else
            error "Kustomize build failed for $ENV"
            kustomize build "$SERVICE/overlays/$ENV" 2>&1 | head -10
        fi
        
        # Check sealed secrets
        if [ -f "$SERVICE/overlays/$ENV/sealed-secrets.yaml" ]; then
            if grep -q "encryptedData:" "$SERVICE/overlays/$ENV/sealed-secrets.yaml"; then
                if grep "encryptedData: {}" "$SERVICE/overlays/$ENV/sealed-secrets.yaml" >/dev/null 2>&1; then
                    warning "Empty sealed secrets in $ENV (no encrypted data)"
                else
                    success "Sealed secrets configured for $ENV"
                fi
            else
                warning "sealed-secrets.yaml exists but no encryptedData in $ENV"
            fi
        else
            warning "No sealed-secrets.yaml in $ENV (secrets may be needed)"
        fi
        
        # Environment-specific checks
        if [ "$ENV" = "live" ]; then
            # Check for PodDisruptionBudget in live
            if [ -f "$SERVICE/overlays/live/pdb.yaml" ]; then
                success "PodDisruptionBudget configured for production"
            else
                warning "No PodDisruptionBudget found for production (recommended)"
            fi
            
            # Check replica count is > 1
            BUILD_OUTPUT=$(kustomize build "$SERVICE/overlays/$ENV")
            REPLICAS=$(echo "$BUILD_OUTPUT" | grep -A5 "kind: Deployment" | grep "replicas:" | awk '{print $2}')
            if [ -n "$REPLICAS" ] && [ "$REPLICAS" -gt 1 ]; then
                success "Production replicas: $REPLICAS (> 1)"
            else
                warning "Production replicas should be > 1 for high availability"
            fi
        fi
    done
done

# Check for sensitive files that shouldn't be committed
echo ""
echo "================================================="
echo "Security Checks"
echo "================================================="

info "Checking for sensitive files..."

if find . -name "secret*.yaml" -not -name "sealed-secrets.yaml" | grep -v ".git" >/dev/null 2>&1; then
    error "Plain secret files found (should be deleted after sealing):"
    find . -name "secret*.yaml" -not -name "sealed-secrets.yaml" | grep -v ".git"
else
    success "No plain secret files found"
fi

if find . -name "*cert.pem" -o -name "*.key" | grep -v ".git" >/dev/null 2>&1; then
    error "Certificate or key files found (should not be committed):"
    find . -name "*cert.pem" -o -name "*.key" | grep -v ".git"
else
    success "No certificate/key files found"
fi

# Check .gitignore
if [ -f ".gitignore" ]; then
    if grep -q "secret.yaml" .gitignore && grep -q "*.pem" .gitignore; then
        success ".gitignore configured for secrets"
    else
        warning ".gitignore should include secret.yaml and *.pem"
    fi
else
    warning ".gitignore not found (recommended)"
fi

# Summary
echo ""
echo "================================================="
echo "Validation Summary"
echo "================================================="
echo -e "Checks passed: ${GREEN}$CHECKS${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo -e "Errors: ${RED}$ERRORS${NC}"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}❌ Validation FAILED with $ERRORS errors${NC}"
    echo "Please fix errors before committing."
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠  Validation completed with $WARNINGS warnings${NC}"
    echo "Review warnings and fix if necessary."
    exit 0
else
    echo -e "${GREEN}✅ Validation PASSED${NC}"
    echo "Configuration looks good!"
    exit 0
fi

#!/bin/bash

# Script de release con versionado para ssh-mobile (Frontend + Backend)
# Uso: ./release.sh [patch|minor|major] "mensaje del commit"

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Colores adicionales
BLUE='\033[0;34m'

print_success() { echo -e "${BLUE}[SUCCESS]${NC} $1"; }

# Variables
FRONTEND_IMAGE="ssh-mobile-frontend"
BACKEND_IMAGE="ssh-mobile-backend"
FRONTEND_DEPLOYMENT="k8s/frontend-deployment.yaml"
BACKEND_DEPLOYMENT="k8s/backend-deployment.yaml"
VERSION_FILE="VERSION"
REGISTRY_USER="3kn4ls"

# Leer versión actual
if [ ! -f "$VERSION_FILE" ]; then
    echo "1.0.0" > "$VERSION_FILE"
fi

CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '\n')
print_info "Versión actual: v$CURRENT_VERSION"

# Función para incrementar versión
increment_version() {
    local version=$1
    local type=$2

    IFS='.' read -r -a parts <<< "$version"
    local major="${parts[0]}"
    local minor="${parts[1]}"
    local patch="${parts[2]}"

    case "$type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            print_error "Tipo de versión inválido: $type"
            exit 1
            ;;
    esac

    echo "${major}.${minor}.${patch}"
}

# Verificar argumentos
VERSION_TYPE=${1:-patch}
COMMIT_MESSAGE=${2:-"Release"}

if [[ ! "$VERSION_TYPE" =~ ^(patch|minor|major)$ ]]; then
    print_error "Tipo de versión debe ser: patch, minor o major"
    echo ""
    echo "Uso: $0 [patch|minor|major] \"mensaje del commit\""
    exit 1
fi

# Calcular nueva versión
NEW_VERSION=$(increment_version "$CURRENT_VERSION" "$VERSION_TYPE")
print_info "Nueva versión: v$NEW_VERSION"

# Verificar que no haya cambios sin commit
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    print_warning "Tienes cambios sin commit."
    git status --short
    echo ""
    read -p "¿Continuar de todas formas? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Operación cancelada"
        exit 1
    fi
fi

# Mostrar plan
echo ""
print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_info "Plan de release:"
print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1. Actualizar VERSION: $CURRENT_VERSION -> $NEW_VERSION"
echo "  2. Actualizar Frontend Deployment: ghcr.io/${REGISTRY_USER}/${FRONTEND_IMAGE}:v${NEW_VERSION}"
echo "  3. Actualizar Backend Deployment: ghcr.io/${REGISTRY_USER}/${BACKEND_IMAGE}:v${NEW_VERSION}"
echo "  4. Commit y tag v${NEW_VERSION}"
echo "  5. Push a GitHub (main + tags)"
echo "  6. GitHub Actions: build multi-arch (Front + Back)"
echo "  7. ArgoCD sync automático"
echo ""
read -p "¿Proceder? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Operación cancelada"
    exit 1
fi

# 1. Actualizar archivo VERSION
print_info "Paso 1/5: Actualizando VERSION..."
echo "$NEW_VERSION" > "$VERSION_FILE"

# 2. Actualizar frontend deployment
print_info "Paso 2/5: Actualizando Frontend Deployment..."
sed -i "s|image: ghcr.io/${REGISTRY_USER}/${FRONTEND_IMAGE}:v.*|image: ghcr.io/${REGISTRY_USER}/${FRONTEND_IMAGE}:v${NEW_VERSION}|g" "$FRONTEND_DEPLOYMENT"

# 3. Actualizar backend deployment
print_info "Paso 3/5: Actualizando Backend Deployment..."
sed -i "s|image: ghcr.io/${REGISTRY_USER}/${BACKEND_IMAGE}:v.*|image: ghcr.io/${REGISTRY_USER}/${BACKEND_IMAGE}:v${NEW_VERSION}|g" "$BACKEND_DEPLOYMENT"

# Verificar cambios
if grep -q "image: ghcr.io/${REGISTRY_USER}/${FRONTEND_IMAGE}:v${NEW_VERSION}" "$FRONTEND_DEPLOYMENT" && \
   grep -q "image: ghcr.io/${REGISTRY_USER}/${BACKEND_IMAGE}:v${NEW_VERSION}" "$BACKEND_DEPLOYMENT"; then
    print_info "✓ Deployments actualizados a v${NEW_VERSION}"
else
    print_error "Error al actualizar los archivos de deployment"
    exit 1
fi

# 4. Commit y tag
print_info "Paso 4/5: Haciendo commit y tag v${NEW_VERSION}..."

git add "$VERSION_FILE" "$FRONTEND_DEPLOYMENT" "$BACKEND_DEPLOYMENT"
git commit -m "release: v${NEW_VERSION} - ${COMMIT_MESSAGE}

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

git tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION} - ${COMMIT_MESSAGE}"

# 5. Push
print_info "Paso 5/5: Haciendo push a GitHub (main y tags)..."

git push origin main
git push origin --tags

if [ $? -eq 0 ]; then
    echo ""
    print_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_success "✅ Release v${NEW_VERSION} iniciado!"
    print_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    print_info "📦 Frontend: ghcr.io/${REGISTRY_USER}/${FRONTEND_IMAGE}:v${NEW_VERSION}"
    print_info "📦 Backend:  ghcr.io/${REGISTRY_USER}/${BACKEND_IMAGE}:v${NEW_VERSION}"
    print_info "🏷️  Tag: v${NEW_VERSION}"
    echo ""
    print_warning "⏳ GitHub Actions está construyendo las imágenes..."
    print_info "📊 ArgoCD: https://northr3nd.duckdns.org/argocd"
    echo ""
    print_success "🚀 ¡El despliegue se completará automáticamente!"
else
    print_error "Error al hacer push a Git"
    exit 1
fi

# Sistema de Despliegue Automático (CI/CD) - ssh-mobile

Este proyecto utiliza un sistema de despliegue continuo para su **Frontend (Vue/Ionic)** y su **Backend (Node.js)**.

## Arquitectura del Sistema

El flujo de trabajo sigue el modelo de "GitOps" con versionado semántico:

1.  **Versionado**: El archivo `VERSION` en la raíz es la fuente de verdad.
2.  **Automatización**: El script `release.sh` gestiona el incremento de versión y la actualización de los despliegues (`k8s/frontend-deployment.yaml` y `k8s/backend-deployment.yaml`).
3.  **Pipeline**: GitHub Actions compila ambas imágenes para `linux/amd64` y `linux/arm64`.
4.  **Despliegue**: ArgoCD sincroniza los cambios al detectar las nuevas etiquetas de versión en Git.

## Cómo realizar un Release

Para desplegar una nueva versión (Front + Back), utiliza el script `release.sh`:

```bash
./release.sh patch "Descripción de los cambios"
```

### ¿Qué hace el script?
1.  Calcula la siguiente versión.
2.  Actualiza el archivo `VERSION`.
3.  Actualiza las imágenes en los archivos de Kubernetes.
4.  Crea un commit de release y un **Git Tag** (ej: `v1.0.1`).
5.  Sube todo a GitHub, disparando la construcción en la nube.

## Pipeline de GitHub Actions

El workflow en `.github/workflows/ci-cd.yml` realiza:
*   **Build Frontend**: Genera `ghcr.io/n0rthr3nd/ssh-mobile-frontend:v1.0.x`.
*   **Build Backend**: Genera `ghcr.io/n0rthr3nd/ssh-mobile-backend:v1.0.x`.
*   **Sync**: Notifica a la API de ArgoCD para sincronizar la aplicación `ssh-mobile`.

---
🤖 *Documentación generada automáticamente por Gemini CLI.*

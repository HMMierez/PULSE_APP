# ⚡ PULSE 2026 - Guía de Lanzamiento Cloud

¡Bienvenido a tu primer despliegue! Sigue estos pasos exactos para subir PULSE a la nube y verlo online sin instalar nada en tu PC.

## 1. Crear el Repositorio en GitHub
1. Entra a [github.com](https://github.com) e inicia sesión.
2. Haz clic en el botón **"+"** (arriba a la derecha) y elige **"New repository"**.
3. Ponle de nombre: `PULSE_APP`.
4. Elige **"Public"** o **"Private"** (como prefieras).
5. **IMPORTANTE**: No marques nada más (ni README, ni .gitignore). Haz clic en **"Create repository"**.

## 2. Vincular y Subir el Código (Vía Terminal)
Abre la terminal en la carpeta de tu proyecto (`PULSE_APP`) y escribe estos comandos uno por uno:

```bash
git init
git add .
git commit -m "feat: Lanzamiento inicial PULSE 2026"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/PULSE_APP.git
git push -u origin main
```
*(Reemplaza `TU_USUARIO` por tu nombre de usuario en GitHub).*

## 3. Configurar la "Magia" (GitHub Secrets)
Para que GitHub pueda desplegar en tu Firebase, necesitamos darle permiso:
1. Ve a tu repositorio en GitHub Web -> **Settings** -> **Secrets and variables** -> **Actions**.
2. Haz clic en **"New repository secret"**.
3. Nombre: `FIREBASE_SERVICE_ACCOUNT_PULSE_APP_2026_UNIQUE123`.
4. Valor: Debes pegar aquí el contenido del archivo JSON de tu **Service Account** de Firebase.
    *   *¿Cómo lo obtengo?* Ve a Firebase Console -> Project Settings -> Service Accounts -> Generate New Private Key.

## 4. Ver el Despegue
Una vez que hagas el `git push`, ve a la pestaña **"Actions"** en tu GitHub. Verás un proceso llamado "Deploy to Firebase Hosting". Cuando termine (en ~3 min), ¡tu app estará online!

---
*PULSE Squad: Visual - Core - Brain - Growth*

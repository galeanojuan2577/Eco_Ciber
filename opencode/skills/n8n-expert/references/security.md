# Guía de Seguridad n8n v2

Esta guía detalla las mejores prácticas para asegurar tus automatizaciones en n8n cloud y self-hosted.

## 1. Gestión de Credenciales
- **No Hardcoding**: Nunca incluyas claves de API o tokens directamente en nodos de función o expresiones. Usa siempre el sistema de Credenciales de n8n.
- **Principio de Menor Privilegio**: Crea credenciales específicas para cada servicio con los permisos mínimos necesarios.
- **Rotación**: Implementa un calendario de rotación para tus claves de API más críticas.

## 2. Protección de Webhooks
- **Autenticación**: Activa siempre la autenticación (Basic Auth o Header Auth) en tus Webhooks de entrada.
- **Validación de Payload**: Usa nodos de Filter o If para validar que los datos recibidos tienen la estructura y origen esperados.
- **IP Whitelisting**: Si es posible, limita el acceso a tus webhooks solo a las IPs de los servicios emisores.

## 3. Seguridad en Nodos de Código (Code Node)
- **Sanitización**: Valida y limpia cualquier entrada de usuario antes de procesarla en un nodo de código para evitar inyecciones.
- **Librerías Externas**: Evita habilitar `NODE_FUNCTION_ALLOW_EXTERNAL` a menos que sea estrictamente necesario y estés en un entorno controlado.

## 4. Hardening de la Instancia
- **Actualizaciones**: Mantén tu instancia de n8n actualizada a la última versión estable (v2.x+).
- **Logs**: Revisa periódicamente los logs de ejecución para detectar patrones de acceso inusuales.
- **Backup**: Asegura que tus workflows y credenciales tengan respaldos cifrados y fuera del servidor principal.

## 5. Control de Acceso
- **RBAC**: En versiones Enterprise, utiliza el control de acceso basado en roles para limitar quién puede editar o activar workflows críticos.
- **2FA**: Habilita la autenticación de dos factores para todos los usuarios con acceso a la interfaz de n8n.

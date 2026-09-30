# Cleanup Policy

Regla para **limpieza de artefactos** tras pruebas ofensivas. Obligatoria al final de cada engagement/sesión de hacking ético.

## 1. Qué limpiar

- **Procesos/daemons** temporales iniciados (listeners, medusas, reverse shells, servidores de phishing, contenedores de test).
- **Archivos temporales** en `/tmp` y directorios de trabajo (payloads, wordlists descargadas, dumps).
- **Herramientas/servicios** levantados solo para la prueba (docker ps → stop/rm si son de prueba).
- **Entradas de audit/scope** no necesarias (opcional mantener scope para re-test).
- **Cuentas/usuarios** creados en el lab que no deban persistir.

## 2. Procedimiento

1. Listar artefactos creados durante la sesión (revisar `audit.log`).
2. Detener procesos: `pkill -f <tool>` si fue prueba y no queda evidencia necesaria.
3. Borrar archivos temporales del workspace/target de pruebas.
4. Actualizar el informe con estado "cleanup completado".
5. Registrar en `audit-log.sh "cleanup: <detalle>"`.

## 3. Evidencia

- Mantener logs y reportes (evidencia de autorización y resultados).
- ELIMINAR credenciales/datos sensibles capturados en el lab que ya no se necesiten.
- No borrar `scope.json` si el engagement sigue activo.

## 4. Post-engagement

- Reporte finalizado y entregado.
- Ambiente restaurado.
- Audit log completo cerrado con la nota "engagement finalizado + cleanup OK".
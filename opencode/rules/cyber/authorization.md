# Authorization & Scope (Authorization)

Regla **obligatoria** antes de CUALQUIER acción ofensiva en este ecosistema. Define el consentimiento y alcance de forma técnica.

## 1. Autorización Previa (SoW — Statement of Work)

Antes de ejecutar cualquier acción ofensiva (escaneo activo, enumeración, explotación, DoS, phishing), el agente DEBE verificar que existe autorización registrada:

```bash
# Registrar/consultar alcance autorizado
bash __OPENCODE_ROOT__/tools/authorize.sh status      # ver scope.json
bash __OPENCODE_ROOT__/tools/authorize.sh list        # listar targets autorizados
bash __OPENCODE_ROOT__/tools/authorize.sh add <target> <tipo_test> <duración>  # añadir (con consentimiento)
bash __OPENCODE_ROOT__/tools/authorize.sh remove <target>
```

**Tipos de test válidos** para `scope.json`:
`recon`, `scan`, `enumerate`, `exploit`, `post-exploit`, `dos`, `phishing`.

## 2. Gate Flexible (check-scope)

ANTES de cada acción activa, ejecutar:

```bash
bash __OPENCODE_ROOT__/tools/check-scope.sh <target> <tipo_test>
```

- **Target en scope** → se permite la acción y se registra en el audit log.
- **Target FUERA de scope** → el gate es FLEXIBLE: se **pregunta al usuario**. Si el usuario confirma explícitamente la acción (declarando que es legal/consentida), se procede, se registra el override en el audit log y se puede añadir el target al scope con `authorize.sh add`.
- El comando devuelve exit code que los agentes deben leer: `0` = autorizado, `1` = requiere confirmación manual, `2` = rechazado con override.

## 3. Consentimiento y Legalidad

- El usuario declara la autorización legal del target (propio, laboratorio, o contratado con SoW).
- Si el usuario dice explícitamente "es legal / tengo consentimiento / autorizado", el agente procede y lo registra en `audit.log`. **Nunca** inventar autorización: si no hay confirmación, preguntar.

## 4. Auditoría

Cada acción ofensiva se registra vía `bash __OPENCODE_ROOT__/tools/audit-log.sh "<tool> <target> <tipo>"`. El log vive en `__OPENCODE_ROOT__/cyber/audit.log` y sirve como evidencia de que todo fue autorizado y trazable.

## 5. Fuera de alcance

Si la acción escapa del alcance (EDR detecta, target no listado, usuario no confirma), DETENERSE y reportar. Registrar la suspensión en el audit log.
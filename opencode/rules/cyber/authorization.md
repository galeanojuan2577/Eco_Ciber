# Authorization & Scope (Authorization)

Regla **obligatoria** antes de CUALQUIER acción ofensiva en este ecosistema. Define el consentimiento y alcance de forma técnica. Se aplica **por proyecto** (ver `rules/cyber/project-isolation.md`).

## 1. Autorización Previa (SoW — Statement of Work)

Cada bug bounty tiene su propio `scope.json` en `/root/.config/opencode/cyber/projects/<proyecto>/scope.json`. Antes de ejecutar cualquier acción ofensiva, el agente DEBE verificar el proyecto activo y su alcance:

```bash
bash /root/.config/opencode/tools/project-context.sh        # proyecto activo + path
bash /root/.config/opencode/tools/authorize.sh status       # ver scope del proyecto
bash /root/.config/opencode/tools/authorize.sh list         # listar targets autorizados
bash /root/.config/opencode/tools/authorize.sh add <target> <tipo_test> <duración>  # añadir (con consentimiento)
bash /root/.config/opencode/tools/authorize.sh remove <target>
bash /root/.config/opencode/tools/authorize.sh archive <proyecto>   # archivar finalizado
```

**Tipos de test válidos**: `recon`, `scan`, `enumerate`, `exploit`, `post-exploit`, `dos`, `phishing`.

**Flujo de inicio de un proyecto nuevo:**
```bash
bash /root/.config/opencode/tools/project-context.sh set <proyecto>   # pin de sesión
bash /root/.config/opencode/tools/authorize.sh init <programa_url>    # crear scope.json
```

## 2. Gate Flexible + Aislamiento (check-scope)

ANTES de cada acción activa, ejecutar:

```bash
bash /root/.config/opencode/tools/check-scope.sh <target> <tipo_test>
```

- **Target en scope del PROYECTO ACTIVO** → se permite la acción y se registra en el audit log (`exit 0`).
- **Target FUERA de scope del proyecto** → el gate es FLEXIBLE: se **pregunta al usuario**. Si confirma explícitamente (legal/consentida), se procede con `--force`, se registra el override y se puede añadir al scope con `authorize.sh add` (`exit 1`).
- **Target de OTRO proyecto** (aunque esté en su scope) → **RECHAZO DURO** (`exit 2`): el aislamiento por proyecto prohíbe atacar targets ajenos al proyecto activo. Para trabajarlo, cambiar de proyecto con `project-context.sh set <otro>`.
- El comando devuelve: `0` = autorizado, `1` = requiere confirmación manual, `2` = rechazado.

## 3. Consentimiento y Legalidad

- El usuario declara la autorización legal del target (propio, laboratorio, o contratado con SoW).
- Si el usuario dice explícitamente "es legal / tengo consentimiento / autorizado", el agente procede y lo registra en `audit.log`. **Nunca** inventar autorización: si no hay confirmación, preguntar.

## 4. Auditoría

Cada acción ofensiva se registra vía `bash /root/.config/opencode/tools/audit-log.sh "<tool> <target> <tipo>"`. El log vive en `/root/.config/opencode/cyber/audit.log`, se etiqueta automáticamente con `[proyecto=X]` y sirve como evidencia de que todo fue autorizado y trazable.

## 5. Fuera de alcance

Si la acción escapa del alcance del proyecto (EDR detecta, target no listado, usuario no confirma, target de otro proyecto), DETENERSE y reportar. Registrar la suspensión en el audit log.

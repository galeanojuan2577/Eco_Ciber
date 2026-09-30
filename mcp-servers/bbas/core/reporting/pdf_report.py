"""Generador de informe PDF en español para un proyecto BBAS."""
from __future__ import annotations

import json
from datetime import datetime
from typing import Any, Dict, List

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (PageBreak, Paragraph, SimpleDocTemplate,
                                Spacer, Table, TableStyle)

SEV_ORDER = {"critical": 0, "high": 1, "medium": 2, "low": 3, "info": 4}
SEV_ES = {"critical": "Crítica", "high": "Alta", "medium": "Media",
          "low": "Baja", "info": "Info"}


def _styles():
    ss = getSampleStyleSheet()
    return {
        "title": ParagraphStyle("t", parent=ss["Title"], fontSize=20, spaceAfter=6),
        "h2": ParagraphStyle("h2", parent=ss["Heading2"], textColor=colors.HexColor("#0369a1"),
                             spaceBefore=14, spaceAfter=6),
        "body": ParagraphStyle("b", parent=ss["BodyText"], fontSize=10, leading=14),
        "small": ParagraphStyle("s", parent=ss["BodyText"], fontSize=8.5, leading=11,
                                textColor=colors.HexColor("#475569")),
        "mono": ParagraphStyle("m", parent=ss["BodyText"], fontName="Courier", fontSize=8.5),
    }


def _table(data: List[List[str]], widths=None, header=True) -> Table:
    t = Table(data, colWidths=widths, repeatRows=1 if header else 0)
    style = [
        ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#cbd5e1")),
        ("FONTSIZE", (0, 0), (-1, -1), 8),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
    ]
    if header:
        style += [("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#0369a1")),
                  ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                  ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold")]
    t.setStyle(TableStyle(style))
    return t


def build_report(project: Dict[str, Any], targets: List[Dict], findings: List[Dict],
                 paths: List[Dict], scope_in: List[Dict], scope_out: List[Dict]) -> bytes:
    st = _styles()
    story = []
    now = datetime.now().strftime("%d/%m/%Y %H:%M")

    # ── Portada / resumen ──
    story.append(Paragraph("Informe de Reconocimiento — BBAS", st["title"]))
    story.append(Paragraph(
        f"<b>Programa:</b> {project['name']} &nbsp;&nbsp; "
        f"<b>Proyecto:</b> {project['id']}<br/>"
        f"<b>URL del programa:</b> {project.get('program_url') or '—'}<br/>"
        f"<b>Fecha:</b> {now}", st["body"]))
    story.append(Spacer(1, 8))

    total = len(targets)
    vivos = [t for t in targets if (t.get("status_code") or 0) > 0]
    locked = [t for t in targets if t.get("locked_type")]
    by_sev: Dict[str, int] = {}
    for f in findings:
        by_sev[f["severity"]] = by_sev.get(f["severity"], 0) + 1

    story.append(Paragraph("1. Resumen ejecutivo", st["h2"]))
    sev_line = " · ".join(f"{SEV_ES[k]}: {by_sev[k]}" for k in SEV_ORDER if by_sev.get(k)) or "sin hallazgos aún"
    story.append(Paragraph(
        f"Se descubrieron <b>{total}</b> activos dentro del alcance autorizado, de los cuales "
        f"<b>{len(vivos)}</b> responden por HTTP y <b>{len(locked)}</b> se descartaron por ser "
        f"superficies bloqueadas o falsas alarmas (SSO, GitHub Pages, errores CDN). "
        f"Hallazgos registrados: <b>{len(findings)}</b> ({sev_line}). "
        f"Cadenas de explotación definidas: <b>{len(paths)}</b>. "
        f"Los endpoints de autenticación, APIs UAT/SIT y paneles administrativos detectados "
        f"constituyen la superficie de mayor interés para testing manual.", st["body"]))

    # ── Alcance ──
    story.append(Paragraph("2. Alcance autorizado", st["h2"]))
    ins = ", ".join(r["target"] for r in scope_in[:40]) or "—"
    outs = ", ".join(r["target"] for r in scope_out[:40]) or "ninguno registrado"
    story.append(Paragraph(f"<b>In-scope:</b> {ins}", st["small"]))
    story.append(Paragraph(f"<b>Fuera de alcance (excluidos):</b> {outs}", st["small"]))

    # ── Top hosts ──
    story.append(PageBreak())
    story.append(Paragraph("3. Activos prioritarios (top 25 por score)", st["h2"]))
    rows = [["Score", "HTTP", "Host", "Título / Tecnología"]]
    for t in sorted(targets, key=lambda x: -(x.get("score") or 0))[:25]:
        rows.append([str(t.get("score") or 0), str(t.get("status_code") or "—"),
                     t["host"], (t.get("title") or "")[:60]])
    story.append(_table(rows, widths=[12*mm, 12*mm, 62*mm, None]))

    # ── Hallazgos ──
    story.append(Paragraph("4. Hallazgos", st["h2"]))
    if findings:
        fh = [["Sev", "Título", "Host", "Tool", "Bounty"]]
        for f in sorted(findings, key=lambda x: SEV_ORDER.get(x["severity"], 9)):
            fh.append([SEV_ES.get(f["severity"], f["severity"]), f["title"][:70],
                       f["target_host"][:38], f.get("tool", ""), f.get("bounty_probability", "")])
        story.append(_table(fh, widths=[16*mm, 68*mm, 48*mm, 18*mm, 18*mm]))
    else:
        story.append(Paragraph(
            "Sin hallazgos automatizados todavía. Ejecuta un scan con «Deep scan» para correr "
            "nuclei sobre los hosts vivos, o registra hallazgos manuales desde la interfaz.",
            st["body"]))

    # ── Attack paths ──
    if paths:
        story.append(Paragraph("5. Cadenas de explotación planificadas", st["h2"]))
        ph = [["Nombre", "Sev", "Estado", "Pasos"]]
        for p in paths:
            ph.append([p["name"][:55], p["severity"], p["status"], str(len(p.get("steps") or []))])
        story.append(_table(ph, widths=[80*mm, 18*mm, 26*mm, None]))

    # ── Conclusiones ──
    story.append(Paragraph("Conclusiones y próximos pasos sugeridos", st["h2"]))
    auth_hosts = [t["host"] for t in vivos if any(k in t["host"].lower()
                  for k in ("auth", "login", "sso", "adfs", "portal", "admin"))]
    api_uat = [t["host"] for t in vivos if any(k in t["host"].lower()
               for k in ("uat", "sit", "ppt", "stg", "dev", "test"))]
    bullets = []
    if auth_hosts:
        bullets.append(f"Probar bypass de autenticación y enumeración de usuarios en: "
                       f"{', '.join(auth_hosts[:6])}.")
    if api_uat:
        bullets.append(f"Entornos no productivos expuestos (UAT/SIT/PPT) con menor hardening: "
                       f"{', '.join(api_uat[:6])} — candidatos ideales a IDOR y fallos de lógica.")
    obapi = [t["host"] for t in vivos if "obapi" in t["host"].lower()]
    if obapi:
        bullets.append(f"Endpoints Open Banking detectados ({', '.join(obapi[:3])}): revisar "
                       f"autorización a nivel de objeto (BOLA/IDOR) y firmas de mensajes.")
    bullets.append("Ejecutar deep scan (nuclei) sobre los hosts vivos para ampliar cobertura "
                   "automatizada antes del testing manual.")
    bullets.append("Registrar cada explotación confirmada como hallazgo manual para incluir "
                   "el PoC sanitizado en el envío al programa.")
    for b in bullets:
        story.append(Paragraph(f"• {b}", st["body"]))

    story.append(Spacer(1, 10))
    story.append(Paragraph(
        "Generado automáticamente por BBAS. Toda prueba debe respetar las reglas del programa; "
        "este documento no sustituye la revisión humana de cada hallazgo.", st["small"]))

    from io import BytesIO
    buf = BytesIO()
    doc = SimpleDocTemplate(buf, pagesize=A4, leftMargin=18*mm, rightMargin=18*mm,
                            topMargin=16*mm, bottomMargin=16*mm,
                            title=f"Informe BBAS {project['name']}")
    doc.build(story)
    return buf.getvalue()

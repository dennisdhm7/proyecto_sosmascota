import json
import sys
import os

# Configuración de Colores (Estilo SOS Mascota)
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SOS Mascota - Reporte Semgrep</title>
    <style>
        :root {{
            --primary: #008080;
            --bg: #f4f4f9;
            --text: #333;
            --white: #ffffff;
            --critical: #dc3545;
            --high: #fd7e14;
            --medium: #ffc107;
            --low: #17a2b8;
        }}
        body {{ font-family: 'Segoe UI', sans-serif; background-color: var(--bg); color: var(--text); margin: 0; padding: 40px; }}
        .container {{ max-width: 1200px; margin: 0 auto; background: var(--white); padding: 30px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.05); }}
        
        header {{ border-bottom: 2px solid var(--primary); padding-bottom: 20px; margin-bottom: 30px; display: flex; justify-content: space-between; align-items: center; }}
        h1 {{ color: var(--primary); margin: 0; font-size: 24px; }}
        .meta {{ font-size: 14px; color: #666; }}

        .summary-box {{ display: flex; gap: 20px; margin-bottom: 30px; }}
        .stat {{ background: #f8f9fa; padding: 15px; border-radius: 8px; border-left: 5px solid var(--primary); flex: 1; }}
        .stat strong {{ display: block; font-size: 24px; color: var(--primary); }}
        .stat span {{ font-size: 14px; color: #666; }}

        table {{ width: 100%; border-collapse: collapse; font-size: 14px; }}
        th {{ background-color: var(--primary); color: white; text-align: left; padding: 12px; }}
        td {{ padding: 12px; border-bottom: 1px solid #ddd; vertical-align: top; }}
        tr:hover {{ background-color: #f1f1f1; }}

        .badge {{ padding: 4px 8px; border-radius: 4px; color: white; font-weight: bold; font-size: 11px; display: inline-block; text-transform: uppercase; }}
        .severity-error {{ background-color: var(--critical); }}
        .severity-warning {{ background-color: var(--high); }}
        .severity-note {{ background-color: var(--low); }}

        .code-loc {{ font-family: 'Consolas', monospace; color: #d63384; font-size: 12px; }}
        .empty-state {{ text-align: center; padding: 40px; background: #d1fae5; color: #065f46; border-radius: 8px; }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div>
                <h1>🛡️ SOS Mascota - Análisis de Código (Semgrep)</h1>
                <div class="meta">Reporte de Seguridad Estática (SAST)</div>
            </div>
            <div><strong>Estado:</strong> Finalizado</div>
        </header>

        {content}

        <div style="text-align: center; color: #999; font-size: 12px; margin-top: 30px;">
            Generado automáticamente por GitHub Actions
        </div>
    </div>
</body>
</html>
"""

def convert_sarif_to_html(sarif_path, output_path):
    try:
        with open(sarif_path, 'r') as f:
            data = json.load(f)
    except FileNotFoundError:
        print("No se encontró el archivo SARIF")
        return

    results = []
    # SARIF structure navigation
    for run in data.get('runs', []):
        results.extend(run.get('results', []))

    if not results:
        content = """
        <div class="empty-state">
            <h2 style="margin:0">✅ ¡Excelente!</h2>
            <p>No se encontraron patrones de código inseguro ni vulnerabilidades.</p>
        </div>
        """
    else:
        rows = ""
        for res in results:
            rule_id = res.get('ruleId', 'Unknown')
            message = res.get('message', {}).get('text', '')
            level = res.get('level', 'warning') # error, warning, note
            
            # Location
            loc = res.get('locations', [{}])[0].get('physicalLocation', {})
            file_path = loc.get('artifactLocation', {}).get('uri', 'unknown file')
            line = loc.get('region', {}).get('startLine', 0)

            rows += f"""
            <tr>
                <td><span class="badge severity-{level}">{level}</span></td>
                <td><strong>{rule_id}</strong><br>{message}</td>
                <td class="code-loc">{file_path}<br>Línea: {line}</td>
            </tr>
            """
        
        content = f"""
        <div class="summary-box">
            <div class="stat"><strong>{len(results)}</strong> <span>Hallazgos Totales</span></div>
        </div>
        <table>
            <thead>
                <tr>
                    <th style="width: 100px;">Severidad</th>
                    <th>Descripción del Hallazgo</th>
                    <th style="width: 250px;">Ubicación</th>
                </tr>
            </thead>
            <tbody>
                {rows}
            </tbody>
        </table>
        """

    final_html = HTML_TEMPLATE.format(content=content)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(final_html)
    print(f"Reporte generado exitosamente en: {output_path}")

if __name__ == "__main__":
    convert_sarif_to_html("semgrep.sarif", "semgrep-report.html")
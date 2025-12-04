<!DOCTYPE html>
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  <title>SOS Mascota - Reporte de Seguridad Trivy</title>
  <style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; background-color: #f4f4f9; }
    .header { background-color: #008080; color: white; padding: 20px; text-align: center; }
    .container { padding: 20px; max-width: 1200px; margin: 0 auto; }
    table { width: 100%; border-collapse: collapse; margin-top: 20px; background: white; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
    th { background-color: #006666; color: white; padding: 12px; text-align: left; }
    td { padding: 12px; border-bottom: 1px solid #ddd; }
    .severity-CRITICAL { color: #d9534f; font-weight: bold; }
    .severity-HIGH { color: #f0ad4e; font-weight: bold; }
    .severity-MEDIUM { color: #5bc0de; }
    .vuln-title { font-weight: bold; display: block; }
    .footer { text-align: center; margin-top: 40px; color: #777; font-size: 0.9em; }
  </style>
</head>
<body>
  <div class="header">
    <h1>🛡️ SOS Mascota - Reporte de Seguridad (Trivy)</h1>
    <p>Análisis de Dependencias y Contenedores</p>
  </div>
  <div class="container">
    {{ range . }}
      <h2>Target: {{ .Target }}</h2>
      {{ if (eq (len .Vulnerabilities) 0) }}
        <div style="background: #dff0d8; color: #3c763d; padding: 15px; border-radius: 4px;">
          ✅ ¡Excelente! No se encontraron vulnerabilidades críticas o altas.
        </div>
      {{ else }}
        <table>
          <tr>
            <th>ID</th>
            <th>Paquete</th>
            <th>Severidad</th>
            <th>Versión Instalada</th>
            <th>Versión Fija</th>
            <th>Título</th>
          </tr>
          {{ range .Vulnerabilities }}
          <tr>
            <td><a href="{{ .PrimaryURL }}" target="_blank">{{ .VulnerabilityID }}</a></td>
            <td>{{ .PkgName }}</td>
            <td class="severity-{{ .Severity }}">{{ .Severity }}</td>
            <td>{{ .InstalledVersion }}</td>
            <td>{{ .FixedVersion }}</td>
            <td>{{ .Title }}</td>
          </tr>
          {{ end }}
        </table>
      {{ end }}
      <br><hr><br>
    {{ end }}
  </div>
  <div class="footer">Generado automáticamente por GitHub Actions para SOS Mascota</div>
</body>
</html>
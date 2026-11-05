import os
import re
import subprocess

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TPI2_DIR = os.path.join(BASE_DIR, "docs", "tpi_parcial2")
MD_PATH = os.path.join(TPI2_DIR, "informe_tpi_parcial2.md")
HTML_PATH = os.path.join(TPI2_DIR, "informe_tpi_parcial2.html")
PDF_PATH = os.path.join(TPI2_DIR, "informe_tpi_parcial2.pdf")

CSS_STYLES = """
    @page {
        size: A4;
        margin: 10mm 12mm 10mm 12mm;
    }
    body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        font-size: 8pt;
        line-height: 1.35;
        color: #1a202c;
        margin: 0;
        padding: 0;
    }
    .header {
        border-bottom: 2px solid #2b6cb0;
        padding-bottom: 5px;
        margin-bottom: 10px;
    }
    .header h1 {
        font-size: 14pt;
        color: #2b6cb0;
        margin: 0 0 3px 0;
        font-weight: 700;
        letter-spacing: -0.2px;
    }
    .header .subtitle {
        font-size: 8.5pt;
        color: #4a5568;
        font-weight: 600;
    }
    .meta-grid {
        display: grid;
        grid-template-columns: repeat(2, 1fr);
        gap: 3px 12px;
        background-color: #ebf8ff;
        border: 1px solid #bee3f8;
        border-radius: 4px;
        padding: 5px 10px;
        font-size: 7.5pt;
        margin-top: 5px;
        color: #2c5282;
    }
    .meta-grid strong {
        color: #1a365d;
    }
    h2 {
        font-size: 10.5pt;
        color: #2b6cb0;
        border-bottom: 1px solid #e2e8f0;
        padding-bottom: 2px;
        margin-top: 14px;
        margin-bottom: 6px;
        font-weight: 700;
        page-break-after: avoid;
    }
    h3 {
        font-size: 9pt;
        color: #2d3748;
        margin-top: 10px;
        margin-bottom: 4px;
        font-weight: 600;
        page-break-after: avoid;
    }
    h4 {
        font-size: 8.2pt;
        color: #4a5568;
        margin-top: 8px;
        margin-bottom: 3px;
        font-weight: 600;
        page-break-after: avoid;
    }
    p {
        margin: 0 0 5px 0;
        text-align: justify;
    }
    ul, ol {
        margin: 0 0 6px 0;
        padding-left: 18px;
    }
    li {
        margin-bottom: 2px;
    }
    table {
        width: 100%;
        border-collapse: collapse;
        font-size: 7.2pt;
        margin: 6px 0 8px 0;
        page-break-inside: avoid;
    }
    th, td {
        border: 1px solid #cbd5e0;
        padding: 3px 6px;
        text-align: left;
    }
    th {
        background-color: #edf2f7;
        color: #2d3748;
        font-weight: 600;
    }
    tr:nth-child(even) td {
        background-color: #f7fafc;
    }
    pre {
        background-color: #2d3748;
        color: #f7fafc;
        padding: 6px 9px;
        border-radius: 4px;
        font-size: 6.8pt;
        font-family: "Consolas", "Courier New", monospace;
        line-height: 1.25;
        overflow-x: auto;
        margin: 5px 0 7px 0;
        page-break-inside: avoid;
    }
    code {
        font-family: "Consolas", "Courier New", monospace;
        font-size: 7.2pt;
        background-color: #edf2f7;
        color: #b83280;
        padding: 1px 3px;
        border-radius: 3px;
    }
    pre code {
        background-color: transparent;
        color: inherit;
        padding: 0;
    }
    blockquote {
        border-left: 3px solid #3182ce;
        background-color: #ebf8ff;
        margin: 4px 0 6px 0;
        padding: 4px 8px;
        font-style: italic;
        color: #2c5282;
        page-break-inside: avoid;
    }
    .badge {
        display: inline-block;
        padding: 1px 5px;
        border-radius: 3px;
        font-weight: bold;
        font-size: 6.8pt;
    }
    .badge-green { background-color: #c6f6d5; color: #22543d; }
    .badge-blue { background-color: #bee3f8; color: #2c5282; }
    .badge-yellow { background-color: #fefcbf; color: #744210; }
    .footer {
        margin-top: 15px;
        border-top: 1px solid #e2e8f0;
        padding-top: 4px;
        font-size: 6.8pt;
        color: #718096;
        text-align: right;
    }
"""

def parse_markdown_to_html(md_text):
    lines = md_text.splitlines()
    html_lines = []
    
    in_code_block = False
    code_lang = ""
    code_content = []
    
    in_table = False
    table_header = []
    table_rows = []
    
    in_list = False
    
    def inline_format(text):
        # Escape html entities except in code
        text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        # Bold + Italic
        text = re.sub(r'\*\*\*(.*?)\*\*\*', r'<strong><em>\1</em></strong>', text)
        # Bold
        text = re.sub(r'\*\*(.*?)\*\*', r'<strong>\1</strong>', text)
        # Italic
        text = re.sub(r'\*(.*?)\*', r'<em>\1</em>', text)
        # Inline code
        text = re.sub(r'`(.*?)`', r'<code>\1</code>', text)
        # Links: [text](url)
        text = re.sub(r'\[(.*?)\]\((.*?)\)', r'<a href="\2">\1</a>', text)
        # Badges
        text = text.replace("Acreditado", '<span class="badge badge-green">Acreditado</span>')
        text = text.replace("Válido", '<span class="badge badge-green">Válido</span>')
        text = text.replace("Consistente", '<span class="badge badge-green">Consistente</span>')
        text = text.replace("SÍ (100%)", '<span class="badge badge-green">SÍ (100%)</span>')
        return text

    for line in lines:
        stripped = line.strip()
        
        # Code block
        if stripped.startswith("```"):
            if not in_code_block:
                in_code_block = True
                code_lang = stripped[3:].strip()
                code_content = []
            else:
                in_code_block = False
                escaped_code = "\n".join(code_content).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                html_lines.append(f'<pre><code class="language-{code_lang}">{escaped_code}</code></pre>')
            continue
            
        if in_code_block:
            code_content.append(line)
            continue
            
        # Table parsing
        if stripped.startswith("|") and stripped.endswith("|"):
            cells = [c.strip() for c in stripped.split("|")[1:-1]]
            if not in_table:
                in_table = True
                table_header = cells
                table_rows = []
            else:
                # Check if it's separator row
                if re.match(r'^[\s\-:|]+$', stripped):
                    pass # delimiter row
                else:
                    table_rows.append(cells)
            continue
        elif in_table:
            # End of table
            in_table = False
            tbl_html = "<table><thead><tr>"
            for th in table_header:
                tbl_html += f"<th>{inline_format(th)}</th>"
            tbl_html += "</tr></thead><tbody>"
            for row in table_rows:
                tbl_html += "<tr>"
                for td in row:
                    tbl_html += f"<td>{inline_format(td)}</td>"
                tbl_html += "</tr>"
            tbl_html += "</tbody></table>"
            html_lines.append(tbl_html)
            
        # Blank line
        if not stripped:
            if in_list:
                html_lines.append("</ul>")
                in_list = False
            continue
            
        # Lists
        if stripped.startswith("* ") or stripped.startswith("- "):
            if not in_list:
                in_list = True
                html_lines.append("<ul>")
            item_text = stripped[2:]
            html_lines.append(f"<li>{inline_format(item_text)}</li>")
            continue
        elif in_list:
            html_lines.append("</ul>")
            in_list = False
            
        # Blockquote
        if stripped.startswith("> "):
            bq_text = stripped[2:]
            html_lines.append(f"<blockquote>{inline_format(bq_text)}</blockquote>")
            continue
            
        # Headers
        if stripped.startswith("# "):
            html_lines.append(f"<h1>{inline_format(stripped[2:])}</h1>")
        elif stripped.startswith("## "):
            html_lines.append(f"<h2>{inline_format(stripped[3:])}</h2>")
        elif stripped.startswith("### "):
            html_lines.append(f"<h3>{inline_format(stripped[4:])}</h3>")
        elif stripped.startswith("#### "):
            html_lines.append(f"<h4>{inline_format(stripped[5:])}</h4>")
        elif stripped.startswith("---"):
            html_lines.append("<hr style='border: none; border-top: 1px solid #cbd5e0; margin: 10px 0;'>")
        else:
            # Normal paragraph
            html_lines.append(f"<p>{inline_format(line)}</p>")
            
    if in_table:
        tbl_html = "<table><thead><tr>"
        for th in table_header:
            tbl_html += f"<th>{inline_format(th)}</th>"
        tbl_html += "</tr></thead><tbody>"
        for row in table_rows:
            tbl_html += "<tr>"
            for td in row:
                tbl_html += f"<td>{inline_format(td)}</td>"
            tbl_html += "</tr>"
        tbl_html += "</tbody></table>"
        html_lines.append(tbl_html)
        
    if in_list:
        html_lines.append("</ul>")
        
    return "\n".join(html_lines)

def main():
    print("[*] Leyendo markdown de origen:", MD_PATH)
    with open(MD_PATH, "r", encoding="utf-8") as f:
        md_text = f.read()

    body_html = parse_markdown_to_html(md_text)
    
    full_html = f"""<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>TPI Segunda Entrega — Food Store (Base de Datos II)</title>
<style>
{CSS_STYLES}
</style>
</head>
<body>
    <div class="header">
        <h1>FOOD STORE — PROYECTO INTEGRADOR</h1>
        <div class="subtitle">Trabajo Práctico Integrador · Segunda Entrega Parcial (Unidades 4 a 8) · UTN TUP</div>
        <div class="meta-grid">
            <div><strong>Estudiante:</strong> Cristian Rodriguez (Cloverfield)</div>
            <div><strong>Materia:</strong> Base de Datos II (Ciclo Lectivo 2026)</div>
            <div><strong>Rama de Entrega:</strong> tpi-parcial2</div>
            <div><strong>Motores:</strong> PostgreSQL 17.11 · MongoDB 9.0.4 · SQLite 3.50.4</div>
        </div>
    </div>
    
    {body_html}
    
    <div class="footer">
        Base de Datos II · Proyecto Integrador Food Store · UTN Tecnicatura Universitaria en Programación
    </div>
</body>
</html>
"""
    print("[*] Escribiendo HTML:", HTML_PATH)
    with open(HTML_PATH, "w", encoding="utf-8") as f:
        f.write(full_html)
    print("    [+] Archivo HTML generado exitosamente.")

    # Edge Headless compilation
    edge_path = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    if not os.path.exists(edge_path):
        edge_path = r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"

    if os.path.exists(edge_path):
        print("[*] Compilando a PDF con Edge Headless:", edge_path)
        cmd = [
            edge_path,
            "--headless",
            "--disable-gpu",
            "--run-all-compositor-stages-before-draw",
            f"--print-to-pdf={PDF_PATH}",
            HTML_PATH
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0:
            print("    [+] Archivo PDF generado exitosamente:", PDF_PATH)
        else:
            print("    [!] Error al generar PDF:", res.stderr)
    else:
        print("[!] No se encontró msedge.exe.")

if __name__ == "__main__":
    main()

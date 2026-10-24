"""Create a per-frame test report from verified Android Emulator screenshots."""
from pathlib import Path
import hashlib
import json
import math

from PIL import Image
from pypdf import PdfReader
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.colors import HexColor
from reportlab.lib.utils import simpleSplit
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / 'docs/qa/ui-copy-device'
OUT = ROOT / 'output/pdf/ruma-report-per-frame.pdf'


def main():
    report = json.loads((QA / 'frame-report.json').read_text())
    run = json.loads((QA / 'device-results.json').read_text())
    assert run.get('passed') is True and run['project'] == 'demo-ruma'
    frames = report['frames']
    assert len(frames) == 27 and len({f['id'] for f in frames}) == 27
    assert {f['id'] for f in frames} == set(run['screens'])
    hashes = {f['id']: hashlib.sha256((QA / (f['id']+'.png')).read_bytes()).hexdigest() for f in frames}
    assert len(set(hashes.values())) == 27, 'Repeated screenshots'
    pdfmetrics.registerFont(TTFont('Report', '/usr/share/fonts/TTF/DejaVuSans.ttf'))
    pdfmetrics.registerFont(TTFont('ReportBold', '/usr/share/fonts/TTF/DejaVuSans-Bold.ttf'))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    w, h = landscape(A4)
    c = canvas.Canvas(str(OUT), pagesize=(w, h), pageCompression=1)
    c.setTitle('Ruma - laporan pengujian emulator per layar')
    c.setAuthor('Ruma')
    ink, muted, accent = map(HexColor, ['#20241F', '#56614F', '#CF4924'])
    palette = {'LULUS': '#E5EDE1', 'CATATAN': '#FFF0E7', 'PERLU REVISI': '#F7DAD6'}
    pages = 1 + math.ceil(len(frames)/3)

    def text(value, x, y, size=9, bold=False, color=ink):
        c.setFillColor(color); c.setFont('ReportBold' if bold else 'Report', size)
        c.drawString(x, y, value)

    def wrap(value, x, y, width, size=9, leading=12, maximum=10, **kwargs):
        lines = simpleSplit(value, 'Report', size, width)
        assert len(lines) <= maximum, (value, len(lines), maximum)
        for line in lines:
            text(line, x, y, size=size, **kwargs); y -= leading
        return y

    def page_base(number, title):
        c.setFillColor(HexColor('#F6F7F3')); c.rect(0, 0, w, h, fill=1, stroke=0)
        text('ruma', 28, h-32, 19, True)
        text(title, 103, h-30, 10, color=muted)
        c.setFont('Report', 8); c.setFillColor(muted)
        c.drawRightString(w-28, h-30, report['dateLabel'])
        text('Android Emulator API 35 - data sintetis - sebutkan nomor layar untuk revisi', 28, 14, 7.5, color=muted)
        c.drawRightString(w-28, 14, f'{number} / {pages}')

    page_base(1, 'Laporan pengujian per layar')
    text('Hasil uji Ruma di Android Emulator', 28, h-91, 25, True)
    wrap('Revisi teks ringkas dan kartu Asisten. Screenshot dari aplikasi yang benar-benar berjalan di AVD, bukan render Figma.', 28, h-117, w-56, 10, 15, 2, color=muted)
    stats = [('27', 'layar / dialog dicapture'), ('LULUS', 'suite teknis akhir'),
             (str(sum(f['status']=='PERLU REVISI' for f in frames)), 'temuan perlu revisi'), ('0', 'panggilan AI / tulis produksi')]
    for i, (value, label) in enumerate(stats):
        x = 28+i*(w-56)/4
        c.setFillColor(HexColor('#FFFFFF')); c.roundRect(x, h-225, 183, 72, 12, fill=1, stroke=0)
        text(value, x+14, h-184, 22, True)
        text(label, x+14, h-207, 8, color=muted)
    text('Lingkungan dan arti status', 28, h-257, 12, True)
    wrap('Pixel 5 / Android 15 (API 35), x86_64, 1080 x 2340, density 440, RAM 2 GB, 2 core, akselerasi KVM. Backend uji: Auth + Firestore lokal demo-ruma.', 28, h-280, w-56, 9, 14, 3)
    wrap('LULUS = pemeriksaan tampilan pada keadaan yang dicapture tidak menemukan masalah yang perlu revisi. CATATAN = tampilan dapat digunakan, tetapi ada batas uji atau perbedaan rancangan penting. PERLU REVISI = temuan UI yang terkonfirmasi. Lulus teknis tidak berarti seluruh fungsi produk sudah selesai.', 28, h-323, w-56, 9, 14, 4)
    text('Temuan dan batas pengujian', 28, h-385, 12, True)
    y = h-409
    for item in report['summary']:
        y = wrap('- '+item, 28, y, w-56, 9, 13, 3)-6
    c.showPage()

    for batch in range(math.ceil(len(frames)/3)):
        group = frames[batch*3:batch*3+3]
        page_base(batch+2, f'Pemeriksaan layar - kelompok {batch+1}')
        for col, frame in enumerate(group):
            x = 28 + col*(w-56)/3
            colwidth = (w-56)/3 - 15
            c.bookmarkPage(frame['id']); c.addOutlineEntry(frame['id'][:2]+' - '+frame['title'], frame['id'])
            text(frame['id'][:2], x, h-61, 10, True, accent)
            text(frame['title'], x+24, h-61, 10, True)
            status = frame['status']
            badgewidth = pdfmetrics.stringWidth(status, 'ReportBold', 8)+16
            c.setFillColor(HexColor(palette[status])); c.roundRect(x, h-88, badgewidth, 18, 6, fill=1, stroke=0)
            text(status, x+8, h-82, 8, True)
            im = Image.open(QA / (frame['id']+'.png'))
            sh = 350; sw = sh*im.width/im.height
            c.drawImage(str(QA / (frame['id']+'.png')), x+(colwidth-sw)/2, 153, width=sw, height=sh)
            y = wrap('Uji: '+frame['checked'], x, 134, colwidth, 8.5, 11.5, 3)
            wrap('Catatan: '+frame['note'], x, y-5, colwidth, 8.5, 11.5, 4, color=muted)
        c.showPage()
    c.save()
    pdf = PdfReader(OUT)
    assert len(pdf.pages) == pages
    content = '\n'.join(page.extract_text() for page in pdf.pages)
    for f in frames: assert f['title'] in content
    (QA / 'pdf-verification.json').write_text(json.dumps({
        'pdf': str(OUT.relative_to(ROOT)), 'pages': pages, 'screens': len(frames),
        'allFrameLabelsPresent': True, 'uniqueScreenshots': len(set(hashes.values())),
        'screenshotSha256': hashes, 'pdfSha256': hashlib.sha256(OUT.read_bytes()).hexdigest(),
        'renderReviewed': False, 'source': 'Android Emulator API35; local demo-ruma; 2026-10-20',
    }, indent=2)+'\n')
    print(OUT)


if __name__ == '__main__': main()

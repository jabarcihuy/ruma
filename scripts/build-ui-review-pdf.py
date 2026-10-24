"""Build the UI review PDF from native phone captures, without changing images."""
from pathlib import Path
import argparse
import hashlib
import json

from PIL import Image
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.colors import HexColor
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/pdf/ruma-review-antarmuka.pdf'
SCREENS = [
    ('01-welcome', 'Sambutan'), ('02-signin', 'Masuk'), ('03-signup', 'Daftar'),
    ('04-home', 'Beranda'), ('05-agenda', 'Agenda'), ('08-agenda-detail', 'Detail agenda'),
    ('06-task-form', 'Form tugas / kegiatan'), ('07-class-form', 'Form kuliah'), ('23-date-picker', 'Pilih tanggal'),
    ('24-time-picker', 'Pilih waktu'), ('09-finance', 'Keuangan'), ('10-expense-form', 'Form pengeluaran'),
    ('11-income-form', 'Form pemasukan'), ('12-budget-form', 'Form anggaran'), ('13-history', 'Riwayat transaksi'),
    ('14-report', 'Laporan keuangan'), ('15-transaction-detail', 'Detail transaksi'), ('16-profile', 'Profil'),
    ('17-profile-name-dialog', 'Ubah nama'), ('18-privacy', 'Privasi'), ('19-assistant', 'Asisten'),
    ('20-combined-review', 'Tinjauan draf gabungan'), ('26-combined-review-actions', 'Tinjauan - tombol simpan'), ('21-combined-saved', 'Draf tersimpan'),
    ('22-assistant-keyboard', 'Asisten + keyboard'), ('25-finance-large-text', 'Keuangan - teks 130%'),
    ('27-assistant-info', 'Informasi Asisten'),
]
GROUPS = ['Awal dan akun', 'Ringkasan dan agenda', 'Form agenda dan tanggal',
          'Waktu dan pengeluaran', 'Pemasukan, anggaran dan riwayat',
          'Laporan dan profil', 'Pengaturan dan Asisten', 'Draf gabungan', 'Keyboard, teks besar dan informasi']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--qa-dir', default='docs/qa/ui-polish')
    parser.add_argument('--source', default='HP Android')
    args = parser.parse_args()
    QA = ROOT / args.qa_dir
    result = json.loads((QA / 'device-results.json').read_text())
    assert result.get('passed') is True and result.get('project') == 'demo-ruma'
    images = [QA / f'{key}.png' for key, _ in SCREENS]
    hashes = [hashlib.sha256(path.read_bytes()).hexdigest() for path in images]
    assert len(set(hashes)) == len(images), 'Repeated capture: review source images'
    OUT.parent.mkdir(parents=True, exist_ok=True)
    pdfmetrics.registerFont(TTFont('Manrope', str(ROOT / 'design/assets/ruma/fonts/Manrope-Variable.ttf')))
    w, h = landscape(A4)
    c = canvas.Canvas(str(OUT), pagesize=(w, h), pageCompression=1)
    c.setTitle('Ruma - review antarmuka aplikasi')
    c.setAuthor('Ruma')
    ink, muted, accent = map(HexColor, ['#20241F', '#5F6859', '#CF4924'])
    for page in range(9):
        c.setFillColor(HexColor('#F6F7F3')); c.rect(0, 0, w, h, fill=1, stroke=0)
        c.setFont('Manrope', 18); c.setFillColor(ink); c.drawString(30, h-33, 'ruma')
        c.setFont('Manrope', 10); c.setFillColor(muted); c.drawString(95, h-31, GROUPS[page])
        c.setFont('Manrope', 8); c.drawRightString(w-30, h-31, 'REVIEW ANTARMUKA / 19 OKTOBER 2026')
        for col, (key, title) in enumerate(SCREENS[page*3:page*3+3]):
            x = 30 + col*(w-60)/3
            c.bookmarkPage(key); c.addOutlineEntry(f'{key[:2]} - {title}', key, level=0)
            c.setFillColor(accent); c.setFont('Manrope', 9); c.drawString(x, h-61, key[:2])
            c.setFillColor(ink); c.setFont('Manrope', 10); c.drawString(x+22, h-61, title)
            im = Image.open(QA / f'{key}.png')
            height = h-101; width = height*im.width/im.height
            ix = x + ((w-60)/3-16-width)/2
            c.drawImage(str(QA / f'{key}.png'), ix, 27, width=width, height=height)
        c.setFillColor(muted); c.setFont('Manrope', 8)
        c.drawString(30, 12, f'{args.source} - data sintetis. Untuk revisi, sebutkan nomor layar.')
        c.drawRightString(w-30, 12, f'{page+1} / 9')
        c.showPage()
    c.save()
    reader = PdfReader(OUT)
    assert len(reader.pages) == 9
    text = '\n'.join(p.extract_text() for p in reader.pages)
    for _, title in SCREENS: assert title in text, title
    (QA / 'pdf-verification.json').write_text(json.dumps({
        'pdf': str(OUT.relative_to(ROOT)), 'pages': 9, 'screens': len(SCREENS),
        'uniqueSourceImages': len(set(hashes)), 'pageSize': 'A4 landscape',
        'source': args.source + '; demo-ruma synthetic data',
        'allScreenLabelsPresent': True,
        'sha256': hashlib.sha256(OUT.read_bytes()).hexdigest(),
        'renderReviewed': False,
    }, indent=2)+'\n')
    print(OUT)


if __name__ == '__main__': main()

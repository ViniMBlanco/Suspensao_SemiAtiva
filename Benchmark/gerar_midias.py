"""Gera o PNG e o MP4 a partir dos CSVs do benchmark."""
import argparse
import csv
import gzip
import os
from pathlib import Path
import subprocess
from functools import lru_cache

import numpy as np
from PIL import Image, ImageDraw, ImageFont


PASTA = Path(__file__).resolve().parent
FUNDO, PAINEL, TINTA = "#F0F4F8", "#FFFFFF", "#142638"
SECUNDARIA, LINHA = "#4C6273", "#DCE5EB"
CORES = ("#8493A1", "#006DA8", "#B4471F")
MODELOS = ("Passiva", "V3", "CDC")
ROTULOS = ("Passiva", "Nossa V3", "Modelo ZF CDC")


@lru_cache
def fonte(tamanho, negrito=False, pasta_fontes=None):
    nomes = ("segoeuib.ttf", "DejaVuSans-Bold.ttf") if negrito else ("segoeui.ttf", "DejaVuSans.ttf")
    pastas = [Path(pasta_fontes)] if pasta_fontes else []
    pastas += [Path(os.environ.get("WINDIR", "C:/Windows")) / "Fonts",
               Path("/usr/share/fonts/truetype/dejavu")]
    for pasta in pastas:
        for nome in nomes:
            arquivo = pasta / nome
            if arquivo.is_file():
                return ImageFont.truetype(str(arquivo), tamanho)
    return ImageFont.load_default(size=tamanho)


def texto(d, xy, valor, tamanho, cor=TINTA, negrito=False, anchor=None, fontes=None):
    d.text(xy, valor, fill=cor, font=fonte(tamanho, negrito, fontes), anchor=anchor)


def numero(x, casas=1):
    valor = round(float(x), casas)
    return f"{valor or 0:.{casas}f}".replace(".", ",")


def ler_resumo():
    with (PASTA / "resultados/resumo.csv").open(encoding="utf-8-sig", newline="") as arquivo:
        return {(r["cenario"], r["modelo"]): r for r in csv.DictReader(arquivo)
                if r["tau_ms"] == "15"}


def grafico(resumo, fontes):
    img = Image.new("RGB", (1560, 950), FUNDO)
    d = ImageDraw.Draw(img)
    t = lambda xy, v, s, **kwargs: texto(d, xy, v, s, fontes=fontes, **kwargs)
    t((52, 40), "Nossa V3 × ZF SACHS CDC", 51, negrito=True)
    t((54, 108), "Mesmo carro, mesmas pistas, Skyhook de 4.000 N·s/m e pneu unilateral", 25, cor=SECUNDARIA)
    for j, (rotulo, cor) in enumerate(zip(ROTULOS, CORES)):
        x = 56 + j * 230
        d.rounded_rectangle((x, 164, x + 20, 184), radius=4, fill=cor)
        t((x + 30, 159), rotulo, 23)
    for i, (cenario, titulo, subtitulo, metrica, unidade, decimais) in enumerate([
        ("lombada", "Lombada", "Aceleração RMS da carroceria", "rms_aceleracao_m_s2", "m/s²", 3),
        ("iso8608", "Pista irregular", "Aceleração RMS da carroceria", "rms_aceleracao_m_s2", "m/s²", 3),
        ("lombada", "Lombada", "Curso máximo da suspensão", "media_curso_max_cm", "cm", 2),
        ("iso8608", "Pista irregular", "Carga dinâmica RMS no pneu", "rms_carga_N", "N", 0),
    ]):
        x, y = 52 + (i % 2) * 739, 214 + (i // 2) * 311
        d.rounded_rectangle((x, y, x + 716, y + 288), radius=18, fill=PAINEL, outline=LINHA, width=2)
        t((x + 25, y + 17), titulo, 28, negrito=True)
        t((x + 25, y + 58), subtitulo, 23, cor=SECUNDARIA)
        valores = [float(resumo[cenario, modelo][metrica]) for modelo in MODELOS]
        for j, (valor, cor) in enumerate(zip(valores, CORES)):
            by = y + 110 + j * 49
            fim = x + 25 + round(515 * valor / max(valores))
            d.rounded_rectangle((x + 25, by, x + 540, by + 28), radius=7, fill=FUNDO)
            d.rounded_rectangle((x + 25, by, fim, by + 28), radius=7, fill=cor)
            t((x + 565, by - 2), f"{numero(valor, decimais)} {unidade}", 22, negrito=True)
    v3 = numero(resumo["iso8608", "V3"]["media_sem_contato_ms"])
    cdc = numero(resumo["iso8608", "CDC"]["media_sem_contato_ms"])
    tempo = f"Na pista irregular, a V3 ficou {v3} ms sem contato por trecho e o CDC {cdc} ms."
    t((54, 842), tempo, 25, negrito=True)
    t((54, 890), "ISO 8608 classe C a 72 km/h, média de cinco trechos de 30 s. Cada painel tem sua própria escala.", 22, cor=SECUNDARIA)
    img.save(PASTA / "comparacao.png", optimize=True)


def sinais(cenario, semente, modelo):
    caminho = PASTA / f"resultados/sinais_{cenario}_{semente}_{modelo}.csv.gz"
    with gzip.open(caminho, "rt", encoding="utf-8-sig") as arq:
        return np.loadtxt(arq, delimiter=",", skiprows=1)


def desenho_suspensao(d, x0, texto_local, serie, tempo, label, cor, velocidade_pista):
    x = x0 + 276
    valores = [np.interp(tempo, serie[:, 0], serie[:, j]) for j in range(1, 7)]
    pista, zs, zu, aceleracao, normal, _ = valores
    escala, chao = 470, 382
    raio = 19
    y_carro = 234 - escala * zs
    # O pneu se deforma até a pista. Na ausência de contato, aparece o vão físico.
    y_roda = chao - raio + escala * 2844.9 / 200000 - escala * zu
    y_pista = chao - escala * pista
    pontos_pista = [(px, chao - escala * np.interp(tempo + (px-x) / velocidade_pista,
                      serie[:, 0], serie[:, 1])) for px in range(x0+12, x0+540, 3)]
    d.polygon(pontos_pista + [(pontos_pista[-1][0], 425), (pontos_pista[0][0], 425)], fill="#E3E9EE")
    d.line(pontos_pista, fill="#516C7C", width=3)
    y_pneu = min(y_roda + raio, y_pista)
    d.line((x, y_carro + 37, x, y_roda), fill="#3B4D5B", width=5)
    mola = [(x-44, y_carro+34)]
    for k in range(1, 13):
        fracao = k / 13
        mola.append((x-44+(-1)**k*11, y_carro+34+fracao*(y_roda-y_carro-34)))
    mola.append((x-44, y_roda))
    d.line(mola, fill=cor, width=4, joint="curve")
    d.line((x-44, y_roda, x+8, y_roda), fill=cor, width=4)
    d.rounded_rectangle((x - 97, y_carro, x + 97, y_carro + 41), radius=8, fill=cor)
    d.ellipse((x - raio, y_roda - raio, x + raio, max(y_roda+3, y_pneu)), fill="#263747")
    d.ellipse((x-6, y_roda-6, x+6, y_roda+6), fill="#EFF4F7")
    texto_local((x0+20, 148), label, 29, cor=cor, negrito=True)
    texto_local((x0+20, 190), f"Aceleração {numero(aceleracao, 2)} m/s²", 19, cor=SECUNDARIA)
    estado = "Sem contato" if normal < .01 else f"Força no pneu {numero(normal, 0)} N"
    texto_local((x0+523, 190), estado, 19, cor="#9B3215" if normal < .01 else SECUNDARIA, anchor="ra")


def tracos(d, t, caixa, dados, tempo, janela, coluna, titulo):
    x1, y1, x2, y2 = caixa
    inicio, fim = janela
    ys = [serie[(serie[:, 0] >= inicio) & (serie[:, 0] <= fim), coluna] for serie in dados]
    minimo = min(0, *(y.min() for y in ys))
    maximo = max(0, *(y.max() for y in ys)) * 1.06
    t((x1, y1-34), titulo, 20, negrito=True)
    for fracao in (0, .5, 1):
        yy = y1 + fracao*(y2-y1)
        d.line((x1, yy, x2, yy), fill=LINHA, width=1)
        rotulo_y = yy-19 if fracao == 1 else yy+1
        t((x1+4, rotulo_y), numero(maximo-fracao*(maximo-minimo), 0), 13, cor=SECUNDARIA)
    for y, cor in zip(ys, CORES[1:]):
        indices = np.linspace(0, len(y)-1, min(len(y), round((x2-x1)*1.4))).astype(int)
        pontos = [(x1+(x2-x1)*i/(len(y)-1), y2-(y2-y1)*(y[i]-minimo)/(maximo-minimo))
                  for i in indices]
        d.line(pontos, fill=cor, width=2)
    cursor = x1 + (x2-x1)*(tempo-inicio)/(fim-inicio)
    d.line((cursor, y1, cursor, y2), fill="#142638", width=2)
    t((x1, y2+8), f"{numero(inicio)} s", 14, cor=SECUNDARIA)
    t((x2, y2+8), f"{numero(fim)} s", 14, cor=SECUNDARIA, anchor="ra")


def cena(caso, eixo_tempo, fontes):
    titulo, subtitulo, dados, janela, velocidade_pista, velocidade_video = caso
    img = Image.new("RGB", (1280, 720), FUNDO)
    d = ImageDraw.Draw(img)
    t = lambda xy, v, s, **kwargs: texto(d, xy, v, s, fontes=fontes, **kwargs)
    t((44, 32), titulo, 42, negrito=True)
    t((46, 85), subtitulo, 22, cor=SECUNDARIA)
    t((1234, 45), f"{numero(eixo_tempo, 2)} s  ·  {numero(velocidade_video, 2)}×",
      21, cor=SECUNDARIA, anchor="ra")
    for x, serie, label, cor in zip((45, 665), dados, ROTULOS[1:], CORES[1:]):
        d.rounded_rectangle((x, 132, x+570, 439), radius=16, fill=PAINEL, outline=LINHA, width=2)
        desenho_suspensao(d, x, t, serie, eixo_tempo, label, cor, velocidade_pista)
    for x, coluna, nome in [(45, 4, "Aceleração da carroceria (m/s²)"),
                            (665, 5, "Força normal no pneu (N)")]:
        d.rounded_rectangle((x, 461, x+570, 668), radius=16, fill=PAINEL, outline=LINHA, width=2)
        tracos(d, t, (x+20, 510, x+548, 635), dados, eixo_tempo, janela, coluna, nome)
    t((47, 686), "Esquema de ¼ de veículo com movimento vertical ampliado. CDC simulado com o Skyhook da V3.",
      17, cor=SECUNDARIA)
    return img


def video(ffmpeg, fontes):
    lombada = tuple(sinais("lombada", 0, m) for m in MODELOS[1:])
    iso = tuple(sinais("iso8608", 5, m) for m in MODELOS[1:])
    sem_contato = np.flatnonzero((iso[0][:, 0] >= 5) & (iso[0][:, 5] == 0))
    assert len(sem_contato), "O recorte ISO precisa mostrar uma perda de contato."
    inicio = max(5, round(iso[0][sem_contato[0], 0] - 1.5, 1))
    casos = [
        ("Lombada de 5 cm", "Resposta à passagem pela mesma lombada", lombada, (.7, 4.3), 230, .5),
        ("Pista irregular", "ISO 8608 classe C a 72 km/h · recorte da semente 5",
         iso, (inicio, inicio+4), 690, .25),
    ]
    fps = 30
    comando = [ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo",
               "-pixel_format", "rgb24", "-video_size", "1280x720", "-framerate", str(fps),
               "-i", "-", "-an", "-c:v", "libx264", "-preset", "fast", "-crf", "21",
               "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(PASTA / "comparacao.mp4")]
    with subprocess.Popen(comando, stdin=subprocess.PIPE) as processo:
        with processo.stdin as video_saida:
            for caso in casos:
                inicio, fim = caso[3]
                for k in range(round((fim-inicio)/caso[5]*fps)):
                    video_saida.write(cena(caso, inicio+k*caso[5]/fps, fontes).tobytes())
            with Image.open(PASTA / "comparacao.png") as resultado:
                cartao = Image.new("RGB", (1280, 720), FUNDO)
                resultado.thumbnail((1280, 720), Image.Resampling.LANCZOS)
                cartao.paste(resultado, ((1280-resultado.width)//2, 0))
                quadro = cartao.tobytes()
                for _ in range(5*fps):
                    video_saida.write(quadro)
        if processo.wait() != 0:
            raise RuntimeError("Falha ao codificar o vídeo.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--fontes", help="Diretório de fontes Segoe UI ou DejaVu Sans")
    parser.add_argument("--so-grafico", action="store_true")
    args = parser.parse_args()
    grafico(ler_resumo(), args.fontes)
    if not args.so_grafico:
        video(args.ffmpeg, args.fontes)

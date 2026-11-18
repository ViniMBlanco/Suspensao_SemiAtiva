import unittest
import numpy as np
from modelo.simular_v3 import REPO, pista_iso, lombada, simular, metricas, selecionar, DT

class Validacao(unittest.TestCase):
    def test_pista_publicada(self):
        ref = np.genfromtxt(REPO / "versoes/v2/resultados/perfil_iso8608_semente1.csv", delimiter=",", names=True)
        t, w = pista_iso(1)
        np.testing.assert_allclose(w, ref["altura_m"], atol=2e-13, rtol=0)
        np.testing.assert_allclose(t, ref["tempo_s"], atol=2e-13, rtol=0)

    def test_equilibrio_passivo(self):
        t = np.arange(101) * DT
        y = simular(t, np.zeros_like(t), 3000, 1500)
        np.testing.assert_allclose(y[:, :6], 0, atol=1e-12)
        self.assertTrue(np.all((y[:, 6] >= 600) & (y[:, 6] <= 2400)))
        self.assertTrue(np.all((y[:, 8] >= 0) & (y[:, 8] <= 12)))

    def test_referencia_lombada(self):
        t, w = lombada()
        p = metricas(t, w, simular(t, w, 3000, 1500), 1, ramo=0)
        self.assertAlmostEqual(p["rms_as_m_s2"], 0.571731596133163, places=7)
        self.assertAlmostEqual(p["rms_carga_N"], 151.000485845282, places=5)

    def test_referencia_iso_cinco_sementes(self):
        ref = np.genfromtxt(REPO / "versoes/v2/resultados/metricas_sementes.csv", delimiter=",", names=True)
        for r in ref:
            semente = int(r["semente"])
            with self.subTest(semente=semente):
                t, w = pista_iso(semente)
                y = simular(t, w, 3000)
                self.assertTrue(np.all(np.isfinite(y)))
                self.assertTrue(np.all((y[:, 6] >= 600) & (y[:, 6] <= 2400)))
                self.assertTrue(np.all((y[:, 8] >= 0) & (y[:, 8] <= 12)))
                self.assertTrue(np.all((y[:, 9] >= 0) & (y[:, 9] <= 1.5)))
                for ramo, sufixo in ((0, "passivo"), (1, "semi")):
                    m = metricas(t, w, y, 5, ramo)
                    for campo, coluna in (("rms_as_m_s2", "rms_as"), ("rms_carga_N", "rms_carga_pneu")):
                        nome = f"{coluna}_{sufixo}" + ("_N" if campo == "rms_carga_N" else "")
                        erro = abs(m[campo] / r[nome] - 1)
                        print(f"Semente {semente} | {sufixo} | {campo} | erro {100*erro:.5f}%")
                        self.assertLess(erro, 0.02 if ramo else 1e-7)
                    self.assertEqual(m["Nmin_N"] > 0, bool(r[f"contato_valido_{sufixo}"]))

    def test_selecao_rejeita_ganho_sem_contato(self):
        def ponto(n, carga, conforto, normal):
            return dict(tipo="semiativa", N_nao_positiva=n, rms_carga_N=carga,
                        rms_as_m_s2=conforto, Nmin_pior_N=normal)
        valido = ponto(0, 800, 1.4, 5)
        invalido = ponto(1, 750, 1.2, -10)
        pior_carga = ponto(0, 900, 1.3, 10)
        self.assertEqual(selecionar([valido, invalido, pior_carga], 802, 1.69),
                         (valido, "contato_e_carga"))
        self.assertEqual(selecionar([invalido], 802, 1.69),
                         (invalido, "exploratorio_maior_N_min"))

    def test_convergencia_dos_cenarios_publicados(self):
        for semente in range(6):
            with self.subTest(semente=semente):
                t, w = pista_iso(semente) if semente else lombada()
                inicio = 5 if semente else 1
                a = metricas(t, w, simular(t,w,8000), inicio)
                t2 = np.arange(2*(len(t)-1)+1)*DT/2
                w2 = np.interp(t2,t,w)
                b = metricas(t2, w2, simular(t2,w2,8000), inicio)
                self.assertEqual(a["Nmin_N"] > 0, b["Nmin_N"] > 0)
                for campo in ("rms_as_m_s2","rms_carga_N","Nmin_N"):
                    erro = abs(a[campo]-b[campo])/abs(a[campo])
                    print(f"Convergência | semente {semente} | {campo} | erro {100*erro:.5f}%")
                    self.assertLess(erro, .001)

if __name__ == "__main__":
    unittest.main(verbosity=2)

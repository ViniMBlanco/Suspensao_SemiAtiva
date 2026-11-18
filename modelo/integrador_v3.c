#include <math.h>

static double limitar(double x, double lo, double hi) {
    return fmin(hi, fmax(lo, x));
}

static void derivada(const double *x, double w, double v, double cp,
                     double tau, double *dx) {
    // Estados: posições e velocidades da passiva e da semiativa, i, c.
    for (int j = 0; j < 8; j += 4) {
        const double c = j == 0 ? cp : x[9];
        const double fs = 16000 * (x[j] - x[j+2]) + c * (x[j+1] - x[j+3]);
        dx[j] = x[j+1];
        dx[j+1] = -fs / 250;
        dx[j+2] = x[j+3];
        dx[j+3] = (fs + 200000 * (w - x[j+2])) / 40;
    }
    dx[8] = (v - 5 * x[8]) / 0.02;
    dx[9] = (limitar(600 + 1200 * x[8], 600, 2400) - x[9]) / tau;
}

void integrar(int n, const double *w, double dt, double ts, double tau,
              double ganho, double cp, double *y) {
    const int subpassos = (int)lround(ts / dt);
    const double fuga = 1.0 / (1.0 + 0.6283185307179586 * ts);
    double x[10] = {0, 0, 0, 0, 0, 0, 0, 0, .75, 1500};
    double vs = 0, vu = 0, integral = 3.75, erro_ant = 0, v = 0, iref = 0;
    double k1[10], k2[10], k3[10], k4[10], aux[10];

    for (int k = 0; k < n; ++k) {
        derivada(x, w[k], v, cp, tau, k1);
        if (k % subpassos == 0) {
            vs = fuga * (vs + ts * k1[5]);
            vu = fuga * (vu + ts * k1[7]);
            const double vr = vs - vu;
            const double produto = vs * vr;
            const double alvo = produto > 0 ?
                limitar(ganho * produto / (vr * vr + .0001), 600, 2400) : 600;
            iref = (alvo - 600) / 1200;
            const double erro = iref - x[8];
            const double inc = k == 0 ? 0 : 1250 * ts * (erro + erro_ant);
            const double u = 10 * erro + integral + inc;
            // Clamping discreto independente; comparar com o bloco do Simulink.
            if (!((u > 12 && erro > 0) || (u < 0 && erro < 0))) integral += inc;
            v = limitar(10 * erro + integral, 0, 12);
            erro_ant = erro;
            derivada(x, w[k], v, cp, tau, k1);
        }
        double *row = y + 10*k;
        row[0] = k1[1]; row[1] = k1[5];
        row[2] = 200000 * (w[k] - x[2]); row[3] = 200000 * (w[k] - x[6]);
        row[4] = x[0]-x[2]; row[5] = x[4]-x[6];
        row[6] = x[9]; row[7] = x[8]; row[8] = v; row[9] = iref;

        if (k + 1 == n) break;
        const double wm = (w[k] + w[k+1]) * .5;
        for (int j = 0; j < 10; ++j) aux[j] = x[j] + .5*dt*k1[j];
        derivada(aux, wm, v, cp, tau, k2);
        for (int j = 0; j < 10; ++j) aux[j] = x[j] + .5*dt*k2[j];
        derivada(aux, wm, v, cp, tau, k3);
        for (int j = 0; j < 10; ++j) aux[j] = x[j] + dt*k3[j];
        derivada(aux, w[k+1], v, cp, tau, k4);
        for (int j = 0; j < 10; ++j)
            x[j] += (dt / 6) * (k1[j] + 2*k2[j] + 2*k3[j] + k4[j]);
    }
}

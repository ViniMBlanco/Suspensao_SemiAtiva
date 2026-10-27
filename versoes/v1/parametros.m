%% Parametros da versao v1
% Valores da apresentacao S1 (versao de 30/09).
% H = hipotese nossa, L = literatura / patente / catalogo (ver README geral).
%
% Uso normal:   rodar_versao('v1')            (pasta modelo/ no path)
% Uso manual:   run('versoes/v1/parametros.m') e depois rodar o modelo

versao = 'v1';

%% Simulacao
dt = 0.5e-3;          % passo fixo do solver ode4 [s]
Ts = 1e-3;            % periodo de amostragem do controlador [s]

%% Planta quarter-car
m_s = 250;            % massa suspensa [kg]                  H
m_u = 40;             % massa nao suspensa [kg]              L Diaz-Choque 2021
k_s = 16000;          % rigidez da mola [N/m]                H (~1,2 Hz)
k_t = 200000;         % rigidez do pneu [N/m]                L Jazar 2014
g   = 9.81;           % gravidade [m/s^2]
c_pass = 1500;        % amortecimento da suspensao passiva [N.s/m]

%% Valvula proporcional
c_min = 600;          % [N.s/m]                              L patente Delphi
c_max = 2400;         % [N.s/m]
K_ci  = 1200;         % ganho corrente -> amortecimento [N.s/m/A]
i_max = (c_max - c_min)/K_ci;   % 1,5 A                      L HydraForce serie 70
tau_v = 0.015;        % constante de tempo da valvula [s]    L Ortiz-Espinoza 2014
c_inicial = 1500;     % amortecimento no instante zero [N.s/m]
i0 = (c_inicial - c_min)/K_ci;  % corrente inicial [A]

%% Bobina (circuito RL) e driver
R = 5.0;              % [ohm]                                L HydraForce, 20 C
L = 0.02;             % [H]                                  H
V_min = 0;            % [V]
V_max = 12;           % [V]                                  L bateria

%% PI de corrente (malha interna, Tustin)
Kp = 10;              % [V/A]       L*omega_i, omega_i = 500 rad/s
Ki = 2500;            % [V/(A.s)]   Kp*R/L: zero do PI cancela o polo da bobina

%% Skyhook (malha externa)
c_sky = 3000;         % ganho skyhook [N.s/m]
v_eps = 0.01;         % evita divisao por zero quando v_rel ~ 0 [m/s]

%% Sensores
usar_sensores = 1;    % 1 = acelerometros + integrador com fuga, 0 = velocidades ideais
f_fuga = 0.1;         % frequencia de corte do integrador com fuga [Hz]
w_fuga = 2*pi*f_fuga;
% integrador com fuga 1/(s + w_fuga) discretizado (Euler para tras), um por acelerometro
A_sd = eye(2)/(1 + w_fuga*Ts);
B_sd = Ts*eye(2)/(1 + w_fuga*Ts);
C_sd = A_sd;
D_sd = B_sd;

%% Matrizes da planta (calculadas, nao mexer)
% estados x = [z_s; v_s; z_u; v_u], entradas u = [F_d; w]
A_p = [ 0         1   0               0;
       -k_s/m_s   0   k_s/m_s         0;
        0         0   0               1;
        k_s/m_u   0  -(k_s + k_t)/m_u 0];
B_p = [ 0        0;
       -1/m_s    0;
        0        0;
        1/m_u    k_t/m_u];
C_p = eye(4);
D_p = zeros(4, 2);

% saidas extras a partir de [x; F_d; w]:
% [a_s; a_u; curso z_s - z_u; forca normal no pneu]
K_ext = [-k_s/m_s   0   k_s/m_s           0   -1/m_s   0;
          k_s/m_u   0  -(k_s + k_t)/m_u   0    1/m_u   k_t/m_u;
          1         0  -1                 0    0       0;
          0         0  -k_t               0    0       k_t];
bias_ext = [0; 0; 0; (m_s + m_u)*g];

K_vrel = [0 1 0 -1];          % v_rel = v_s - v_u
K_v    = [0 1 0 0; 0 0 0 1];  % [v_s; v_u] ideais
K_a    = [eye(2) zeros(2)];   % [a_s; a_u] dos acelerometros

%% Pistas
pistas.lombada = struct('t_final', 8,  't_ini', 1.0, 'duracao', 0.70, 'altura', 0.05);
pistas.senoide = struct('t_final', 15, 'amplitude', 0.10, 'omega', 4.0, 't_metrica', 3.0);
pistas.degrau  = struct('t_final', 8,  't_ini', 1.0, 'altura', 0.03, 't_rampa', 0.02);

% pista usada quando o modelo e rodado direto pelo botao Run
pista_tipo = 'lombada';
addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'modelo'));
[pista, t_final, t_metrica] = gerar_pista(pista_tipo, pistas, dt);

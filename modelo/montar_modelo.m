function montar_modelo()
% MONTAR_MODELO  Cria modelo/suspensao_semiativa.slx bloco a bloco.
%
% Rodar de novo sempre que este arquivo mudar. Os blocos usam so nomes de
% variaveis; os valores vem do parametros.m de cada versao (regra do README).
%
% Estrutura do modelo:
%   Pista -> Planta semiativa <- F_d = c*v_rel <- Valvula <- Bobina RL <- PI <- skyhook
%   Pista -> Planta passiva   <- F_d = c_pass*v_rel   (referencia de comparacao)

mdl = 'suspensao_semiativa';
pasta = fileparts(mfilename('fullpath'));

if bdIsLoaded(mdl)
    close_system(mdl, 0);
end
new_system(mdl);

%% Solver: passo fixo, igual ao RK4 do esboco em Python
set_param(mdl, 'SolverType', 'Fixed-step', 'Solver', 'ode4', 'FixedStep', 'dt', ...
    'StopTime', 't_final', 'ReturnWorkspaceOutputs', 'on', ...
    'ReturnWorkspaceOutputsName', 'out');
try
    set_param(mdl, 'EnableMultiTasking', 'off');
catch
    set_param(mdl, 'SolverMode', 'SingleTasking');
end

%% Pista
bloco(mdl, 'simulink/Sources/From Workspace', 'Pista', em(0, 3), ...
    'VariableName', 'pista', 'Interpolate', 'on', ...
    'OutputAfterFinalValue', 'Holding final value');

%% Planta semiativa e forca do amortecedor
criar_planta(mdl, 'Planta semiativa', em(1, 3, 120, 70));
bloco(mdl, 'simulink/Math Operations/Gain', 'v_rel', em(2, 1), ...
    'Gain', 'K_vrel', 'Multiplication', 'Matrix(K*u)');
bloco(mdl, 'simulink/Math Operations/Product', 'Forca amortecedor', em(1, 1));

%% Sensores e A/D
bloco(mdl, 'simulink/Math Operations/Gain', 'Velocidades ideais', em(2, 3), ...
    'Gain', 'K_v', 'Multiplication', 'Matrix(K*u)');
bloco(mdl, 'simulink/Math Operations/Gain', 'Acelerometros', em(2, 5), ...
    'Gain', 'K_a', 'Multiplication', 'Matrix(K*u)');
bloco(mdl, 'simulink/Discrete/Zero-Order Hold', 'AD velocidades', em(3, 3), ...
    'SampleTime', 'Ts');
bloco(mdl, 'simulink/Discrete/Zero-Order Hold', 'AD acelerometros', em(3, 5), ...
    'SampleTime', 'Ts');
bloco(mdl, 'simulink/Discrete/Discrete State-Space', 'Integrador com fuga', em(4, 5), ...
    'A', 'A_sd', 'B', 'B_sd', 'C', 'C_sd', 'D', 'D_sd', 'SampleTime', 'Ts');
condicao_inicial([mdl '/Integrador com fuga'], 'zeros(2,1)');
bloco(mdl, 'simulink/Sources/Constant', 'Usar sensores', em(4, 4), ...
    'Value', 'usar_sensores');
bloco(mdl, 'simulink/Signal Routing/Switch', 'Sensor ou ideal', em(5, 4), ...
    'Criteria', 'u2 >= Threshold', 'Threshold', '0.5');

%% Malha externa: skyhook e conversao c* -> i_ref
criar_skyhook(mdl, 'Skyhook', em(6, 4, 90, 50));
bloco(mdl, 'simulink/Math Operations/Bias', 'menos c_min', em(7, 4), 'Bias', '-c_min');
bloco(mdl, 'simulink/Math Operations/Gain', 'dividir por K_ci', em(8, 4), 'Gain', '1/K_ci');
bloco(mdl, 'simulink/Discontinuities/Saturation', 'Limite i_ref', em(9, 4), ...
    'UpperLimit', 'i_max', 'LowerLimit', '0');

%% Malha interna: PI de corrente, D/A (ZOH implicito na saida do PI) e bobina
bloco(mdl, 'simulink/Math Operations/Sum', 'Erro corrente', em(10, 4), 'Inputs', '+-');
bloco(mdl, 'simulink/Discrete/Discrete PID Controller', 'PI corrente', em(11, 4, 80, 50));
set_param([mdl '/PI corrente'], 'Controller', 'PI', 'Form', 'Parallel', ...
    'P', 'Kp', 'I', 'Ki', 'SampleTime', 'Ts', 'IntegratorMethod', 'Trapezoidal', ...
    'InitialConditionForIntegrator', 'R*i0', ...
    'LimitOutput', 'on', 'UpperSaturationLimit', 'V_max', 'LowerSaturationLimit', 'V_min', ...
    'AntiWindupMode', 'clamping');
bloco(mdl, 'simulink/Continuous/State-Space', 'Bobina RL', em(12, 4), ...
    'A', '-R/L', 'B', '1/L', 'C', '1', 'D', '0');
condicao_inicial([mdl '/Bobina RL'], 'i0');
bloco(mdl, 'simulink/Discrete/Zero-Order Hold', 'AD corrente', em(11, 6), ...
    'SampleTime', 'Ts');

%% Valvula proporcional: c = sat(c_min + K_ci*i) filtrado por 1a ordem
bloco(mdl, 'simulink/Math Operations/Gain', 'K_ci', em(12, 1), 'Gain', 'K_ci');
bloco(mdl, 'simulink/Math Operations/Bias', 'mais c_min', em(11, 1), 'Bias', 'c_min');
bloco(mdl, 'simulink/Discontinuities/Saturation', 'Limites valvula', em(10, 1), ...
    'UpperLimit', 'c_max', 'LowerLimit', 'c_min');
bloco(mdl, 'simulink/Continuous/State-Space', 'Valvula', em(9, 1), ...
    'A', '-1/tau_v', 'B', '1/tau_v', 'C', '1', 'D', '0');
condicao_inicial([mdl '/Valvula'], 'c_inicial');

%% Planta passiva (referencia)
criar_planta(mdl, 'Planta passiva', em(1, 8, 120, 70));
bloco(mdl, 'simulink/Math Operations/Gain', 'F_d passivo', em(2, 7), ...
    'Gain', 'c_pass*K_vrel', 'Multiplication', 'Matrix(K*u)');

%% Ligacoes
ligar(mdl, 'Pista/1', 'Planta semiativa/2');
ligar(mdl, 'Pista/1', 'Planta passiva/2');

ligar(mdl, 'Planta semiativa/1', 'v_rel/1');
ligar(mdl, 'v_rel/1', 'Forca amortecedor/2');
ligar(mdl, 'Valvula/1', 'Forca amortecedor/1');
ligar(mdl, 'Forca amortecedor/1', 'Planta semiativa/1');

ligar(mdl, 'Planta semiativa/1', 'Velocidades ideais/1');
ligar(mdl, 'Velocidades ideais/1', 'AD velocidades/1');
ligar(mdl, 'Planta semiativa/2', 'Acelerometros/1');
ligar(mdl, 'Acelerometros/1', 'AD acelerometros/1');
ligar(mdl, 'AD acelerometros/1', 'Integrador com fuga/1');
ligar(mdl, 'Integrador com fuga/1', 'Sensor ou ideal/1');
ligar(mdl, 'Usar sensores/1', 'Sensor ou ideal/2');
ligar(mdl, 'AD velocidades/1', 'Sensor ou ideal/3');

ligar(mdl, 'Sensor ou ideal/1', 'Skyhook/1');
ligar(mdl, 'Skyhook/1', 'menos c_min/1');
ligar(mdl, 'menos c_min/1', 'dividir por K_ci/1');
ligar(mdl, 'dividir por K_ci/1', 'Limite i_ref/1');
ligar(mdl, 'Limite i_ref/1', 'Erro corrente/1');
ligar(mdl, 'AD corrente/1', 'Erro corrente/2');
ligar(mdl, 'Erro corrente/1', 'PI corrente/1');
ligar(mdl, 'PI corrente/1', 'Bobina RL/1');
ligar(mdl, 'Bobina RL/1', 'AD corrente/1');

ligar(mdl, 'Bobina RL/1', 'K_ci/1');
ligar(mdl, 'K_ci/1', 'mais c_min/1');
ligar(mdl, 'mais c_min/1', 'Limites valvula/1');
ligar(mdl, 'Limites valvula/1', 'Valvula/1');

ligar(mdl, 'Planta passiva/1', 'F_d passivo/1');
ligar(mdl, 'F_d passivo/1', 'Planta passiva/1');

%% Sinais salvos (ficam em out.<nome> depois do sim)
salvar(mdl, 'Pista/1',            'w_pista',  em(1, 0));
salvar(mdl, 'Planta semiativa/1', 'x_semi',   em(3, 2));
salvar(mdl, 'Planta semiativa/2', 'ext_semi', em(3, 6));
salvar(mdl, 'Skyhook/1',          'c_ref',    em(7, 3));
salvar(mdl, 'Limite i_ref/1',     'i_ref',    em(10, 3));
salvar(mdl, 'PI corrente/1',      'v_cmd',    em(12, 3));
salvar(mdl, 'Bobina RL/1',        'i_bobina', em(13, 4));
salvar(mdl, 'Valvula/1',          'c_efetivo', em(8, 0));
salvar(mdl, 'Planta passiva/1',   'x_pass',   em(3, 8));
salvar(mdl, 'Planta passiva/2',   'ext_pass', em(3, 9));

try
    Simulink.BlockDiagram.arrangeSystem(mdl);
catch
    % versoes antigas do MATLAB nao tem o arrange; fica o layout em grade
end

save_system(mdl, fullfile(pasta, [mdl '.slx']));
open_system(mdl);
fprintf('Modelo salvo em %s\n', fullfile(pasta, [mdl '.slx']));
end


%% ------------------------------------------------------------------------
function criar_planta(sys, nome, pos)
% Quarter-car de 2 GDL. Entradas: F_d, w. Saidas: x = [z_s v_s z_u v_u] e
% ext = [a_s a_u curso N]. As duas saidas sao separadas para nao criar laco
% algebrico (x nao depende direto de F_d; ext depende).
p = [sys '/' nome];
add_block('built-in/Subsystem', p, 'Position', pos);
add_block('simulink/Sources/In1', [p '/F_d'], 'Position', [20 40 50 54]);
add_block('simulink/Sources/In1', [p '/w'], 'Position', [20 120 50 134]);
add_block('simulink/Signal Routing/Mux', [p '/u'], 'Inputs', '2', ...
    'Position', [100 40 105 134]);
add_block('simulink/Continuous/State-Space', [p '/Quarter-car'], ...
    'A', 'A_p', 'B', 'B_p', 'C', 'C_p', 'D', 'D_p', 'Position', [150 65 260 110]);
condicao_inicial([p '/Quarter-car'], 'zeros(4,1)');
add_block('simulink/Signal Routing/Mux', [p '/x_F_w'], 'Inputs', '3', ...
    'Position', [320 150 325 250]);
add_block('simulink/Math Operations/Gain', [p '/Saidas extras'], 'Gain', 'K_ext', ...
    'Multiplication', 'Matrix(K*u)', 'Position', [370 180 450 220]);
add_block('simulink/Math Operations/Bias', [p '/Peso estatico'], 'Bias', 'bias_ext', ...
    'Position', [490 185 540 215]);
add_block('simulink/Sinks/Out1', [p '/x'], 'Position', [600 80 630 94]);
add_block('simulink/Sinks/Out1', [p '/ext'], 'Position', [600 193 630 207]);

ligar(p, 'F_d/1', 'u/1');
ligar(p, 'w/1', 'u/2');
ligar(p, 'u/1', 'Quarter-car/1');
ligar(p, 'Quarter-car/1', 'x/1');
ligar(p, 'Quarter-car/1', 'x_F_w/1');
ligar(p, 'F_d/1', 'x_F_w/2');
ligar(p, 'w/1', 'x_F_w/3');
ligar(p, 'x_F_w/1', 'Saidas extras/1');
ligar(p, 'Saidas extras/1', 'Peso estatico/1');
ligar(p, 'Peso estatico/1', 'ext/1');
end


function criar_skyhook(sys, nome, pos)
% Skyhook classico (Karnopp 1974) com regularizacao perto de v_rel = 0.
p = [sys '/' nome];
add_block('simulink/User-Defined Functions/MATLAB Function', p, 'Position', pos);
codigo = sprintf([ ...
    'function c_ref = skyhook(v, c_sky, c_min, c_max, v_eps)\n' ...
    '%% v = [v_s; v_u] medidos. Saida: amortecimento pedido c*.\n' ...
    'v_s = v(1);\n' ...
    'v_rel = v(1) - v(2);\n' ...
    'if v_s*v_rel <= 0\n' ...
    '    %% amortecedor atrapalharia: fica o mais macio possivel\n' ...
    '    c_ref = c_min;\n' ...
    'else\n' ...
    '    c_ref = c_sky*v_s*v_rel/(v_rel^2 + v_eps^2);\n' ...
    '    c_ref = min(max(c_ref, c_min), c_max);\n' ...
    'end\n']);
ch = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', p);
ch.Script = codigo;
for nome_par = {'c_sky', 'c_min', 'c_max', 'v_eps'}
    d = find(ch, '-isa', 'Stateflow.Data', 'Name', nome_par{1});
    d.Scope = 'Parameter';
end
end


function bloco(sys, lib, nome, pos, varargin)
add_block(lib, [sys '/' nome], 'Position', pos, varargin{:});
end


function ligar(sys, de, para)
add_line(sys, de, para, 'autorouting', 'on');
end


function salvar(sys, sinal, nome, pos)
add_block('simulink/Sinks/To Workspace', [sys '/' nome], 'Position', pos, ...
    'VariableName', nome, 'SaveFormat', 'Timeseries');
ligar(sys, sinal, [nome '/1']);
end


function condicao_inicial(blk, valor)
% o nome do parametro mudou entre versoes do MATLAB
try
    set_param(blk, 'InitialCondition', valor);
catch
    set_param(blk, 'X0', valor);
end
end


function pos = em(col, lin, larg, alt)
% posicao na grade (coluna, linha), so para o modelo nao nascer embolado
if nargin < 3, larg = 70; end
if nargin < 4, alt = 40; end
x = 40 + 160*col;
y = 40 + 90*lin;
pos = [x y x + larg y + alt];
end

function T = rodar_versao(versao, tipos)
% RODAR_VERSAO  Simula uma versao (semiativa x passiva) e salva os resultados.
%   rodar_versao('v1')                  -> lombada, senoide e degrau
%   rodar_versao('v1', {'lombada'})     -> so a lombada
%
% Salva em versoes/<versao>/resultados/: metricas.csv e uma figura por pista.

if nargin < 2
    tipos = {'lombada', 'senoide', 'degrau'};
end

pasta_modelo = fileparts(mfilename('fullpath'));
pasta_versao = fullfile(fileparts(pasta_modelo), 'versoes', versao);
pasta_res = fullfile(pasta_versao, 'resultados');
if ~exist(pasta_res, 'dir')
    mkdir(pasta_res);
end
addpath(pasta_modelo);

mdl = 'suspensao_semiativa';
if ~exist(fullfile(pasta_modelo, [mdl '.slx']), 'file')
    montar_modelo;
end
load_system(fullfile(pasta_modelo, [mdl '.slx']));

% o Simulink procura as variaveis no workspace base
evalin('base', sprintf('run(''%s'');', fullfile(pasta_versao, 'parametros.m')));

linhas = cell(numel(tipos), 1);
for k = 1:numel(tipos)
    tipo = tipos{k};
    evalin('base', sprintf(['pista_tipo = ''%s''; ' ...
        '[pista, t_final, t_metrica] = gerar_pista(pista_tipo, pistas, dt);'], tipo));
    fprintf('Simulando %s / %s...\n', versao, tipo);
    out = sim(mdl);

    m = calcular_metricas(out, evalin('base', 't_metrica'));
    linhas{k} = [table(string(tipo), 'VariableNames', {'pista'}), struct2table(m)];
    if min(m.N_min_semi_N, m.N_min_passivo_N) <= 0
        warning(['%s: forca normal <= 0, o pneu sairia do chao. ' ...
            'O modelo nao simula a separacao pneu-pista.'], tipo);
    end
    plotar(out, versao, tipo, pasta_res);
end

T = vertcat(linhas{:});
writetable(T, fullfile(pasta_res, 'metricas.csv'));
disp(T);
fprintf('Resultados salvos em %s\n', pasta_res);
end


function m = calcular_metricas(out, t0)
% ext = [a_s a_u curso N]; metricas a partir de t0
es = out.ext_semi.Data;
ep = out.ext_pass.Data;
sel = out.ext_semi.Time >= t0;
rms_ = @(x) sqrt(mean(x(sel).^2));

m.rms_as_passivo = rms_(ep(:, 1));
m.rms_as_semi = rms_(es(:, 1));
m.melhora_rms_pct = 100*(1 - m.rms_as_semi/m.rms_as_passivo);
m.pico_as_passivo = max(abs(ep(sel, 1)));
m.pico_as_semi = max(abs(es(sel, 1)));
% aderencia: variacao da forca normal em torno do peso estatico (t = 0)
m.rms_carga_pneu_passivo_N = rms_(ep(:, 4) - ep(1, 4));
m.rms_carga_pneu_semi_N = rms_(es(:, 4) - es(1, 4));
m.curso_max_passivo_cm = 100*max(abs(ep(:, 3)));
m.curso_max_semi_cm = 100*max(abs(es(:, 3)));
m.N_min_passivo_N = min(ep(:, 4));
m.N_min_semi_N = min(es(:, 4));
m.i_max_A = max(out.i_bobina.Data);
m.v_max_V = max(out.v_cmd.Data);
end


function plotar(out, versao, tipo, pasta_res)
fig = figure('Visible', 'off', 'Position', [100 100 900 750]);
tl = tiledlayout(fig, 4, 1, 'TileSpacing', 'compact');
title(tl, sprintf('%s - %s', versao, tipo));

nexttile;
plot(out.w_pista.Time, 100*out.w_pista.Data, 'k');
ylabel('w [cm]'); grid on;

nexttile;
plot(out.ext_pass.Time, out.ext_pass.Data(:, 1), '--', ...
     out.ext_semi.Time, out.ext_semi.Data(:, 1));
ylabel('a_s [m/s^2]'); legend('Passiva', 'Semiativa'); grid on;

nexttile;
stairs(out.c_ref.Time, out.c_ref.Data, ':'); hold on;
plot(out.c_efetivo.Time, out.c_efetivo.Data);
ylabel('c [N.s/m]'); legend('c* pedido', 'c efetivo'); grid on;

nexttile;
stairs(out.i_ref.Time, out.i_ref.Data, ':'); hold on;
plot(out.i_bobina.Time, out.i_bobina.Data);
ylabel('i [A]'); xlabel('t [s]'); legend('i_{ref}', 'i'); grid on;

exportgraphics(fig, fullfile(pasta_res, sprintf('%s_%s.png', versao, tipo)), ...
    'Resolution', 150);
close(fig);
end

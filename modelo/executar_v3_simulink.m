function T = executar_v3_simulink(ganho)
% EXECUTAR_V3_SIMULINK Avalia um ganho Skyhook explícito no modelo oficial da V2.
% T = executar_v3_simulink(ganho);  % ganho em N*s/m
% Requer MATLAB/Simulink e reutiliza o SLX da V2 deste repositório.
% Exporta comparativos, gráficos e verificações em versoes/v3/resultados/simulink.
% N <= 0 é registrado como diagnóstico do pneu bilateral em todos os ensaios.
% O callback original do SLX e carregar_versao escrevem no workspace base.
% Use uma sessão nova do MATLAB ou -batch para isolar esses parâmetros.

validateattributes(ganho, {'numeric'}, {'scalar','real','finite','positive'});
repo = fileparts(fileparts(mfilename('fullpath')));
modelo = 'suspensao_semiativa_v2';
arquivo = fullfile(repo, 'versoes', 'v2', [modelo '.slx']);
assert(isfile(arquivo), 'Modelo Simulink não encontrado em %s.', arquivo);
assert(~isempty(ver('simulink')), 'Esta rotina requer Simulink.');

path_original = path;
restaurar_path = onCleanup(@() path(path_original));
addpath(fullfile(repo, 'modelo'));
if bdIsLoaded(modelo)
    assert(strcmp(get_param(modelo, 'FileName'), arquivo) && ...
        strcmp(get_param(modelo, 'Dirty'), 'off'), ...
        'Feche o modelo homônimo ou abra uma sessão nova para usar o SLX de referência.');
else
    load_system(arquivo);
    fechar_modelo = onCleanup(@() close_system(modelo, 0));
end

v1 = carregar_versao('v1');
v2 = carregar_versao('v2');
p = v2;
p.versao = 'v3';
p.c_sky = double(ganho);
p.pistas.lombada = v1.pistas.lombada;
sementes = 1:5;
linhas = cell(numel(sementes) + 1, 1);
testes = cell(size(linhas));
dados_iso = cell(numel(sementes), 1);
pasta = fullfile(repo, 'versoes', 'v3', 'resultados', 'simulink');

[pista_lombada, ~, inicio_lombada] = gerar_pista('lombada', p.pistas, p.dt);
[lombada, linhas{1}, testes{1}] = ensaio(p, 'lombada', NaN, pista_lombada, inicio_lombada);
ganhos = unique([600 900 1200 1500 2000 2500 3000 4000 6000 8000 p.c_sky]);
passivos = unique([linspace(p.c_min, p.c_max, 10) p.c_pass]);
n_semi = numel(ganhos);
n_pass = numel(passivos);
varredura = cell(numel(sementes), n_semi + n_pass);

for k = sementes
    fprintf('V3 Simulink | pista ISO 8608, semente %d/%d\n', k, numel(sementes));
    p.pistas.iso8608.semente = k;
    [pista, ~, inicio_iso] = gerar_pista('iso8608', p.pistas, p.dt);
    [dados_iso{k}, linhas{k+1}, testes{k+1}] = ensaio(p, 'iso8608', k, pista, inicio_iso);
    for j = 1:n_semi
        q = p;
        q.c_sky = ganhos(j);
        if q.c_sky == p.c_sky
            m = dados_iso{k}.metricas;
        else
            d = simular(q, 'iso8608', pista, inicio_iso);
            m = d.metricas;
        end
        varredura{k,j} = linha_varredura("Semiativa", q.c_sky, k, ...
            m.rms_as_semi, m.rms_carga_pneu_semi_N, m.N_min_semi_N);
    end
    for j = 1:n_pass
        q = p;
        q.c_pass = passivos(j);
        if q.c_pass == p.c_pass
            m = dados_iso{k}.metricas;
        else
            d = simular(q, 'iso8608', pista, inicio_iso);
            m = d.metricas;
        end
        varredura{k,n_semi+j} = linha_varredura("Passiva", q.c_pass, k, ...
            m.rms_as_passivo, m.rms_carga_pneu_passivo_N, m.N_min_passivo_N);
    end
end

T = vertcat(linhas{:});
S = vertcat(varredura{:});
G = medias_varredura(S);
V = vertcat(testes{:});
comparativa = [resumo(T(1,:), "Lombada"); resumo(T(2:end,:), "ISO 8608")];
numerica = comparar_referencias(p, v2, lombada, dados_iso{1}, repo);

if ~isfolder(pasta)
    mkdir(pasta);
end
writetable(T, fullfile(pasta, 'metricas_por_ensaio.csv'));
writetable(comparativa, fullfile(pasta, 'tabela_comparativa.csv'));
writetable(S, fullfile(pasta, 'varredura_por_semente.csv'));
writetable(G, fullfile(pasta, 'varredura_media.csv'));
writetable(V, fullfile(pasta, 'validacao.csv'));
writetable(numerica, fullfile(pasta, 'convergencia_e_referencia.csv'));
salvar_sinais(lombada, fullfile(pasta, 'sinais_lombada.csv'));
for k = sementes
    nome = sprintf('sinais_iso8608_semente%d.csv', k);
    salvar_sinais(dados_iso{k}, fullfile(pasta, nome));
end
grafico_tempo(lombada, 'Lombada de 50 mm', fullfile(pasta, 'lombada.png'));
grafico_tempo(dados_iso{1}, 'ISO 8608 classe C a 72 km/h · semente 1', ...
    fullfile(pasta, 'iso8608_semente1.png'));
grafico_varredura(G, p, fullfile(pasta, 'conforto_aderencia.png'));
fprintf('Resultados calculados pelo Simulink em: %s\n', pasta);
end

function d = simular(p, tipo, pista, inicio)
out = sim(entrada_v2(p, pista));
d = coletar_sinais(out, p, tipo, inicio);
d.metricas = metricas_suspensao(d);
end

function [d, linha, teste] = ensaio(p, tipo, semente, pista, inicio)
d = simular(p, tipo, pista, inicio);
m = d.metricas;
linha = [table(string(tipo), semente, p.c_sky, p.c_pass, d.t_metrica, ...
    'VariableNames', {'cenario','semente','c_sky_Ns_m','c_pass_Ns_m','inicio_rms_s'}), ...
    struct2table(m)];
linha.tempo_N_nao_positivo_passivo_s = trapz(d.t, double(d.N_pass <= 0));
linha.tempo_N_nao_positivo_semi_s = trapz(d.t, double(d.N_semi <= 0));

y = d.y;
peso = (p.m_s + p.m_u) * p.g;
v_rel = y(:,8) - y(:,10);
forca = p.k_s * (y(:,7) - y(:,9)) + y(:,13) .* v_rel;
erro_a = max(abs(y(:,11) + forca / p.m_s));
erro_N = max(abs(d.N_semi - (peso + p.k_t * (y(:,1) - y(:,9)))));
pista_esperada = interp1(pista(:,1), pista(:,2), d.t, 'linear', 'extrap');
erro_pista = max(abs(y(:,1) - pista_esperada));
potencia_min = min(y(:,13) .* v_rel.^2);
assert(all(isfinite(y), 'all') && all(isfinite([d.N_pass; d.N_semi])), ...
    'A simulação gerou sinais não finitos.');
assert(abs(d.t(1)) < 1e-10 && abs(d.t(end) - pista(end,1)) < 1e-10 && ...
    max(abs(diff(d.t) - p.dt)) < 1e-10, 'Malha de tempo diferente da pedida.');
assert(erro_a < 1e-8 && erro_N < 1e-8 && erro_pista < 1e-10, ...
    'Sinais inconsistentes com as equações ou com a pista.');
assert(potencia_min >= -1e-12 && in_range(y(:,12:13), p.c_min, p.c_max, 1e-6), ...
    'Amortecimento fora dos limites ou dissipação negativa.');
assert(in_range(y(:,14), 0, p.i_max, 1e-9) && ...
    in_range(y(:,15), 0, max(p.i0, p.V_max/p.R), 1e-6) && ...
    in_range(y(:,16), p.V_min, p.V_max, 1e-9), ...
    'Comando ou estado elétrico fora dos limites do modelo.');

% N <= 0 sinaliza a limitação física do pneu bilateral e fica no CSV.
teste = table(string(tipo), semente, erro_a, erro_N, erro_pista, potencia_min, ...
    m.contato_valido_passivo, m.contato_valido_semi, ...
    'VariableNames', {'cenario','semente','erro_equacao_a_m_s2','erro_equacao_N_N', ...
    'erro_pista_m','potencia_dissipada_min_W','contato_passivo','contato_semi'});
end

function ok = in_range(valores, minimo, maximo, tolerancia)
ok = all(valores >= minimo - tolerancia & valores <= maximo + tolerancia, 'all');
end

function linha = linha_varredura(tipo, valor, semente, rms_as, rms_carga, Nmin)
assert(all(isfinite([rms_as rms_carga Nmin])), 'Sinais não finitos na varredura.');
linha = table(tipo, valor, semente, rms_as, rms_carga, Nmin, Nmin > 0, ...
    'VariableNames', {'suspensao','coeficiente_Ns_m','semente','rms_a_m_s2', ...
    'rms_carga_N','N_min_N','contato_valido'});
end

function G = medias_varredura(S)
[chave, tipo, coeficiente] = findgroups(S.suspensao, S.coeficiente_Ns_m);
G = table(tipo, coeficiente, splitapply(@mean, S.rms_a_m_s2, chave), ...
    splitapply(@mean, S.rms_carga_N, chave), splitapply(@min, S.N_min_N, chave), ...
    splitapply(@sum, S.contato_valido, chave), ...
    'VariableNames', {'suspensao','coeficiente_Ns_m','rms_a_m_s2','rms_carga_N', ...
    'pior_N_min_N','ensaios_com_contato'});
end

function R = resumo(t, cenario)
R = table(cenario, height(t), t.c_sky_Ns_m(1), t.c_pass_Ns_m(1), ...
    mean(t.rms_as_passivo), mean(t.rms_as_semi), mean(t.melhora_rms_pct), ...
    mean(t.rms_carga_pneu_passivo_N), mean(t.rms_carga_pneu_semi_N), ...
    min(t.N_min_passivo_N), min(t.N_min_semi_N), ...
    sum(t.contato_valido_passivo), sum(t.contato_valido_semi), ...
    'VariableNames', {'cenario','ensaios','c_sky_Ns_m','c_pass_Ns_m', ...
    'media_rms_a_pass_m_s2','media_rms_a_semi_m_s2','melhora_media_por_ensaio_pct', ...
    'media_rms_carga_pass_N','media_rms_carga_semi_N','pior_N_min_pass_N', ...
    'pior_N_min_semi_N','ensaios_contato_pass','ensaios_contato_semi'});
end

function T = comparar_referencias(p, v2, lombada, iso, repo)
[pista, ~, inicio] = gerar_pista('iso8608', v2.pistas, v2.dt);
base = simular(v2, 'iso8608', pista, inicio);
oficial = readtable(fullfile(repo, 'versoes', 'v2', 'resultados', 'metricas_sementes.csv'));
oficial = oficial(oficial.semente == 1,:);
assert(height(oficial) == 1, 'Referência da V2 para a semente 1 ausente ou duplicada.');
T = diferencas("V2 versus CSV publicado", oficial, base.metricas, v2.dt, v2.dt);
p.dt = p.dt / 2;
p.pistas.iso8608.semente = 1;
for d = {lombada, iso}
    original = d{1};
    [pista, ~, inicio] = gerar_pista(original.nome, p.pistas, p.dt);
    fino = simular(p, original.nome, pista, inicio);
    linha = diferencas(string(original.nome) + " com dt/2", ...
        original.metricas, fino.metricas, original.parametros.dt, p.dt);
    T = [T; linha]; %#ok<AGROW>
end
end

function T = diferencas(teste, ref, novo, dt_original, dt_comparacao)
erro_pass = abs(novo.rms_as_passivo / ref.rms_as_passivo - 1);
erro_semi = abs(novo.rms_as_semi / ref.rms_as_semi - 1);
limite = 0.005;
assert(max(erro_pass, erro_semi) < limite, '%s: RMS divergiu em 0,5%% ou mais.', char(teste));
T = table(teste, dt_original, dt_comparacao, erro_pass, erro_semi, limite, ...
    'VariableNames', {'teste','dt_original_s','dt_comparacao_s', ...
    'delta_rel_RMS_passivo','delta_rel_RMS_semi','limite_delta_rel_RMS'});
end

function salvar_sinais(d, arquivo)
sinais = [table(d.t, 'VariableNames', {'tempo_s'}), array2table(d.y, ...
    'VariableNames', d.colunas), table(d.N_pass, d.N_semi, ...
    'VariableNames', {'N_pass_N','N_semi_N'})];
writetable(sinais, arquivo);
end

function grafico_tempo(d, titulo, arquivo)
fig = figure('Visible','off', 'Color','w', 'Position',[100 100 1120 750]);
fechar = onCleanup(@() close(fig));
t = tiledlayout(fig, 3, 1, 'TileSpacing','compact');
title(t, sprintf('%s | Simulink | c_{sky} = %g N·s/m', titulo, d.parametros.c_sky));
ax = nexttile(t);
plot(ax, d.t, 1000*d.y(:,1)); ylabel(ax, 'Pista [mm]'); grid(ax, 'on');
ax = nexttile(t);
plot(ax, d.t, d.y(:,[6 11]), 'LineWidth', 1.15); grid(ax, 'on');
ylabel(ax, 'Aceleração [m/s²]');
legend(ax, {'Passiva','Semiativa'}, 'Location','best');
ax = nexttile(t);
plot(ax, d.t, [d.N_pass d.N_semi], 'LineWidth', 1.15); grid(ax, 'on');
yline(ax, 0, '--k', 'Limiar de contato');
ylabel(ax, 'Força normal [N]'); xlabel(ax, 'Tempo [s]');
exportgraphics(fig, arquivo, 'Resolution',160);
end

function grafico_varredura(G, p, arquivo)
fig = figure('Visible','off', 'Color','w', 'Position',[100 100 1000 650]);
fechar = onCleanup(@() close(fig));
ax = axes(fig);
hold(ax, 'on'); grid(ax, 'on');
for tipo = ["Passiva" "Semiativa"]
    m = G.suspensao == tipo;
    linha = plot(ax, G.rms_carga_N(m), G.rms_a_m_s2(m), '-o', ...
        'DisplayName',tipo, 'LineWidth',1.4);
    sem_contato = m & G.pior_N_min_N <= 0;
    plot(ax, G.rms_carga_N(sem_contato), G.rms_a_m_s2(sem_contato), 'x', ...
        'Color',linha.Color, 'MarkerSize',9, 'LineWidth',1.2, 'HandleVisibility','off');
end
ref = (G.suspensao == "Passiva" & G.coeficiente_Ns_m == p.c_pass) | ...
      (G.suspensao == "Semiativa" & G.coeficiente_Ns_m == p.c_sky);
plot(ax, G.rms_carga_N(ref), G.rms_a_m_s2(ref), 'ks', 'MarkerSize',12, ...
    'DisplayName','Casos da tabela');
plot(ax, NaN, NaN, 'kx', 'DisplayName','N ≤ 0 em pelo menos um trecho');
legend(ax, 'Location','best');
xlabel(ax, 'RMS da carga dinâmica no pneu [N]');
ylabel(ax, 'RMS da aceleração da carroceria [m/s²]');
title(ax, {'Conforto e aderência no Simulink','ISO 8608 classe C a 72 km/h · média de cinco sementes'});
exportgraphics(fig, arquivo, 'Resolution',160);
end

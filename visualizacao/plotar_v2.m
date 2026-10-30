function plotar_v2(dados,pasta)
d=dados(1); t=d.t; y=d.y; m=d.metricas;
f=figure('Visible','off','Position',[50 50 1400 930]);
tiledlayout(3,2,'TileSpacing','compact');
nexttile; plot(t,y(:,[6 11]),'LineWidth',.85); grid on;
xline(d.t_metrica,'k:'); xlabel('Tempo [s]'); ylabel('a_s [m/s^2]');
title('Aceleracao vertical da carroceria - semente 1'); legend('Passiva','Semiativa');
nexttile; plot(t,y(:,[6 11]),'LineWidth',1.1); xlim([10 13]); grid on;
xlabel('Tempo [s]'); ylabel('a_s [m/s^2]'); title('Detalhe da aceleracao');
nexttile; bar([m.rms_as_passivo m.rms_as_semi]);
xticks([1 2]); xticklabels({'Passiva','Semiativa'}); ylabel('RMS a_s [m/s^2]'); grid on;
title(sprintf('RMS 5-30 s: reducao %.2f%%',m.melhora_rms_pct));
nexttile; plot(t,[d.N_pass,d.N_semi]); yline(0,'r:'); grid on;
xlabel('Tempo [s]'); ylabel('Forca normal [N]'); title('Contato do pneu');
nexttile; plot(t,1000*[y(:,2)-y(:,4),y(:,7)-y(:,9)]); grid on;
xlabel('Tempo [s]'); ylabel('Curso [mm]'); title('Curso da suspensao');
nexttile; bar([(arrayfun(@(a)a.metricas.rms_as_passivo,dados))', ...
 (arrayfun(@(a)a.metricas.rms_as_semi,dados))']); grid on;
xlabel('Semente'); ylabel('RMS a_s [m/s^2]'); legend('Passiva','Semiativa');
title('Comparacao pareada - cinco trechos');
titulo='V2 - classe C, 72 km/h, c_{sky}=3000 N s/m; RMS sem ponderacao ISO 2631';
if any(arrayfun(@(a)min(a.N_semi)<=0 || min(a.N_pass)<=0,dados))
 titulo=[titulo ' | N <= 0: limitacao do pneu linear'];
end
sgtitle(titulo);
exportgraphics(f,fullfile(pasta,'comparacao_v2.png'),'Resolution',160);
savefig(f,fullfile(pasta,'comparacao_v2.fig')); close(f);
f=figure('Visible','off','Position',[50 50 1250 780]);
tiledlayout(2,2,'TileSpacing','compact');
nexttile; plot(t,y(:,[12 13])); ylabel('c [N s/m]'); legend('Pedido','Efetivo');
title('Amortecimento'); grid on; xlabel('Tempo [s]');
nexttile; plot(t,y(:,[14 15])); ylabel('Corrente [A]'); legend('Referencia','Bobina');
title('Malha de corrente'); grid on; xlabel('Tempo [s]');
nexttile; plot(t,y(:,16)); ylabel('Tensao [V]'); title('Saida do PI'); grid on; xlabel('Tempo [s]');
nexttile; plot(t,y(:,13).*(y(:,8)-y(:,10)).^2); ylabel('Potencia [W]');
title('Dissipacao mecanica semiativa'); grid on; xlabel('Tempo [s]');
sgtitle('V2 - atuador, controle digital e passividade');
exportgraphics(f,fullfile(pasta,'controle_v2.png'),'Resolution',150);
savefig(f,fullfile(pasta,'controle_v2.fig')); close(f);
end

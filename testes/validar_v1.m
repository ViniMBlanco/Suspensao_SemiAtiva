function resumo = validar_v1(dados)
% Validacao numerica e de invariantes; nao equivale a ensaio experimental.
raiz=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(raiz,'modelo'));
if nargin<1
 a=load(fullfile(raiz,'versoes','v1','resultados','dados_simulacao.mat'),'dados'); dados=a.dados;
end
p=dados(1).parametros; carregar_versao(p.versao);
m='suspensao_semiativa'; load_system(fullfile(raiz,'modelo',[m '.slx']));
pi=unico(m,'PI corrente');
assert(strcmp(get_param(pi,'IntegratorMethod'),'Trapezoidal'));
assert(strcmp(get_param(pi,'AntiWindupMode'),'clamping'));
assert(abs(p.Ki/p.Kp-p.R/p.L)<1e-9,'Sintonia PI inconsistente com RL');
assert(isscalar(find_system(m,'LookUnderMasks','all','BlockType','FromWorkspace')));
resumo=table;
for j=1:numel(dados)
 d=dados(j); y=d.y; t=d.t; h=diff(t);
 assert(all(isfinite(y(:))));
 assert(max(abs(h-p.dt))<1e-10,'Passo do solver');
 assert(all(y(:,12)>=p.c_min-1e-6 & y(:,12)<=p.c_max+1e-6));
 assert(all(y(:,13)>=p.c_min-1e-6 & y(:,13)<=p.c_max+1e-6));
 assert(all(y(:,14)>=-1e-9 & y(:,14)<=p.i_max+1e-9),'Limites da referencia de corrente');
 assert(all(y(:,16)>=p.V_min-1e-9 & y(:,16)<=p.V_max+1e-9));
 assert(all(y(:,15)>=-1e-6 & y(:,15)<=max(p.i0,p.V_max/p.R)+1e-6),'Invariante RL');
 rel=y(:,8)-y(:,10); curso=y(:,7)-y(:,9); F=p.k_s*curso+y(:,13).*rel;
 assert(max(abs(y(:,11)+F/p.m_s))<1e-8,'Sinais da forca na carroceria');
 au=(F-p.k_t*(y(:,9)-y(:,1)))/p.m_u;
 assert(max(abs(au-d.au_semi))<1e-8,'Sinais da forca na roda');
 assert(all(y(:,13).*rel.^2>=-1e-12),'Amortecedor produzindo potencia ativa');
 peso=(p.m_s+p.m_u)*p.g;
 assert(max(abs(d.N_semi-(peso-p.k_t*(y(:,9)-y(:,1)))))<1e-8);
 amostra=abs(t/p.Ts-round(t/p.Ts))<1e-8;
 salto=[0;diff(y(:,16))]; assert(max(abs(salto(~amostra)))<1e-9,'ZOH');
 v=interp1(d.v_controle.Time,d.v_controle.Data,t(amostra),'previous');
 vr=v(:,1)-v(:,2); alvo=p.c_min*ones(size(vr)); ativo=v(:,1).*vr>0;
 alvo(ativo)=p.c_sky*v(ativo,1).*vr(ativo)./(vr(ativo).^2+p.v_eps^2);
 alvo=min(max(alvo,p.c_min),p.c_max);
 assert(max(abs(alvo-y(amostra,12)))<1e-7,'Skyhook regularizado');
 ae=d.a_amostrada.Data; ve=d.v_estimada.Data;
 esperado=zeros(size(ve)); anterior=zeros(2,1);
 for k=1:size(ae,1)
  anterior=p.A_sd*anterior+p.B_sd*ae(k,:)'; esperado(k,:)=anterior';
 end
 assert(max(abs(esperado-ve),[],'all')<1e-8,'Integracao com fuga Euler para tras');
 % Referencia passiva independente: RK4 aplicado diretamente a A e B fechados.
 A=p.A_p+p.B_p(:,1)*(p.c_pass*p.K_vrel); B=p.B_p(:,2); ref=zeros(numel(t),4);
 for k=1:numel(t)-1
  x=ref(k,:)'; hk=h(k); w0=y(k,1); w1=y(k+1,1); wm=(w0+w1)/2;
  a=A*x+B*w0; b=A*(x+hk*a/2)+B*wm; c=A*(x+hk*b/2)+B*wm;
  e=A*(x+hk*c)+B*w1; ref(k+1,:)=(x+hk*(a+2*b+2*c+e)/6)';
 end
 erro=max(abs(ref-y(:,2:5)),[],'all'); assert(erro<1e-6,'Referencia mecanica RK4');
 contato=all(d.N_semi>0) && all(d.N_pass>0);
 linha=table(string(d.nome),erro,contato,max(0,max(y(:,15))-p.i_max), ...
  'VariableNames',{'pista','erro_RK4','contato_positivo','excesso_corrente_A'});
 resumo=[resumo;linha]; %#ok<AGROW>
end
isolados(m,p);
% Conferir convergencia sem alterar o dt da v1 entregue.
ref=dados(strcmp({dados.nome},'lombada'));
if ~isempty(ref)
 [pista,t_final,t0]=gerar_pista('lombada',p.pistas,p.dt/2);
 in=Simulink.SimulationInput(m); in=in.setVariable('dt',p.dt/2);
 in=in.setVariable('pista',pista); in=in.setVariable('t_final',t_final);
 out=sim(in); cfg=p; cfg.dt=p.dt/2; fino=coletar_sinais(out,cfg,'lombada',t0);
 erro=max(abs(interp1(fino.t,fino.y(:,7),ref.t)-ref.y(:,7)));
 assert(erro<2e-4,'Convergencia mecanica dt/2: tolerancia 0.2 mm');
end
% Caminho alternativo de sensores: velocidades ideais, sem integrador estimador.
[pista,t_final]=gerar_pista('lombada',p.pistas,p.dt);
in=Simulink.SimulationInput(m); in=in.setVariable('usar_sensores',0);
in=in.setVariable('pista',pista); in=in.setVariable('t_final',t_final);
o=sim(in); assert(max(abs(o.v_controle.Data-o.v_ideal.Data),[],'all')<1e-10);
pasta=fullfile(raiz,'versoes',p.versao,'resultados');
writetable(resumo,fullfile(pasta,'validacao.csv'));
fid=fopen(fullfile(pasta,'validacao.txt'),'w');
fprintf(fid,'MATLAB %s | %s\n',version,char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
fprintf(fid,'PASSOU: equacoes, dissipacao, limites, ZOH, Skyhook, estimadores e RK4.\n');
fprintf(fid,'PASSOU: RL e valvula analiticos; PI Tustin, antiwindup, corrente; dt/2; sensores ideais.\n');
fprintf(fid,'N <= 0 e sobrecorrente transitoria sao reportados, sem alterar estados artificialmente.\n');
fclose(fid); disp(resumo); disp('VALIDACAO_V1_APROVADA');
end
function b=unico(m,n)
a=find_system(m,'LookUnderMasks','all','FollowLinks','on', ...
 'MatchFilter',@Simulink.match.allVariants,'Name',n);
assert(isscalar(a),'Bloco deve ser unico: %s',n); b=a{1};
end
function isolados(orig,p)
m='ensaios_v1'; if bdIsLoaded(m), close_system(m,0); end
new_system(m); limpeza=onCleanup(@()close_system(m,0));
set_param(m,'Solver','ode4','SolverType','Fixed-step','FixedStep','dt', ...
 'StopTime','0.1','ReturnWorkspaceOutputs','on');
add_block('simulink/Sources/Constant',[m '/V'],'Value','R*i_max');
add_block(unico(orig,'Bobina RL'),[m '/RL']); add_line(m,'V/1','RL/1'); gravar(m,'RL','i');
add_block('simulink/Sources/Constant',[m '/C'],'Value','c_max');
add_block(unico(orig,'Valvula'),[m '/Valvula']); add_line(m,'C/1','Valvula/1'); gravar(m,'Valvula','c');
add_block('simulink/Sources/Step',[m '/E'],'Time','0.005','Before','0.01','After','0.02','SampleTime','Ts');
add_block(unico(orig,'PI corrente'),[m '/PI'],'InitialConditionForIntegrator','0');
add_line(m,'E/1','PI/1'); gravar(m,'PI','u');
o=sim(m);
ex=p.i_max+(p.i0-p.i_max)*exp(-p.R*o.i.Time/p.L);
assert(max(abs(o.i.Data-ex))<1e-5,'RL analitico com condicao inicial');
ex=p.c_max+(p.c_inicial-p.c_max)*exp(-o.c.Time/p.tau_v);
assert(max(abs(o.c.Data-ex))<1e-4,'Valvula analitica com condicao inicial');
sel=o.u.Time<=0.01; tt=o.u.Time(sel); u=o.u.Data(sel); e=0.01+0.01*(tt>=0.005-1e-10);
esperado=p.Kp*diff(e)+p.Ki*p.Ts/2*(e(2:end)+e(1:end-1));
assert(max(abs(diff(u)-esperado))<1e-8,'Recorrencia Tustin');
set_param([m '/E'],'Time','0.2','Before','100','After','-0.1');
set_param(m,'StopTime','0.3'); o=sim(m);
assert(max(o.u.Data)<=p.V_max+1e-9 && min(o.u.Data)>=p.V_min-1e-9);
assert(all(o.u.Data(o.u.Time>=0.201)<p.V_max),'Recuperacao antiwindup');
delete_line(m,'V/1','RL/1'); delete_line(m,'E/1','PI/1'); delete_block([m '/E']);
add_block('simulink/Sources/Constant',[m '/Ref'],'Value','i0');
add_block('simulink/Math Operations/Sum',[m '/Erro'],'Inputs','+-');
add_line(m,'Ref/1','Erro/1'); add_line(m,'RL/1','Erro/2'); add_line(m,'Erro/1','PI/1');
add_line(m,'PI/1','RL/1'); o=sim(m);
assert(abs(o.i.Data(end)-p.i0)<0.01,'Rastreamento de corrente');
end
function gravar(m,src,n)
add_block('simulink/Sinks/To Workspace',[m '/' n],'VariableName',n,'SaveFormat','Timeseries');
add_line(m,[src '/1'],[n '/1']);
end

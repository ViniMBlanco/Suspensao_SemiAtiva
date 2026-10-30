function R=validar_v2(dados,pasta)
% Testes de energia da pista, repetibilidade, fisica e convergencia numerica.
p=dados(1).parametros; a=carregar_versao('v1');
nomes={'m_s','m_u','k_s','k_t','g','c_pass','c_min','c_max','K_ci','i_max', ...
 'tau_v','c_inicial','i0','R','L','V_min','V_max','Kp','Ki','c_sky','v_eps', ...
 'usar_sensores','w_fuga','A_sd','B_sd','C_sd','D_sd','A_p','B_p','C_p','D_p','Ts','dt'};
for k=1:numel(nomes), assert(isequal(p.(nomes{k}),a.(nomes{k})),'Parametro v1 alterado'); end
carregar_versao('v2');
estado=rng; [w,~,~,meta]=gerar_pista('iso8608',p.pistas,p.dt);
assert(isequal(estado,rng),'Gerador alterou o RNG global');
wr=gerar_pista('iso8608',p.pistas,p.dt); assert(isequal(w,wr),'Semente nao reprodutivel');
erro_pista=max(abs(interp1(w(:,1),w(:,2),dados(1).t)-dados(1).y(:,1)));
fprintf('Erro de reproducao da pista na malha de tempo do solver: %.3g m\n',erro_pista);
assert(erro_pista<1e-10,'Pista simulada diferente da gerada');
q=p.pistas.iso8608;
sigma=sqrt(q.Gd0*q.n0^2*(1/q.n_min-1/q.n_max));
assert(abs(sum(meta.A.^2)/2-sigma^2)<1e-15,'Energia integrada incorreta');
assert(abs(sigma-0.0152258)<1e-5);
assert(numel(meta.n)==400 && abs(w(end,1)*q.V-600)<1e-9);
G=meta.A.^2./(2*q.n0^2*(1./meta.bordas(1:end-1)-1./meta.bordas(2:end)));
assert(max(abs(G-q.Gd0))<1e-15,'Densidade espectral alvo');
espectro=readtable(fullfile(pasta,'conferencia_classe_C.csv'));
assert(espectro.Gd0_estimado_media5_m3>=128e-6 && espectro.Gd0_estimado_media5_m3<=512e-6);
assert(abs(espectro.inclinacao_estimada+2)<0.3,'Inclinacao da PSD estimada');
mdl='suspensao_semiativa_v2';
fonte=find_system(mdl,'LookUnderMasks','all','BlockType','FromWorkspace');
assert(isscalar(fonte),'As duas suspensoes devem compartilhar a mesma fonte');
R=table;
for s=1:numel(dados)
 d=dados(s); y=d.y; t=d.t; rel=y(:,8)-y(:,10);
 assert(all(isfinite(y(:))) && all(isfinite(d.N_semi)));
 assert(max(abs(diff(t)-p.dt))<1e-10);
 assert(all(y(:,13)>=p.c_min-1e-6 & y(:,13)<=p.c_max+1e-6));
 assert(all(y(:,12)>=p.c_min-1e-6 & y(:,12)<=p.c_max+1e-6));
 assert(all(y(:,14)>=-1e-9 & y(:,14)<=p.i_max+1e-9),'Referencia de corrente fora do limite');
 assert(all(y(:,15)>=-1e-6 & y(:,15)<=max(p.i0,p.V_max/p.R)+1e-6),'Resposta RL fora do limite fisico');
 assert(all(y(:,16)>=p.V_min-1e-9 & y(:,16)<=p.V_max+1e-9));
 assert(min(y(:,13).*rel.^2)>=-1e-12,'Potencia mecanica ativa');
 F=p.k_s*(y(:,7)-y(:,9))+y(:,13).*rel;
 erro=max(abs(y(:,11)+F/p.m_s)); assert(erro<1e-8);
 assert(max(abs((F+p.k_t*(y(:,1)-y(:,9)))/p.m_u-d.au_semi))<1e-8);
 assert(max(abs(d.N_semi-((p.m_s+p.m_u)*p.g+p.k_t*(y(:,1)-y(:,9)))))<1e-8);
 v=table(s,erro,true,all(d.N_pass>0),all(d.N_semi>0), ...
  'VariableNames',{'semente','erro_equacao_carroceria','passividade','contato_passivo','contato_semi'});
 R=[R;v]; %#ok<AGROW>
end
% Referencia mecanica independente para o ramo passivo, mesmo perfil interpolado.
d=dados(1); y=d.y; t=d.t;
A=p.A_p+p.B_p(:,1)*(p.c_pass*p.K_vrel); B=p.B_p(:,2); ref=zeros(numel(t),4);
for k=1:numel(t)-1
 x=ref(k,:)'; h=t(k+1)-t(k); w0=y(k,1); w1=y(k+1,1); wm=(w0+w1)/2;
 k1=A*x+B*w0; k2=A*(x+h*k1/2)+B*wm; k3=A*(x+h*k2/2)+B*wm;
 k4=A*(x+h*k3)+B*w1; ref(k+1,:)=(x+h*(k1+2*k2+2*k3+k4)/6)';
end
erro_RK4=max(abs(ref-y(:,2:5)),[],'all'); assert(erro_RK4<1e-6);
fprintf('Validando v2 com passo dt/2 e mesmas fases...\n');
pf=p; pf.dt=p.dt/2; wf=gerar_pista('iso8608',pf.pistas,pf.dt);
out=sim(entrada_v2(pf,wf)); fino=coletar_sinais(out,pf,'iso8608',d.t_metrica);
mf=metricas_suspensao(fino); m=d.metricas;
ep=abs(mf.rms_as_passivo/m.rms_as_passivo-1);
es=abs(mf.rms_as_semi/m.rms_as_semi-1);
assert(max(ep,es)<0.005,'RMS variou mais de 0,5%% com dt/2');
convergencia=table(p.dt,pf.dt,erro_RK4,ep,es, ...
 mf.melhora_rms_pct,m.melhora_rms_pct, ...
 'VariableNames',{'dt','dt_fino','erro_RK4','delta_rel_RMS_passivo','delta_rel_RMS_semi', ...
 'melhora_dt_fino_pct','melhora_dt_pct'});
writetable(convergencia,fullfile(pasta,'convergencia_numerica.csv'));
writetable(R,fullfile(pasta,'validacao.csv'));
carregar_versao('v2');
fprintf('V2: testes numericos aprovados. Contato e informado separadamente.\n');
end

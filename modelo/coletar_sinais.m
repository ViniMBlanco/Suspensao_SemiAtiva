function d = coletar_sinais(out,cfg,tipo,t0)
% Eixo comum em dt; sinais digitais usam retencao anterior, nunca interpolacao linear.
d.nome=tipo; d.versao=cfg.versao; d.parametros=cfg; d.visual=cfg.visual; d.t_metrica=t0;
d.t=out.x_semi.Time;
xp=sinal(out.x_pass,d.t); xs=sinal(out.x_semi,d.t);
ep=sinal(out.ext_pass,d.t); es=sinal(out.ext_semi,d.t);
d.y=[sinal(out.w_pista,d.t),xp(:,1:4),ep(:,1),xs(:,1:4),es(:,1), ...
 sinal(out.c_ref,d.t,'previous'),sinal(out.c_efetivo,d.t), ...
 sinal(out.i_ref,d.t,'previous'),sinal(out.i_bobina,d.t),sinal(out.v_cmd,d.t,'previous')];
d.colunas={'w','zs_pass','vs_pass','zu_pass','vu_pass','as_pass', ...
 'zs_semi','vs_semi','zu_semi','vu_semi','as_semi','c_ref','c_efetivo','i_ref','i','v'};
d.N_pass=ep(:,4); d.N_semi=es(:,4);
d.au_pass=ep(:,2); d.au_semi=es(:,2);
d.v_controle=out.v_controle; d.v_estimada=out.v_estimada;
d.a_amostrada=out.a_amostrada; d.v_ideal=out.v_ideal;
end
function y=sinal(ts,t,metodo)
if nargin<3, metodo='linear'; end
y=interp1(ts.Time,squeeze(ts.Data),t,metodo,'extrap');
end

function m = metricas_suspensao(d)
p=d.parametros; y=d.y; t=d.t; sel=t>=d.t_metrica; tt=t(sel);
rms_= @(v) sqrt(trapz(tt,v(sel).^2)/(tt(end)-tt(1)));
m.rms_as_passivo=rms_(y(:,6)); m.rms_as_semi=rms_(y(:,11));
m.melhora_rms_pct=100*(1-m.rms_as_semi/m.rms_as_passivo);
m.pico_as_passivo=max(abs(y(sel,6))); m.pico_as_semi=max(abs(y(sel,11)));
peso=(p.m_s+p.m_u)*p.g;
m.rms_carga_pneu_passivo_N=rms_(d.N_pass-peso);
m.rms_carga_pneu_semi_N=rms_(d.N_semi-peso);
m.curso_max_passivo_cm=100*max(abs(y(:,2)-y(:,4)));
m.curso_max_semi_cm=100*max(abs(y(:,7)-y(:,9)));
m.N_min_passivo_N=min(d.N_pass); m.N_min_semi_N=min(d.N_semi);
m.i_max_A=max(y(:,15)); m.v_max_V=max(y(:,16));
m.rms_deflexao_pneu_passivo_m=rms_(y(:,4)-y(:,1));
m.rms_deflexao_pneu_semi_m=rms_(y(:,9)-y(:,1));
m.rms_erro_corrente_A=rms_(y(:,14)-y(:,15));
m.excesso_corrente_A=max(0,m.i_max_A-p.i_max);
m.contato_valido_passivo=all(d.N_pass>0); m.contato_valido_semi=all(d.N_semi>0);
end

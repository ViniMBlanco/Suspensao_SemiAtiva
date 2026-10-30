function organizar_diagrama(m)
% Agrupamento virtual: preserva as equacoes e expoe as duas malhas completas.
grupo(m,'Estrada',{'Pista','w_pista'});
grupo(m,'Suspensao semiativa',{'Planta semiativa','v_rel','Forca amortecedor','x_semi','ext_semi'});
grupo(m,'Suspensao passiva',{'Planta passiva','F_d passivo','x_pass','ext_pass'});
grupo(m,'Sensores mecanicos',{'Velocidades ideais','Acelerometros','AD velocidades', ...
 'AD acelerometros','Integrador com fuga','Usar sensores','Sensor ou ideal', ...
 'v_controle','v_estimada','a_amostrada','v_ideal'});
grupo(m,'Controle Skyhook',{'Skyhook','c_ref'});
grupo(m,'Conversao c-i',{'menos c_min','dividir por K_ci','Limite i_ref','i_ref'});
grupo(m,'Valvula proporcional',{'K_ci','mais c_min','Limites valvula','Valvula','c_efetivo'});
grupo(m,'Bobina',{'Bobina RL','i_bobina'});
grupo(m,'DA',{'DA ZOH','v_cmd'});
pos(m,'Controle Skyhook',[70 210 215 280]);
pos(m,'Conversao c-i',[275 210 415 280]);
pos(m,'Erro corrente',[465 230 495 260]);
set_param([m '/Erro corrente'],'IconShape','round','Inputs','|+-');
pos(m,'PI corrente',[555 210 700 280]);
pos(m,'DA',[760 210 870 280]);
pos(m,'Bobina',[930 210 1090 280]);
pos(m,'Valvula proporcional',[1150 195 1360 295]);
pos(m,'Suspensao semiativa',[1430 180 1620 315]);
pos(m,'Estrada',[1190 50 1360 105]);
pos(m,'AD corrente',[920 385 1090 435]);
set_param([m '/AD corrente'],'Orientation','left');
pos(m,'Sensores mecanicos',[1190 540 1430 660]);
set_param([m '/Sensores mecanicos'],'Orientation','left');
pos(m,'Suspensao passiva',[1430 790 1620 900]);
icone(m,'Estrada',"disp('w(t)');");
icone(m,'Controle Skyhook',"disp('Skyhook continuo');");
icone(m,'Conversao c-i',"disp('c* -> i_ref');");
icone(m,'DA',"disp('ZOH');");
icone(m,'Bobina',"disp('1/(Ls+R)');");
icone(m,'Valvula proporcional',"text(0.5,0.7,'c_eq = c_min + K_ci i','horizontalAlignment','center'); text(0.5,0.3,'1/(tau_v s+1)','horizontalAlignment','center');");
icone(m,'Suspensao semiativa',"text(0.5,0.65,'Quarter-car 2 GDL','horizontalAlignment','center'); text(0.5,0.3,'Fd = c(t) v_rel','horizontalAlignment','center');");
icone(m,'Suspensao passiva',"text(0.5,0.65,'Quarter-car passivo','horizontalAlignment','center'); text(0.5,0.3,'c = c_pass','horizontalAlignment','center');");
icone(m,'Sensores mecanicos',"text(0.5,0.75,'Acelerometros -> A/D','horizontalAlignment','center'); text(0.5,0.5,'Integradores com fuga','horizontalAlignment','center'); text(0.5,0.25,'ou velocidades ideais','horizontalAlignment','center');");
bs=find_system(m,'SearchDepth',1,'Type','Block');
for k=1:numel(bs)
 if strcmp(bs{k},m), continue; end
 set_param(bs{k},'ShowName','off','FontName','Arial','FontSize','11', ...
  'ForegroundColor','black','BackgroundColor','white','DropShadow','off');
end
% Os ramos sao ortogonais; retornos inferiores ficam separados da atuacao.
ls=find_system(m,'FindAll','on','SearchDepth',1,'Type','line');
Simulink.BlockDiagram.routeLine(ls);
nota(m,'V1 - SUSPENSAO SEMIATIVA EM CASCATA',[70 10 950 40],16);
nota(m,'Mesma perturbacao w(t) para as duas suspensoes',[1180 120 1690 145],11);
nota(m,'Controle externo',[70 300 230 325],11);
nota(m,'Calibracao inversa',[275 300 440 325],11);
nota(m,'PI digital - Tustin',[555 300 740 325],11);
nota(m,'D/A',[780 300 870 325],11);
nota(m,'Bobina RL',[955 300 1100 325],11);
nota(m,'Valvula proporcional',[1160 320 1390 345],11);
nota(m,'Planta mecanica',[1430 340 1640 365],11);
nota(m,'A/D de corrente - Ts = 1 ms',[880 455 1180 480],11);
nota(m,'MALHA INTERNA: corrente medida -> erro do PI',[460 495 1050 520],12);
nota(m,'MALHA EXTERNA: aceleracoes -> estimativa de velocidades -> Skyhook',[70 715 1010 745],12);
nota(m,'REFERENCIA PASSIVA - MESMA ESTRADA',[1100 755 1640 780],12);
nota(m,'Duplo clique nos blocos para ver equacoes, limites e registros.',[70 940 1000 970],11);
set_param(m,'ZoomFactor','FitSystem','PaperOrientation','landscape');
end
function grupo(m,n,nomes)
h=zeros(1,numel(nomes));
for k=1:numel(nomes), h(k)=get_param([m '/' nomes{k}],'Handle'); end
Simulink.BlockDiagram.createSubsystem(h,'Name',n);
Simulink.BlockDiagram.arrangeSystem([m '/' n]);
end
function pos(m,n,p), set_param([m '/' n],'Position',p); end
function icone(m,n,c)
a=Simulink.Mask.create([m '/' n]); a.Display=char(c);
a.IconUnits='normalized'; a.IconOpaque='opaque-with-ports';
set_param([m '/' n],'ShowPortLabels','none');
end
function nota(m,t,p,f)
a=Simulink.Annotation(m,t); a.Position=p; a.FontName='Arial'; a.FontSize=f;
end

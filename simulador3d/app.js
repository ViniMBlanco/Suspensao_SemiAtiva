import {DEFAULTS,CHANNELS,validateConfig} from './physics.js';
import {drawTimeChart,drawCursor,drawSweep} from './charts.js';

const $=s=>document.querySelector(s),$$=s=>[...document.querySelectorAll(s)];
const fmt=(x,d=0)=>Number(x).toLocaleString('pt-BR',{minimumFractionDigits:d,maximumFractionDigits:d});
let config={...DEFAULTS},result=null,scene=null,worker=null,sweepWorker=null,jobId=0,debounce=null;
let time=0,playing=false,page='simulation',lastFrame=0,lastDraw=0,charts=[],sweep=[],sweepHits=[],toastTimer=null;
try{const saved=localStorage.getItem('suspensao-lab-config-v1');if(saved)config=validateConfig(JSON.parse(saved));}catch{config={...DEFAULTS};}

const SPECS={
  c_sky:['Ganho skyhook','c_sky',0,8000,100,'N·s/m',1],
  c_pass:['Amortecimento passivo','c_pass',400,4000,100,'N·s/m',1],
  tau_v:['Resposta da válvula','τ_v',5,80,1,'ms',1000],
  Ts:['Período de amostragem','Ts',.5,10,.5,'ms',1000],
  m_s:['Massa suspensa','m_s',150,500,5,'kg',1],
  m_u:['Massa da roda','m_u',20,80,1,'kg',1],
  k_s:['Rigidez da mola','k_s',8000,40000,500,'N/m',1],
  k_t:['Rigidez do pneu','k_t',100000,350000,5000,'N/m',1],
  c_min:['Amortecimento mínimo','c_min',200,1400,50,'N·s/m',1],
  c_max:['Amortecimento máximo','c_max',1600,4500,50,'N·s/m',1],
  Kp:['Ganho proporcional','Kp',0,30,.5,'V/A',1],
  Ki:['Ganho integral','Ki',0,6000,100,'V/(A·s)',1],
  R:['Resistência da bobina','R',2,10,.1,'Ω',1],
  L:['Indutância da bobina','L',5,80,1,'mH',1000],
  V_max:['Tensão da bateria','V_max',6,16,.5,'V',1],
  K_ci:['Ganho corrente → c','K_ci',600,2400,50,'N·s/(m·A)',1],
  i_max:['Limite da referência','i_max',.5,2.5,.05,'A',1],
  c_inicial:['Amortecimento inicial','c₀',200,4500,50,'N·s/m',1],
  f_fuga:['Fuga do estimador','f_fuga',.01,1,.01,'Hz',1],
  v_eps:['Regularização skyhook','v_eps',.001,.05,.001,'m/s',1],
  speed:['Velocidade','V',10,140,1,'km/h',1],
  duration:['Duração do ensaio','',8,60,1,'s',1],
  height:['Altura','h',.5,10,.1,'cm',100],
  bumpDuration:['Duração da lombada','',.2,1.2,.05,'s',1],
  amplitude:['Amplitude','A',.5,15,.1,'cm',100],
  omega:['Frequência angular','ω',.5,20,.1,'rad/s',1],
  ramp:['Tempo da rampa','',5,100,1,'ms',1000]
};
function numericControl(key){
  const [label,symbol,min,max,step,unit,factor]=SPECS[key],value=Number((config[key]*factor).toPrecision(10));
  const fill=100*(value-min)/(max-min);
  const digits=step<1?Math.min(3,Math.ceil(-Math.log10(step))):0;
  return '<div class="control"><div class="control-top"><label class="control-label" for="range-'+key+'">'+label+' <small>'+symbol+'</small></label><span class="number-wrap"><input id="number-'+key+'" data-key="'+key+'" data-factor="'+factor+'" type="number" min="'+min+'" max="'+max+'" step="'+step+'" value="'+value+'" aria-label="'+label+'"><small>'+unit+'</small></span></div><input id="range-'+key+'" data-key="'+key+'" data-factor="'+factor+'" type="range" min="'+min+'" max="'+max+'" step="'+step+'" value="'+value+'" style="--fill:'+fill+'%" aria-label="'+label+'"><div class="range-ends"><span>'+fmt(min,digits)+'</span><span>'+fmt(max,digits)+'</span></div></div>';
}
function drawControls(){
  let road='';
  if(config.track==='iso8608')road+='<div class="inline-fields"><div class="small-field"><label for="road-class">Classe ISO 8608</label><select id="road-class">'+['A','B','C','D'].map(c=>'<option '+(config.roadClass===c?'selected':'')+'>'+c+'</option>').join('')+'</select></div><div class="small-field"><label for="road-seed">Semente</label><input id="road-seed" type="number" min="1" max="9999" step="1" value="'+config.seed+'"></div></div>'+numericControl('speed');
  if(config.track==='lombada')road+=numericControl('height')+numericControl('bumpDuration');
  if(config.track==='degrau')road+=numericControl('height')+numericControl('ramp');
  if(config.track==='senoide')road+=numericControl('amplitude')+numericControl('omega');
  road+=numericControl('duration');$('#road-controls').innerHTML=road;
  const groups=[
    ['02','CONTROLE SEMIATIVO',['c_sky','c_pass','tau_v','Ts'],true,'O ganho skyhook busca reduzir a vibração da carroceria. Observe também a carga no pneu.'],
    ['03','VEÍCULO E SUSPENSÃO',['m_s','m_u','k_s','k_t','c_min','c_max'],false,'Massas e rigidez definem as frequências naturais do conjunto.'],
    ['04','BOBINA E PI DE CORRENTE',['Kp','Ki','R','L','V_max','K_ci','i_max','c_inicial'],false,'A corrente de referência e a tensão são limitadas. O estado da bobina mantém sua dinâmica física.'],
    ['05','SENSORES E INTEGRAÇÃO',['f_fuga','v_eps'],false,'O controlador usa velocidades estimadas a partir dos acelerômetros, como no modelo original.']
  ];
  $('#parameter-groups').innerHTML=groups.map(([num,title,keys,open,help])=>'<details class="param-group" '+(open?'open':'')+'><summary><span>'+num+'</span>'+title+'</summary><p class="helper">'+help+'</p>'+keys.map(numericControl).join('')+(num==='05'?'<label class="select-control" for="sensor-mode">Velocidades<select id="sensor-mode"><option value="1" '+(config.usar_sensores?'selected':'')+'>Acelerômetros + fuga</option><option value="0" '+(!config.usar_sensores?'selected':'')+'>Ideais</option></select></label><label class="select-control" for="solver-step">Passo RK4<select id="solver-step"><option value="0.0005" '+(config.dt===.0005?'selected':'')+'>0,5 ms · padrão</option><option value="0.00025" '+(config.dt===.00025?'selected':'')+'>0,25 ms · refinado</option></select></label>':'')+'</details>').join('');
  $('#preset').value=config.track;
  $$('[data-track]').forEach(el=>el.classList.toggle('selected',el.dataset.track===config.track));
}
function toast(message){clearTimeout(toastTimer);$('#toast').textContent=message;$('#toast').hidden=false;toastTimer=setTimeout(()=>$('#toast').hidden=true,6500);}
function status(message,kind=''){const el=$('#compute-state');el.className=kind;el.innerHTML='<i class="status-dot"></i>';el.append(document.createTextNode(message));}
function setPlaying(value){
  playing=value;$('#play-icon').innerHTML=playing?'<path d="M6 4h3v12H6zm5 0h3v12h-3z" fill="currentColor"/>':'<path d="m7 4 9 6-9 6Z" fill="currentColor"/>';
  $('#play').setAttribute('aria-label',playing?'Pausar simulação':'Reproduzir simulação');
}
function stopSweep(){
  sweepWorker?.terminate();sweepWorker=null;sweep=[];sweepHits=[];
  $('#run-sweep').disabled=false;$('#export-sweep').disabled=true;
  $('#sweep-state').textContent='20 ensaios com a configuração do painel';
  $('#sweep-table tbody').innerHTML='';drawSweep($('#sweep-chart'),[]);
}
function schedule(){
  clearTimeout(debounce);worker?.terminate();worker=null;setPlaying(false);jobId++;
  $('#play').disabled=true;$('#export-csv').disabled=true;
  if(result)$('#metric-window').textContent='RESULTADOS ANTERIORES · RECALCULANDO';
  status('Parâmetros alterados · recalculando','busy');stopSweep();
  debounce=setTimeout(compute,350);
}
function commit(key,value){
  const next={...config,[key]:value};
  try{
    config=validateConfig(next);
    for(const normalizedKey of new Set([key,'c_inicial'])){
      const input=$('#range-'+normalizedKey),number=$('#number-'+normalizedKey);
      if(input&&number){
        const display=Number((config[normalizedKey]*Number(input.dataset.factor)).toPrecision(10));
        input.value=display;number.value=display;input.style.setProperty('--fill',100*(display-input.min)/(input.max-input.min)+'%');
      }
    }
    schedule();return true;
  }catch(e){toast(e.message);return false;}
}
function chooseTrack(track,reset=false){
  config=reset?{...DEFAULTS,track}:{...config,track};
  const changes={iso8608:{duration:30},lombada:{duration:8,height:.05},senoide:{duration:15,amplitude:.1,omega:4},degrau:{duration:8,height:.03,ramp:.02},plana:{duration:8}};
  Object.assign(config,changes[track]);drawControls();schedule();
}
function compute(){
  const id=++jobId,start=performance.now();status('Calculando pista e respostas…','busy');
  try{config=validateConfig(config);}catch(e){status('Configuração inválida','error');toast(e.message);return;}
  worker=new Worker(new URL('./worker.js',import.meta.url),{type:'module'});
  worker.onerror=()=>{status('Não foi possível iniciar o cálculo','error');toast('Reinicie pelo arquivo SIMULAR_3D.py para carregar o simulador por HTTP.');};
  worker.onmessage=({data})=>{
    if(data.id!==jobId)return;
    if(data.type==='error'){status('Ajuste a configuração','error');if(result)$('#metric-window').textContent='RESULTADOS ANTERIORES · CONFIGURAÇÃO INVÁLIDA';toast(data.message);worker?.terminate();worker=null;return;}
    if(data.type!=='result')return;
    result=data.result;time=0;scene?.setResult(result);$('#timeline').max=result.config.duration;$('#timeline').value=0;
    $('#play').disabled=false;$('#export-csv').disabled=false;
    try{localStorage.setItem('suspensao-lab-config-v1',JSON.stringify(Object.fromEntries(Object.keys(DEFAULTS).map(k=>[k,config[k]]))));}catch{}
    renderResults();prepareCharts();status('Ensaio calculado · '+fmt((performance.now()-start)/1000,2)+' s');
    worker?.terminate();worker=null;setPlaying(true);
  };
  worker.postMessage({id,type:'simulate',config});
}
function comparison(value,type=''){
  return '<span class="comparison '+type+'">'+value+'</span>';
}
function renderResults(){
  const {metrics:m,config:p,t0}=result;
  const relative=(semi,pass)=>pass>1e-12?100*(semi/pass-1):0;
  const acceleration=m.improvement>=0?fmt(m.improvement,1)+'% menos vibração':fmt(-m.improvement,1)+'% mais vibração';
  const loadChange=relative(m.semi.load,m.pass.load),courseChange=relative(m.semi.course,m.pass.course);
  const cards=[
    ['ACELERAÇÃO RMS',fmt(m.semi.rms,3),'m/s²','Passiva: '+fmt(m.pass.rms,3)+' m/s²',comparison(acceleration,m.improvement<0?'bad':'')],
    ['CARGA DINÂMICA RMS',fmt(m.semi.load,1),'N','Passiva: '+fmt(m.pass.load,1)+' N',comparison(fmt(Math.abs(loadChange),1)+'% '+(loadChange>0?'mais carga':'menos carga'),loadChange>0?'bad':'')],
    ['CURSO MÁXIMO',fmt(1000*m.semi.course,1),'mm','Passiva: '+fmt(1000*m.pass.course,1)+' mm',comparison(fmt(Math.abs(courseChange),1)+'% '+(courseChange>0?'mais curso':'menos curso'),courseChange>0?'bad':'')],
    ['FORÇA NORMAL MÍNIMA',fmt(m.semi.minNormal),'N','Passiva: '+fmt(m.pass.minNormal)+' N',comparison(m.semi.minNormal<=0?'Contato inválido no modelo':'Contato positivo',m.semi.minNormal<=0?'bad':'')]
  ];
  $('#metrics').innerHTML=cards.map(([title,value,unit,note,badge])=>'<article class="metric"><span>'+title+'</span><strong>'+value+'<small>'+unit+'</small></strong><p>'+note+'</p>'+badge+'</article>').join('');
  $('#metric-window').textContent='ENSAIO COMPLETO · '+fmt(t0)+'–'+fmt(p.duration)+' s';
  $('#tag-pass-value').textContent='c = '+fmt(p.c_pass)+' N·s/m';
  const names={iso8608:'ISO 8608 · CLASSE '+p.roadClass+' · '+fmt(p.speed)+' km/h',lombada:'LOMBADA · '+fmt(100*p.height,1)+' cm · '+fmt(p.bumpDuration,2)+' s',senoide:'SENOIDE · '+fmt(100*p.amplitude,1)+' cm · '+fmt(p.omega,1)+' rad/s',degrau:'DEGRAU · '+fmt(100*p.height,1)+' cm · RAMPA '+fmt(1000*p.ramp)+' ms',plana:'PISTA PLANA · EQUILÍBRIO ESTÁTICO'};
  $('#road-caption').textContent=names[p.track];
  let notices=[];
  if(m.semi.minNormal<=0||m.pass.minNormal<=0){
    const who=[];if(m.pass.minNormal<=0)who.push('passiva em '+fmt(m.pass.firstLoss,3)+' s');if(m.semi.minNormal<=0)who.push('semiativa em '+fmt(m.semi.firstLoss,3)+' s');
    notices.push('<strong>Limite físico do modelo:</strong> N ≤ 0 na '+who.join(' e na ')+'. O pneu linear não representa voo e recontato; as métricas desse ensaio têm validade física limitada.');
  }
  if(m.maxCurrent>p.i_max+.0005)notices.push('A corrente real atingiu '+fmt(m.maxCurrent,3)+' A, acima da referência limitada a '+fmt(p.i_max,2)+' A.');
  if(p.track!=='iso8608'&&p.track!=='plana')notices.push('Perfil definido no tempo, como na v1. A velocidade de deslocamento da pista 3D é apenas ilustrativa.');
  $('#physics-notice').hidden=!notices.length;$('#physics-notice').innerHTML=notices.join(' ');
}
function prepareCharts(){
  charts=[];if(!result||page!=='simulation')return;
  const d=result.data,duration=result.config.duration;
  const specs=[['acc-chart',[{values:d.as_pass},{values:d.as_semi}],true],['normal-chart',[{values:d.N_pass},{values:d.N_semi}],true],
    ['damping-chart',[{values:d.c_ref},{values:d.c_efetivo}],false],['current-chart',[{values:d.i_ref},{values:d.i}],false],
    ['voltage-chart',[{values:d.v,color:'#ff965e'}],true],['road-chart',[{values:d.w,factor:1000,color:'#ff965e'}],true]];
  for(const [id,series,zero] of specs){const chart=drawTimeChart($('#'+id),series,duration,zero);if(chart)charts.push(chart);}
  charts.forEach(c=>drawCursor(c,time));
}
function updateLive(){
  if(!result)return;const {data:d,config:p}=result,idx=Math.min(d.t.length-1,Math.floor(time/p.dt));
  $('#live-damping').innerHTML=fmt(d.c_efetivo[idx])+' <small>N·s/m</small>';
  $('#damping-bar').style.width=(100*(d.c_efetivo[idx]-p.c_min)/(p.c_max-p.c_min))+'%';
  $('#live-current').innerHTML=fmt(d.i[idx],2)+' <small>A</small>';$('#live-voltage').textContent=fmt(d.v[idx],1)+' V aplicados';
  $('#live-normal').innerHTML=fmt(d.N_semi[idx])+' <small>N</small>';
  $('#live-normal').style.color=d.N_semi[idx]<=0?'#f3a17a':'';
  $('#live-contact').textContent=d.N_semi[idx]<=0?'N ≤ 0 · fora da hipótese de contato':'Contato positivo no instante';
  $('#time-label').innerHTML=fmt(time,2)+' <span>/ '+fmt(p.duration,2)+' s</span>';
  $('#timeline').value=time;$('#timeline').style.setProperty('--fill',(100*time/p.duration)+'%');
  charts.forEach(c=>drawCursor(c,time));
}
function download(name,content,type='text/plain;charset=utf-8'){
  const url=URL.createObjectURL(new Blob([content],{type})),a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
}
function exportCSV(){
  if(!result)return;const rows=[CHANNELS.join(',')],d=result.data;
  for(let j=0;j<d.t.length;j++)rows.push(CHANNELS.map(k=>d[k][j].toPrecision(12)).join(','));
  download('suspensao_'+result.config.track+'_sinais_SI.csv',rows.join('\n'),'text/csv;charset=utf-8');
}
function startSweep(){
  if(sweepWorker)return;
  try{validateConfig(config);}catch(e){toast(e.message);return;}
  setPlaying(false);sweep=[];sweepHits=[];$('#run-sweep').disabled=true;$('#export-sweep').disabled=true;
  $('#sweep-state').textContent='Preparando os 20 ensaios…';sweepWorker=new Worker(new URL('./worker.js',import.meta.url),{type:'module'});
  sweepWorker.onmessage=({data})=>{
    if(data.type==='progress')$('#sweep-state').textContent=data.completed+' / '+data.total+' ensaios calculados';
    if(data.type==='error'){toast(data.message);$('#sweep-state').textContent='Configuração instável na varredura.';$('#run-sweep').disabled=false;sweepWorker.terminate();sweepWorker=null;}
    if(data.type==='sweep'){
      sweep=data.points;$('#run-sweep').disabled=false;$('#export-sweep').disabled=false;$('#sweep-state').textContent='20 ensaios concluídos · semente '+config.seed;
      sweepHits=drawSweep($('#sweep-chart'),sweep);
      $('#sweep-table tbody').innerHTML=sweep.map((p,i)=>'<tr data-index="'+i+'"><td>'+(p.kind==='semi'?'Semiativa':'Passiva')+'</td><td>'+fmt(p.gain)+'</td><td>'+fmt(p.rms,4)+'</td><td>'+fmt(p.load,2)+'</td><td>'+fmt(p.minNormal,1)+'</td><td class="'+(p.minNormal>0?'good-cell':'loss-cell')+'">'+(p.minNormal>0?'Positivo':'N ≤ 0')+'</td></tr>').join('');
      sweepWorker.terminate();sweepWorker=null;
    }
  };
  sweepWorker.onerror=()=>{toast('Falha ao executar a varredura.');$('#run-sweep').disabled=false;sweepWorker?.terminate();sweepWorker=null;};
  sweepWorker.postMessage({id:0,type:'sweep',config});
}
function applyPoint(index){
  const point=sweep[index];if(!point)return;
  const key=point.kind==='semi'?'c_sky':'c_pass';config[key]=point.gain;drawControls();showPage('simulation');schedule();toast((point.kind==='semi'?'Ganho skyhook':'Amortecimento passivo')+' aplicado: '+fmt(point.gain)+' N·s/m.');
}
function showPage(name){
  page=name;$$('[data-page]').forEach(el=>el.classList.toggle('active',el.dataset.page===name));
  $$('.page').forEach(el=>el.hidden=el.id!=='page-'+name);
  requestAnimationFrame(()=>{if(name==='simulation'){scene?.resize();prepareCharts();}if(name==='analysis')sweepHits=drawSweep($('#sweep-chart'),sweep);});
}
$('.sidebar').addEventListener('input',e=>{
  const el=e.target;if(!el.dataset.key||el.type!=='range')return;
  const key=el.dataset.key,value=Number(el.value),factor=Number(el.dataset.factor);
  $('#number-'+key).value=value;el.style.setProperty('--fill',100*(value-Number(el.min))/(Number(el.max)-Number(el.min))+'%');
  if(!commit(key,value/factor)){
    const previous=config[key]*factor;el.value=previous;$('#number-'+key).value=previous;
    el.style.setProperty('--fill',100*(previous-Number(el.min))/(Number(el.max)-Number(el.min))+'%');
  }
});
$('.sidebar').addEventListener('change',e=>{
  const el=e.target;
  if(el.dataset.key&&el.type==='number'){
    const key=el.dataset.key;if(!el.checkValidity()){toast('Valor fora da faixa permitida.');el.value=config[key]*Number(el.dataset.factor);return;}
    if(commit(key,Number(el.value)/Number(el.dataset.factor))){const range=$('#range-'+key);range.value=el.value;range.style.setProperty('--fill',100*(el.value-range.min)/(range.max-range.min)+'%');}
    else el.value=config[key]*Number(el.dataset.factor);
  }
  if(el.id==='road-class')commit('roadClass',el.value);
  if(el.id==='road-seed'){if(!commit('seed',Number(el.value)))el.value=config.seed;}
  if(el.id==='sensor-mode')commit('usar_sensores',Number(el.value));
  if(el.id==='solver-step')commit('dt',Number(el.value));
});
$$('[data-track]').forEach(el=>el.addEventListener('click',()=>chooseTrack(el.dataset.track)));
$('#preset').addEventListener('change',e=>chooseTrack(e.target.value,true));
$('#reset-config').addEventListener('click',()=>{config={...DEFAULTS};drawControls();schedule();toast('Parâmetros originais da v2 restaurados.');});
$$('[data-page]').forEach(el=>el.addEventListener('click',()=>showPage(el.dataset.page)));
$('#play').addEventListener('click',()=>{if(result&&time>=result.config.duration)time=0;setPlaying(!playing);});
$('#restart').addEventListener('click',()=>{time=0;setPlaying(Boolean(result));updateLive();});
$('#timeline').addEventListener('input',e=>{setPlaying(false);time=Number(e.target.value);updateLive();});
$('#camera-reset').addEventListener('click',()=>scene?.resetCamera());
$('#labels-toggle').addEventListener('click',()=>{if(scene){scene.labels=!scene.labels;$('#labels-toggle').classList.toggle('on',scene.labels);}});
$('#visual-scale').addEventListener('change',e=>{if(scene)scene.scale=Number(e.target.value);});
$('#fullscreen').addEventListener('click',async()=>{try{if(document.fullscreenElement)await document.exitFullscreen();else await $('.viewer-card').requestFullscreen();}catch{toast('A tela cheia não está disponível neste navegador.');}});
$('#export-csv').addEventListener('click',exportCSV);
$('#save-config').addEventListener('click',()=>download('suspensao_configuracao.json',JSON.stringify({schema:1,config:Object.fromEntries(Object.keys(DEFAULTS).map(k=>[k,config[k]]))},null,2),'application/json'));
$('#load-config').addEventListener('click',()=>$('#config-file').click());
$('#config-file').addEventListener('change',async e=>{
  const file=e.target.files[0];if(!file)return;
  try{
    if(file.size>100000)throw new Error('Arquivo de configuração muito grande.');
    const parsed=JSON.parse(await file.text());if(parsed.schema!==1||!parsed.config)throw new Error('Formato de configuração não reconhecido.');
    for(const key of Object.keys(parsed.config))if(!Object.hasOwn(DEFAULTS,key))throw new Error('Parâmetro desconhecido: '+key);
    config=validateConfig(parsed.config);drawControls();schedule();toast('Configuração importada.');
  }catch(e){toast(e.message);}finally{$('#config-file').value='';}
});
$('#run-sweep').addEventListener('click',startSweep);
$('#sweep-table tbody').addEventListener('click',e=>{const row=e.target.closest('tr[data-index]');if(row)applyPoint(Number(row.dataset.index));});
$('#sweep-chart').addEventListener('click',e=>{
  const rect=e.target.getBoundingClientRect(),x=e.clientX-rect.left,y=e.clientY-rect.top;
  let best=null,distance=Infinity;for(const p of sweepHits){const dist=Math.hypot(p.x-x,p.y-y);if(dist<distance){best=p;distance=dist;}}
  if(best&&distance<20)applyPoint(best.index);
});
$('#export-sweep').addEventListener('click',()=>{
  const keys=['kind','gain','rms','load','minNormal','course','loss'];download('suspensao_varredura_SI.csv',[keys.join(','),...sweep.map(p=>keys.map(k=>p[k]).join(','))].join('\n'),'text/csv;charset=utf-8');
});
$('.actuator-details').addEventListener('toggle',prepareCharts);
let resizeTimer;window.addEventListener('resize',()=>{clearTimeout(resizeTimer);resizeTimer=setTimeout(()=>{prepareCharts();if(page==='analysis')sweepHits=drawSweep($('#sweep-chart'),sweep);},150);});
document.addEventListener('visibilitychange',()=>{if(document.hidden)setPlaying(false);lastFrame=performance.now();});
window.addEventListener('beforeunload',()=>{worker?.terminate();sweepWorker?.terminate();scene?.dispose();});
function frame(now){
  const delta=lastFrame?Math.min((now-lastFrame)/1000,.1):0;lastFrame=now;
  if(playing&&result){time=Math.min(result.config.duration,time+delta*Number($('#play-speed').value));if(time>=result.config.duration)setPlaying(false);}
  if(now-lastDraw>1000/30&&page==='simulation'){
    scene?.render(time);updateLive();lastDraw=now;
  }
  requestAnimationFrame(frame);
}
drawControls();compute();requestAnimationFrame(frame);
(async()=>{
  try{const {SuspensionScene}=await import('./scene.js');scene=new SuspensionScene($('#viewport'));$('#labels-toggle').classList.toggle('on',scene.labels);if(result)scene.setResult(result);scene.render(time);$('#loading-view').hidden=true;}
  catch(error){console.error(error);const el=$('#loading-view');el.className='loading-view error-view';el.textContent='Não foi possível iniciar o WebGL 3D. Ative a aceleração gráfica e use Chrome, Edge ou Firefox atualizado. O cálculo e os gráficos continuam disponíveis.';}
})();
window.suspensionLab={
  getConfig:()=>({...config}),getResult:()=>result,getScene:()=>scene,
  setConfig:value=>{config=validateConfig({...config,...value});drawControls();schedule();},
  setTime:value=>{setPlaying(false);time=Math.max(0,Math.min(result?.config.duration||30,value));updateLive();},
  isReady:()=>Boolean(result),getSweep:()=>sweep
};


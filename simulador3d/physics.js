/** Modelo do repositório: 2 GDL + PI Tustin + RL + válvula, SI internamente. */
export const DEFAULTS = Object.freeze({
  m_s:250,m_u:40,k_s:16000,k_t:200000,g:9.81,c_pass:1500,
  c_min:600,c_max:2400,K_ci:1200,i_max:1.5,c_inicial:1500,
  tau_v:0.015,R:5,L:0.02,V_max:12,Kp:10,Ki:2500,
  c_sky:3000,v_eps:0.01,usar_sensores:1,f_fuga:0.1,Ts:0.001,dt:0.0005,
  track:'iso8608',roadClass:'C',speed:72,seed:1,duration:30,
  height:0.05,bumpDuration:0.7,amplitude:0.1,omega:4,ramp:0.02,
});
export const LIMITS = Object.freeze({
  m_s:[150,500],m_u:[20,80],k_s:[8000,40000],k_t:[100000,350000],g:[9.81,9.81],
  c_pass:[400,4000],c_min:[200,1400],c_max:[1600,4500],K_ci:[600,2400],
  i_max:[0.5,2.5],c_inicial:[200,4500],tau_v:[0.005,0.08],R:[2,10],L:[0.005,0.08],
  V_max:[6,16],Kp:[0,30],Ki:[0,6000],c_sky:[0,8000],v_eps:[0.001,0.05],
  usar_sensores:[0,1],f_fuga:[0.01,1],Ts:[0.0005,0.01],dt:[0.00025,0.0005],
  speed:[10,140],seed:[1,9999],duration:[8,60],height:[0.005,0.1],
  bumpDuration:[0.2,1.2],amplitude:[0.005,0.15],omega:[0.5,20],ramp:[0.005,0.1],
});
export const CHANNELS = ['t','w','zs_pass','vs_pass','zu_pass','vu_pass','as_pass',
  'zs_semi','vs_semi','zu_semi','vu_semi','as_semi','c_ref','c_efetivo','i_ref',
  'i','v','N_pass','N_semi','au_pass','au_semi','v_est_s','v_est_u'];
export const CLASS_GD = Object.freeze({A:16e-6,B:64e-6,C:256e-6,D:1024e-6});
const clamp=(x,a,b)=>Math.min(b,Math.max(a,x));

export function validateConfig(input={}) {
  const p={...DEFAULTS,...input};
  for(const [key,[lo,hi]] of Object.entries(LIMITS)) {
    if(typeof p[key]!=='number'||!Number.isFinite(p[key])||p[key]<lo-1e-12||p[key]>hi+1e-12)
      throw new Error(`Parâmetro ${key}: informe um valor entre ${lo} e ${hi}.`);
  }
  if(!['iso8608','lombada','senoide','degrau','plana'].includes(p.track)) throw new Error('Pista desconhecida.');
  if(!Object.hasOwn(CLASS_GD,p.roadClass)) throw new Error('Classe de pista inválida.');
  if(!Number.isInteger(p.seed)) throw new Error('A semente deve ser um inteiro.');
  if(![0,1].includes(p.usar_sensores)) throw new Error('Seleção de sensores inválida.');
  if(![0.00025,0.0005].includes(p.dt)) throw new Error('Use passo de 0,25 ou 0,5 ms.');
  if(Math.abs(p.Ts/p.dt-Math.round(p.Ts/p.dt))>1e-8) throw new Error('Ts deve ser múltiplo do passo de integração.');
  if(p.c_max<=p.c_min) throw new Error('c máximo deve ser maior que c mínimo.');
  p.c_inicial=clamp(p.c_inicial,p.c_min,p.c_max);
  // Limita-se a referência e o mapa da válvula; nunca o estado da bobina.
  p.i0=(p.c_inicial-p.c_min)/p.K_ci;
  if(p.i0>p.V_max/p.R) throw new Error('O amortecimento inicial exige mais corrente que V/R. Reduza c inicial.');
  return p;
}

/** MT19937 + uniforme de 53 bits, como RandStream mt19937ar (sementes >= 1). */
export class MT19937 {
  constructor(seed) {
    this.mt=new Uint32Array(624);this.index=624;this.mt[0]=seed>>>0;
    for(let i=1;i<624;i++) this.mt[i]=(Math.imul(1812433253,this.mt[i-1]^(this.mt[i-1]>>>30))+i)>>>0;
  }
  uint32() {
    if(this.index>=624) {
      for(let i=0;i<624;i++) {
        const y=(this.mt[i]&0x80000000)|(this.mt[(i+1)%624]&0x7fffffff);
        this.mt[i]=this.mt[(i+397)%624]^(y>>>1)^((y&1)?0x9908b0df:0);
      }
      this.index=0;
    }
    let y=this.mt[this.index++];
    y^=y>>>11;y^=(y<<7)&0x9d2c5680;y^=(y<<15)&0xefc60000;y^=y>>>18;
    return y>>>0;
  }
  random(){return ((this.uint32()>>>5)*67108864+(this.uint32()>>>6))/9007199254740992;}
}

export function generateRoad(p) {
  const count=Math.round(p.duration/p.dt)+1,w=new Float64Array(count);
  let sigma=0;
  if(p.track==='iso8608') {
    const rng=new MT19937(p.seed),G=CLASS_GD[p.roadClass],N=400,lo=0.011,hi=2.83;
    for(let k=0;k<N;k++) {
      const left=lo*(hi/lo)**(k/N),right=lo*(hi/lo)**((k+1)/N),n=Math.sqrt(left*right);
      const A=Math.sqrt(2*G*0.1**2*(1/left-1/right)),phase=2*Math.PI*rng.random();
      // Rotação recorrente: evita 24 milhões de chamadas trigonométricas.
      const step=2*Math.PI*n*(p.speed/3.6)*p.dt,cs=Math.cos(step),sn=Math.sin(step);
      let c=Math.cos(phase),s=Math.sin(phase);
      for(let j=0;j<count;j++) {w[j]+=A*c;const nc=c*cs-s*sn;s=s*cs+c*sn;c=nc;}
    }
    const origin=w[0];for(let j=0;j<count;j++) w[j]-=origin;
    sigma=Math.sqrt(G*0.1**2*(1/lo-1/hi));
  } else {
    for(let j=0;j<count;j++) {
      const t=j*p.dt;
      if(p.track==='lombada') {const f=(t-1)/p.bumpDuration;w[j]=f>=0&&f<=1?0.5*p.height*(1-Math.cos(2*Math.PI*f)):0;}
      else if(p.track==='degrau') w[j]=p.height*clamp((t-1)/p.ramp,0,1);
      else if(p.track==='senoide') w[j]=p.amplitude*Math.sin(p.omega*t);
    }
  }
  return {w,sigma};
}

export function skyhook(vs,vu,p) {
  const rel=vs-vu;
  return vs*rel<=0?p.c_min:clamp(p.c_sky*vs*rel/(rel*rel+p.v_eps*p.v_eps),p.c_min,p.c_max);
}

export function derivative(x,w,voltage,p,out=new Float64Array(10)) {
  const Fs=p.k_s*(x[0]-x[2])+x[9]*(x[1]-x[3]);
  const Fp=p.k_s*(x[4]-x[6])+p.c_pass*(x[5]-x[7]);
  out[0]=x[1];out[1]=-Fs/p.m_s;out[2]=x[3];out[3]=(Fs+p.k_t*(w-x[2]))/p.m_u;
  out[4]=x[5];out[5]=-Fp/p.m_s;out[6]=x[7];out[7]=(Fp+p.k_t*(w-x[6]))/p.m_u;
  out[8]=(voltage-p.R*x[8])/p.L;
  out[9]=(clamp(p.c_min+p.K_ci*x[8],p.c_min,p.c_max)-x[9])/p.tau_v;
  return out;
}

export function simulate(input,road=null) {
  const p=validateConfig(input),profile=road||generateRoad(p),w=profile.w;
  const data=Object.fromEntries(CHANNELS.map(k=>[k,new Float64Array(w.length)]));
  const x=new Float64Array(10),tmp=new Float64Array(10),k1=new Float64Array(10),k2=new Float64Array(10),k3=new Float64Array(10),k4=new Float64Array(10);
  x[8]=p.i0;x[9]=p.c_inicial;
  const h=p.dt,sampleEvery=Math.round(p.Ts/h),weight=(p.m_s+p.m_u)*p.g;
  let integral=p.R*p.i0,voltage=p.R*p.i0,estimatedS=0,estimatedU=0,cref=p.c_min,iref=0;
  const leak=1/(1+2*Math.PI*p.f_fuga*p.Ts);
  for(let j=0;j<w.length;j++) {
    const F=p.k_s*(x[0]-x[2])+x[9]*(x[1]-x[3]),as=-F/p.m_s,au=(F+p.k_t*(w[j]-x[2]))/p.m_u;
    const Fp=p.k_s*(x[4]-x[6])+p.c_pass*(x[5]-x[7]),ap=-Fp/p.m_s;
    if(j%sampleEvery===0) {
      estimatedS=leak*(estimatedS+p.Ts*as);estimatedU=leak*(estimatedU+p.Ts*au);
      cref=skyhook(p.usar_sensores?estimatedS:x[1],p.usar_sensores?estimatedU:x[3],p);
      iref=clamp((cref-p.c_min)/p.K_ci,0,p.i_max);
      const error=iref-x[8];
      // Estado do integrador trapezoidal: saída usa meia amostra atual;
      // clamping suspende integração apenas quando ela aumenta a saturação.
      const half=p.Ki*p.Ts/2,raw=p.Kp*error+integral+half*error;
      const blocked=(raw>p.V_max&&error>0)||(raw<0&&error<0);
      voltage=clamp(raw,0,p.V_max);
      if(!blocked) integral+=p.Ki*p.Ts*error;
    }
    const values=[j*h,w[j],x[4],x[5],x[6],x[7],ap,x[0],x[1],x[2],x[3],as,cref,x[9],iref,x[8],voltage,
      weight+p.k_t*(w[j]-x[6]),weight+p.k_t*(w[j]-x[2]),(Fp+p.k_t*(w[j]-x[6]))/p.m_u,au,estimatedS,estimatedU];
    for(let c=0;c<CHANNELS.length;c++) data[CHANNELS[c]][j]=values[c];
    if(!Number.isFinite(as)||Math.abs(x[0])>50||!Number.isFinite(x[8])) throw new Error('Configuração instável. Reduza os ganhos do PI ou o período de amostragem.');
    if(j===w.length-1) break;
    const wm=(w[j]+w[j+1])/2;
    derivative(x,w[j],voltage,p,k1);
    for(let n=0;n<10;n++) tmp[n]=x[n]+h*k1[n]/2;
    derivative(tmp,wm,voltage,p,k2);
    for(let n=0;n<10;n++) tmp[n]=x[n]+h*k2[n]/2;
    derivative(tmp,wm,voltage,p,k3);
    for(let n=0;n<10;n++) tmp[n]=x[n]+h*k3[n];
    derivative(tmp,w[j+1],voltage,p,k4);
    for(let n=0;n<10;n++) x[n]+=h*(k1[n]+2*k2[n]+2*k3[n]+k4[n])/6;
  }
  const t0=p.track==='iso8608'?5:p.track==='senoide'?3:p.track==='plana'?0:1;
  const metrics=calculateMetrics(data,p,t0);
  return {config:p,data,metrics,t0,sigma:profile.sigma};
}

export function calculateMetrics(d,p,t0) {
  const start=Math.ceil(t0/p.dt-1e-8),last=d.t.length-1,span=d.t[last]-d.t[start],weight=(p.m_s+p.m_u)*p.g;
  const rms=(a,offset=0)=>{let sum=0;for(let j=start;j<last;j++) sum+=((a[j]-offset)**2+(a[j+1]-offset)**2)*p.dt/2;return Math.sqrt(sum/span);};
  const branch=(suffix)=>{
    const semi=suffix==='semi',acc=d[semi?'as_semi':'as_pass'],normal=d[semi?'N_semi':'N_pass'];
    const zs=d[semi?'zs_semi':'zs_pass'],zu=d[semi?'zu_semi':'zu_pass'];
    let course=0,minNormal=Infinity,peak=0,loss=0,firstLoss=null;
    for(let j=0;j<=last;j++) {
      course=Math.max(course,Math.abs(zs[j]-zu[j]));minNormal=Math.min(minNormal,normal[j]);
      if(j>=start) peak=Math.max(peak,Math.abs(acc[j]));
      if(normal[j]<=0&&firstLoss===null) firstLoss=d.t[j];
      if(j<last) loss+=((normal[j]<=0?1:0)+(normal[j+1]<=0?1:0))*p.dt/2;
    }
    const load=rms(normal,weight);
    return {rms:rms(acc),load,dlc:load/weight,course,minNormal,peak,loss,firstLoss};
  };
  const pass=branch('pass'),semi=branch('semi');
  let maxCurrent=0,minPower=Infinity;
  for(let j=0;j<=last;j++) {maxCurrent=Math.max(maxCurrent,d.i[j]);minPower=Math.min(minPower,d.c_efetivo[j]*(d.vs_semi[j]-d.vu_semi[j])**2);}
  return {pass,semi,improvement:pass.rms>1e-12?100*(1-semi.rms/pass.rms):0,maxCurrent,minPower,weight};
}

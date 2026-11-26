const COLORS=['#96a8bc','#ff965e'];
export function drawTimeChart(canvas,series,duration,zero=false){
  const width=canvas.clientWidth,height=canvas.clientHeight;
  if(width<10||height<10)return null;
  const ratio=Math.min(devicePixelRatio,2),base=document.createElement('canvas');
  base.width=canvas.width=Math.round(width*ratio);base.height=canvas.height=Math.round(height*ratio);
  const ctx=base.getContext('2d');ctx.scale(ratio,ratio);
  const pad={left:38,right:8,top:12,bottom:22},pw=width-pad.left-pad.right,ph=height-pad.top-pad.bottom;
  let min=Infinity,max=-Infinity;
  for(const s of series)for(let j=0;j<s.values.length;j++){const v=s.values[j]*(s.factor||1);if(v<min)min=v;if(v>max)max=v;}
  if(zero){min=Math.min(0,min);max=Math.max(0,max);}
  if(max-min<1e-9){min-=1;max+=1;}
  const margin=(max-min)*.12;min-=margin;max+=margin;
  const py=v=>pad.top+ph*(max-v)/(max-min);
  ctx.font='9px "Segoe UI",Arial';ctx.textAlign='right';ctx.fillStyle='#6f818e';ctx.lineWidth=.6;
  for(let j=0;j<=3;j++){
    const value=min+(max-min)*j/3,y=py(value);ctx.strokeStyle='#35414a80';ctx.beginPath();ctx.moveTo(pad.left,y);ctx.lineTo(width-pad.right,y);ctx.stroke();
    ctx.fillText(Math.abs(value)>=100?Math.round(value).toString():value.toFixed(Math.abs(value)<1?2:1),pad.left-7,y+3);
  }
  ctx.textAlign='center';
  for(let j=0;j<=5;j++){const x=pad.left+pw*j/5;ctx.fillText((duration*j/5).toFixed(0),x,height-5);}
  if(zero&&min<0&&max>0){ctx.strokeStyle='#bc927263';ctx.setLineDash([3,3]);ctx.beginPath();ctx.moveTo(pad.left,py(0));ctx.lineTo(width-pad.right,py(0));ctx.stroke();ctx.setLineDash([]);}
  series.forEach((s,index)=>{
    const values=s.values,factor=s.factor||1,bins=Math.max(1,Math.floor(pw)),count=values.length;
    ctx.strokeStyle=s.color||COLORS[index%2];ctx.lineWidth=index?1.25:1;ctx.globalAlpha=index?.95:.72;
    ctx.beginPath();
    // Envelope por pixel: preserva os picos ao reduzir os dados para a tela.
    for(let b=0;b<bins;b++){
      const start=Math.floor(b*count/bins),end=Math.max(start+1,Math.floor((b+1)*count/bins));let lo=Infinity,hi=-Infinity,ilo=start,ihi=start;
      for(let n=start;n<end;n++){if(values[n]<lo){lo=values[n];ilo=n;}if(values[n]>hi){hi=values[n];ihi=n;}}
      const x=pad.left+b*pw/bins,a=ilo<ihi?lo:hi,z=ilo<ihi?hi:lo;
      if(!b)ctx.moveTo(x,py(a*factor));else ctx.lineTo(x,py(a*factor));ctx.lineTo(x,py(z*factor));
    }
    ctx.stroke();ctx.globalAlpha=1;
  });
  return {canvas,base,pad,pw,height,width,duration,ratio};
}
export function drawCursor(chart,time){
  if(!chart)return;const {canvas,base,ratio,pad,pw,height,duration}=chart,ctx=canvas.getContext('2d');
  ctx.setTransform(1,0,0,1,0,0);ctx.clearRect(0,0,canvas.width,canvas.height);ctx.drawImage(base,0,0);ctx.scale(ratio,ratio);
  const x=pad.left+pw*time/duration;ctx.strokeStyle='#dce4ea70';ctx.lineWidth=.7;ctx.setLineDash([2,3]);ctx.beginPath();ctx.moveTo(x,pad.top);ctx.lineTo(x,height-pad.bottom);ctx.stroke();ctx.setLineDash([]);
}
export function drawSweep(canvas,points){
  const width=canvas.clientWidth,height=canvas.clientHeight;if(width<10)return [];
  const ratio=Math.min(devicePixelRatio,2);canvas.width=width*ratio;canvas.height=height*ratio;
  const ctx=canvas.getContext('2d');ctx.scale(ratio,ratio);
  const pad={l:55,r:30,t:25,b:50},pw=width-pad.l-pad.r,ph=height-pad.t-pad.b;
  if(!points.length){ctx.fillStyle='#697d8b';ctx.font='12px "Segoe UI"';ctx.textAlign='center';ctx.fillText('Execute a varredura para explorar as curvas.',width/2,height/2);return [];}
  let xmin=Infinity,xmax=-Infinity,ymin=Infinity,ymax=-Infinity;
  for(const p of points){xmin=Math.min(xmin,p.load);xmax=Math.max(xmax,p.load);ymin=Math.min(ymin,p.rms);ymax=Math.max(ymax,p.rms);}
  const dx=Math.max(xmax-xmin,1),dy=Math.max(ymax-ymin,.1);xmin-=dx*.12;xmax+=dx*.12;ymin=Math.max(0,ymin-dy*.18);ymax+=dy*.18;
  const x=v=>pad.l+(v-xmin)/(xmax-xmin)*pw,y=v=>pad.t+(ymax-v)/(ymax-ymin)*ph;
  ctx.font='10px "Segoe UI",Arial';ctx.strokeStyle='#34414c';ctx.fillStyle='#8395a3';ctx.lineWidth=.6;
  for(let k=0;k<=4;k++){
    const xx=pad.l+pw*k/4,yy=pad.t+ph*k/4;
    ctx.beginPath();ctx.moveTo(xx,pad.t);ctx.lineTo(xx,pad.t+ph);ctx.moveTo(pad.l,yy);ctx.lineTo(pad.l+pw,yy);ctx.stroke();
    ctx.textAlign='center';ctx.fillText(Math.round(xmin+(xmax-xmin)*k/4),xx,height-29);
    ctx.textAlign='right';ctx.fillText((ymax-(ymax-ymin)*k/4).toFixed(2),pad.l-9,yy+4);
  }
  ctx.textAlign='center';ctx.fillText('RMS da carga dinâmica no pneu (N) →',pad.l+pw/2,height-8);
  ctx.save();ctx.translate(12,pad.t+ph/2);ctx.rotate(-Math.PI/2);ctx.fillText('RMS da aceleração (m/s²) →',0,0);ctx.restore();
  for(const kind of ['pass','semi']){
    ctx.strokeStyle=kind==='semi'?COLORS[1]:COLORS[0];ctx.lineWidth=1.5;ctx.beginPath();
    points.filter(p=>p.kind===kind).forEach((p,i)=>{if(i)ctx.lineTo(x(p.load),y(p.rms));else ctx.moveTo(x(p.load),y(p.rms));});ctx.stroke();
  }
  return points.map((p,index)=>{
    const px=x(p.load),py=y(p.rms);ctx.strokeStyle=p.kind==='semi'?COLORS[1]:COLORS[0];ctx.fillStyle=ctx.strokeStyle;ctx.lineWidth=1.6;
    if(p.minNormal<=0){ctx.beginPath();ctx.moveTo(px-4,py-4);ctx.lineTo(px+4,py+4);ctx.moveTo(px+4,py-4);ctx.lineTo(px-4,py+4);ctx.stroke();}
    else{ctx.beginPath();ctx.arc(px,py,3.5,0,Math.PI*2);ctx.fill();}
    ctx.font='8px "Segoe UI"';ctx.textAlign='left';ctx.fillText(p.gain,px+6,py-7);
    return {x:px,y:py,index};
  });
}


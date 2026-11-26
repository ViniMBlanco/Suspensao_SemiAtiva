import {simulate,generateRoad,validateConfig} from './physics.js';
self.onmessage=({data:{id,type,config}})=>{
  try {
    if(type==='sweep') {
      const p=validateConfig(config),road=generateRoad(p),points=[];
      const gains=[600,900,1200,1500,2000,2500,3000,4000,6000,8000];
      for(let k=0;k<20;k++) {
        const kind=k<10?'semi':'pass',gain=k<10?gains[k]:600+(k-10)*200;
        const result=simulate({...p,...(kind==='semi'?{c_sky:gain}:{c_pass:gain})},road);
        points.push({kind,gain,...result.metrics[kind]});
        self.postMessage({id,type:'progress',completed:k+1,total:20});
      }
      self.postMessage({id,type:'sweep',points});
    } else {
      const result=simulate(config);
      self.postMessage({id,type:'result',result},Object.values(result.data).map(a=>a.buffer));
    }
  } catch(error) {self.postMessage({id,type:'error',message:error.message});}
};

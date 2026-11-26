import * as THREE from 'three';
import {OrbitControls} from './vendor/OrbitControls.js';
import {RoomEnvironment} from './vendor/RoomEnvironment.js';

const UP=new THREE.Vector3(0,1,0),TAU=2*Math.PI;
const metal=(color,roughness=0.28,metalness=0.85)=>new THREE.MeshStandardMaterial({color,roughness,metalness});

function asphaltTexture(){
  const canvas=document.createElement('canvas');canvas.width=canvas.height=256;
  const ctx=canvas.getContext('2d'),im=ctx.createImageData(256,256);let rng=37;
  for(let i=0;i<im.data.length;i+=4){rng=(Math.imul(rng,1664525)+1013904223)>>>0;const g=48+(rng>>>26);im.data[i]=g*.93;im.data[i+1]=g;im.data[i+2]=g*1.06;im.data[i+3]=255;}
  ctx.putImageData(im,0,0);const tex=new THREE.CanvasTexture(canvas);tex.wrapS=tex.wrapT=THREE.RepeatWrapping;tex.repeat.set(3,35);tex.colorSpace=THREE.SRGBColorSpace;return tex;
}
function mesh(geo,mat,parent,x=0,y=0,z=0){
  const obj=new THREE.Mesh(geo,mat);obj.position.set(x,y,z);obj.castShadow=true;obj.receiveShadow=true;parent.add(obj);return obj;
}
function box(parent,size,mat,pos=[0,0,0]){
  return mesh(new THREE.BoxGeometry(...size),mat,parent,...pos);
}
function cylinder(parent,radius,length,mat,pos=[0,0,0]){
  return mesh(new THREE.CylinderGeometry(radius,radius,length,32),mat,parent,...pos);
}
function connect(obj,a,b){
  obj.position.copy(a).add(b).multiplyScalar(.5);obj.scale.y=a.distanceTo(b);obj.quaternion.setFromUnitVectors(UP,new THREE.Vector3().subVectors(b,a).normalize());
}
function torus(parent,radius,tube,mat,pos=[0,0,0]){
  const obj=mesh(new THREE.TorusGeometry(radius,tube,10,72),mat,parent,...pos);obj.rotation.y=Math.PI/2;return obj;
}

function createCorner(scene,x,color){
  const group=new THREE.Group();group.position.x=x;scene.add(group);
  const steel=metal('#c1c8ce',.24,.95),dark=metal('#303a42',.31),black=metal('#141a20',.53,.48);
  const paint=new THREE.MeshPhysicalMaterial({color,roughness:.26,metalness:.55,clearcoat:1,clearcoatRoughness:.17});
  const rubber=new THREE.MeshStandardMaterial({color:'#101317',roughness:.92,metalness:0});
  const body=new THREE.Group(),hub=new THREE.Group();group.add(body,hub);
  // Chassi seccionado, torres, travessas e flange do amortecedor.
  box(body,[.92,.12,1.34],paint,[-.27,0,0]);
  box(body,[.75,.06,1.48],dark,[-.30,-.1,0]);
  box(body,[.1,.27,1.36],steel,[-.66,-.15,0]);
  box(body,[.1,.12,1.35],steel,[.08,-.12,0]);
  box(body,[.72,.08,.1],dark,[-.3,-.31,-.5]);
  box(body,[.72,.08,.1],dark,[-.3,-.31,.5]);
  const tower=cylinder(body,.19,.09,dark,[-.07,-.1,0]);tower.rotation.z=.12;
  cylinder(body,.12,.035,steel,[-.07,.075,0]);
  cylinder(body,.046,.05,black,[-.07,.11,0]);
  for(const z of [-.52,.52])for(const xx of [-.53,.04])cylinder(body,.021,.018,steel,[xx,.07,z]);
  // Seção de para-lama na face interna: abertura circular e pintura automotiva.
  const shape=new THREE.Shape();
  shape.moveTo(-.92,-.62);shape.lineTo(-.92,-.02);shape.quadraticCurveTo(-.85,.18,-.5,.18);
  shape.lineTo(.55,.18);shape.quadraticCurveTo(.86,.18,.92,-.02);shape.lineTo(.92,-.62);shape.lineTo(.48,-.62);
  shape.absarc(0,-.62,.48,0,Math.PI,false);shape.lineTo(-.92,-.62);
  const fender=mesh(new THREE.ExtrudeGeometry(shape,{depth:.045,bevelEnabled:true,bevelSegments:3,steps:1,bevelSize:.018,bevelThickness:.012}),paint,body,-.62,-.13,0);
  fender.rotation.y=Math.PI/2;
  // Pneu com perfil arredondado e banda de rodagem geométrica.
  const points=[[.218,-.124],[.29,-.14],[.35,-.118],[.371,-.079],[.378,-.035],[.378,.035],[.371,.079],[.35,.118],[.29,.14],[.218,.124],[.218,-.124]].map(v=>new THREE.Vector2(...v));
  const tire=mesh(new THREE.LatheGeometry(points,96),rubber,hub,.28,0,0);tire.rotation.z=Math.PI/2;
  const spinning=new THREE.Group();spinning.position.x=.28;hub.add(spinning);
  const tread=new THREE.InstancedMesh(new THREE.BoxGeometry(.056,.009,.029),rubber,252),dummy=new THREE.Object3D();
  for(let n=0;n<84;n++)for(let row=0;row<3;row++){const a=n/84*TAU+row*.025;dummy.position.set((row-1)*.077,.376*Math.cos(a),.376*Math.sin(a));dummy.rotation.set(a,0,(row-1)*.35);dummy.updateMatrix();tread.setMatrixAt(n*3+row,dummy.matrix);}
  tread.castShadow=true;spinning.add(tread);
  const barrel=cylinder(spinning,.233,.21,dark);barrel.rotation.z=Math.PI/2;
  torus(spinning,.223,.014,steel,[.118,0,0]);torus(spinning,.239,.008,dark,[.118,0,0]);
  torus(hub,.312,.0018,dark,[.412,0,0]);torus(hub,.325,.002,dark,[.405,0,0]);
  const disk=cylinder(spinning,.182,.014,metal('#6f7a82',.4),[.111,0,0]);disk.rotation.z=Math.PI/2;
  for(let n=0;n<10;n++){const a=n/10*TAU;const spoke=box(spinning,[.032,.157,.026],steel,[.13,.132*Math.cos(a),.132*Math.sin(a)]);spoke.rotation.x=a;}
  const cap=cylinder(spinning,.064,.04,steel,[.153,0,0]);cap.rotation.z=Math.PI/2;
  for(let n=0;n<5;n++){const a=n/5*TAU;const bolt=cylinder(spinning,.011,.012,black,[.179,.044*Math.cos(a),.044*Math.sin(a)]);bolt.rotation.z=Math.PI/2;}
  const holeMat=new THREE.MeshStandardMaterial({color:'#222a30',roughness:.9});
  for(let n=0;n<32;n++){const a=n/32*TAU;const hole=cylinder(spinning,.005,.002,holeMat,[.121,.157*Math.cos(a),.157*Math.sin(a)]);hole.rotation.z=Math.PI/2;}
  box(hub,[.07,.12,.065],paint,[.397,.09,-.12]);
  box(hub,[.18,.16,.19],dark,[-.06,0,0]);
  // Amortecedor telescópico e mola helicoidal com comprimento variável.
  const damperMat=metal(color,.25,.6),shock=cylinder(group,.056,.36,damperMat);
  const shaft=cylinder(group,.023,1,steel),boot=cylinder(group,.069,.09,black);
  class Coil extends THREE.Curve{getPoint(t,target=new THREE.Vector3()){const a=t*TAU*7;return target.set(.131*Math.cos(a),t,.131*Math.sin(a));}}
  const coil=mesh(new THREE.TubeGeometry(new Coil(),224,.012,8,false),paint,group);
  const lowerSeat=cylinder(group,.16,.028,dark),upperSeat=cylinder(group,.16,.028,steel);
  const arms=[0,1,2,3].map(()=>cylinder(group,.022,1,steel));
  const joints=[0,1,2,3].map(()=>mesh(new THREE.SphereGeometry(.041,14,10),black,group));
  // Fio da válvula e conexão hidráulica.
  const wireCurve=new THREE.CatmullRomCurve3([new THREE.Vector3(-.09,1.06,.08),new THREE.Vector3(-.33,1.12,.2),new THREE.Vector3(-.5,1.0,.3)]);
  mesh(new THREE.TubeGeometry(wireCurve,20,.009,6,false),black,body,0,-1.22,0);
  const valve=box(group,[.07,.10,.065],black,[-.03,.68,.07]);
  const ring=torus(group,.068,.008,steel);ring.rotation.set(Math.PI/2,0,0);
  return {group,body,hub,spinning,coil,shock,shaft,boot,lowerSeat,upperSeat,arms,joints,valve,ring,damperMat,x};
}

export class SuspensionScene{
  constructor(container){
    this.container=container;this.labels=false;this.scale=4;this.result=null;
    this.scene=new THREE.Scene();this.scene.background=new THREE.Color('#262e35');this.scene.fog=new THREE.FogExp2('#262e35',.038);
    this.renderer=new THREE.WebGLRenderer({antialias:true,powerPreference:'high-performance'});
    this.renderer.setPixelRatio(Math.min(devicePixelRatio,1.7));this.renderer.shadowMap.enabled=true;this.renderer.shadowMap.type=THREE.PCFSoftShadowMap;
    this.renderer.toneMapping=THREE.ACESFilmicToneMapping;this.renderer.toneMappingExposure=1.05;
    container.prepend(this.renderer.domElement);
    this.camera=new THREE.PerspectiveCamera(32,1,.1,100);
    this.controls=new OrbitControls(this.camera,this.renderer.domElement);this.controls.enableDamping=true;this.controls.dampingFactor=.07;
    this.controls.minDistance=3;this.controls.maxDistance=14;this.controls.maxPolarAngle=Math.PI*.49;this.controls.minPolarAngle=.15;this.controls.enablePan=true;
    this.resetCamera();
    const pmrem=new THREE.PMREMGenerator(this.renderer),room=new RoomEnvironment();
    this.environment=pmrem.fromScene(room,.04);this.scene.environment=this.environment.texture;room.dispose();pmrem.dispose();
    this.scene.add(new THREE.HemisphereLight('#e1efff','#4c5355',1.0));
    const key=new THREE.DirectionalLight('#fff1df',3.3);key.position.set(3,8,4);key.castShadow=true;key.shadow.mapSize.set(2048,2048);
    Object.assign(key.shadow.camera,{left:-6,right:6,top:6,bottom:-6,near:.5,far:25});key.shadow.normalBias=.025;key.shadow.bias=-.0001;this.scene.add(key);
    const rim=new THREE.DirectionalLight('#a4c8e9',2.1);rim.position.set(-5,4,-5);this.scene.add(rim);
    const floor=mesh(new THREE.PlaneGeometry(200,200),new THREE.MeshStandardMaterial({color:'#192127',roughness:1}),this.scene,0,-.22,0);floor.rotation.x=-Math.PI/2;floor.castShadow=false;
    const grid=new THREE.GridHelper(80,160,'#44515a','#38454e');grid.position.y=-.215;grid.material.transparent=true;grid.material.opacity=.22;this.scene.add(grid);
    const texture=asphaltTexture(),roadMat=new THREE.MeshStandardMaterial({color:'#515a61',map:texture,bumpMap:texture,bumpScale:.006,roughness:.95,metalness:.05,side:THREE.DoubleSide});
    this.roads=[];
    for(const x of [-1.55,1.55]){
      const geometry=new THREE.PlaneGeometry(2.7,32,1,640);geometry.rotateX(-Math.PI/2);
      const road=mesh(geometry,roadMat,this.scene,x,-.005,0);road.castShadow=false;this.roads.push(road);
    }
    this.dashes=new THREE.InstancedMesh(new THREE.BoxGeometry(.035,.003,.48),new THREE.MeshStandardMaterial({color:'#b8b8a4',roughness:.9}),66);this.scene.add(this.dashes);this.dummy=new THREE.Object3D();
    this.rigs=[createCorner(this.scene,-1.55,'#9aafbf'),createCorner(this.scene,1.55,'#fa8d50')];
    this.tagEls=[document.querySelector('#tag-pass'),document.querySelector('#tag-semi')];
    this.partEls=['Chassi · m_s','Mola · k_s','Válvula CDC','Roda · m_u'].map(text=>{const el=document.createElement('span');el.className='part-label';el.textContent=text;document.querySelector('#part-labels').append(el);return el;});
    this.vector=new THREE.Vector3();this.resizeObserver=new ResizeObserver(()=>this.resize());this.resizeObserver.observe(container);this.resize();
  }
  resetCamera(){this.camera.position.set(3.9,2.45,5.2);this.controls.target.set(0,.83,0);this.controls.update();}
  resize(){const {clientWidth:w,clientHeight:h}=this.container;if(!w||!h)return;this.camera.aspect=w/h;this.camera.zoom=Math.min(1,this.camera.aspect/1.65);this.camera.updateProjectionMatrix();this.renderer.setSize(w,h,false);}
  setResult(result){this.result=result;}
  roadAt(t){
    const d=this.result.data,p=this.result.config,k=t/p.dt;
    if(k<0)return 0;if(k>=d.w.length-1)return d.w[d.w.length-1];
    const i=Math.floor(k);return d.w[i]+(d.w[i+1]-d.w[i])*(k-i);
  }
  project(el,x,y,z,offsetX=0,offsetY=0){
    this.vector.set(x,y,z).project(this.camera);
    el.style.left=((this.vector.x*.5+.5)*this.container.clientWidth+offsetX)+'px';
    el.style.top=((-this.vector.y*.5+.5)*this.container.clientHeight+offsetY)+'px';
    el.style.visibility=this.vector.z>1?'hidden':'visible';
  }
  render(time=0){
    const result=this.result,p=result?.config,d=result?.data,scale=this.scale;
    const idx=d?Math.min(d.t.length-1,Math.floor(time/p.dt)):0;
    const speed=p?p.speed/3.6:20;
    for(const road of this.roads){
      const pos=road.geometry.attributes.position;
      for(let n=0;n<pos.count;n++)pos.setY(n,result?scale*this.roadAt(time-pos.getZ(n)/speed)-.005:0);
      pos.needsUpdate=true;road.geometry.computeVertexNormals();
    }
    for(let i=0;i<66;i++){
      const line=Math.floor(i/22),j=i%22,z=((j*1.4+time*speed)%30.8)-15.4;
      this.dummy.position.set([-2.86,0,2.86][line],result?scale*this.roadAt(time-z/speed)+.002:0,z);this.dummy.updateMatrix();this.dashes.setMatrixAt(i,this.dummy.matrix);
    }
    this.dashes.instanceMatrix.needsUpdate=true;
    for(let j=0;j<2;j++){
      const r=this.rigs[j],zs=d?d[j?'zs_semi':'zs_pass'][idx]*scale:0,zu=d?d[j?'zu_semi':'zu_pass'][idx]*scale:0;
      const bodyY=1.30+zs,wheelY=.365+zu,top=bodyY-.13,bottom=wheelY+.23,length=Math.max(.12,top-bottom);
      r.body.position.y=bodyY;r.hub.position.y=wheelY;r.spinning.rotation.x=-time*speed/.378;
      r.coil.position.set(-.07,bottom,0);r.coil.scale.y=length;
      r.lowerSeat.position.set(-.07,bottom,0);r.upperSeat.position.set(-.07,top,0);
      r.shock.position.set(-.07,wheelY+.23,0);r.boot.position.set(-.07,wheelY+.43,0);
      r.valve.position.y=wheelY+.28;r.ring.position.set(-.07,wheelY+.34,0);
      connect(r.shaft,new THREE.Vector3(-.07,wheelY+.34,0),new THREE.Vector3(-.07,top,0));
      for(let n=0;n<4;n++){
        const upper=n>=2,sgn=n%2?1:-1;
        const a=new THREE.Vector3(-.61,bodyY-(upper?.43:.84),sgn*.43),b=new THREE.Vector3(.1,wheelY+(upper?.16:-.08),sgn*.05);
        connect(r.arms[n],a,b);r.joints[n].position.copy(b);
      }
      if(d){const damping=j?d.c_efetivo[idx]:p.c_pass;const mix=Math.max(0,Math.min(1,(damping-p.c_min)/(p.c_max-p.c_min)));r.damperMat.emissive.set(j?'#b84918':'#000000');r.damperMat.emissiveIntensity=j?.08+mix*.2:0;}
      this.project(this.tagEls[j],r.x-.25,bodyY+.49,0,-63,-12);
    }
    const semi=this.rigs[1],by=semi.body.position.y,wy=semi.hub.position.y;
    const anchors=[[semi.x-.5,by+.06,-.6,8,0],[semi.x+.08,(by+wy)/2,0,16,0],[semi.x+.05,wy+.24,.12,23,0],[semi.x+.65,wy-.07,.1,12,0]];
    anchors.forEach((a,i)=>{this.partEls[i].hidden=!this.labels;this.project(this.partEls[i],...a);});
    this.controls.update();this.renderer.render(this.scene,this.camera);
  }
  dispose(){this.resizeObserver.disconnect();this.controls.dispose();this.environment.dispose();this.scene.traverse(o=>{o.geometry?.dispose();if(o.material)(Array.isArray(o.material)?o.material:[o.material]).forEach(m=>m.dispose());});this.renderer.dispose();}
}


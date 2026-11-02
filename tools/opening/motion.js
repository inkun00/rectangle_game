/* Original deterministic film. Units are a 1600 × 900 artboard; no frame state. */
'use strict';
const canvas = document.getElementById('film');
const c = canvas.getContext('2d', {alpha: false});
const W = 1600, H = 900, DURATION = 55;
const C = {navy:'#071827',ink:'#102b3b',mint:'#8ce2c4',teal:'#22a99a',cream:'#fff5da',gold:'#f5c25c',coral:'#ef826b',blue:'#3988a5'};
const assets = {};
const paths = {alien:'opening-v1/alien.png', ship:'opening-v1/ship.png', planet:'opening-v1/planet.png', earth:'opening-v1/earth.png', crew:'starfront-v1/crew.png'};
const clamp = (x,a=0,b=1) => Math.max(a,Math.min(b,x));
const mix = (a,b,p) => a+(b-a)*p;
const ease = x => { x=clamp(x); return x*x*(3-2*x); };
const out = x => 1-Math.pow(1-clamp(x),3);
const arrive = x => {x=clamp(x); return x===1?1:1-Math.exp(-7*x)*Math.cos(9*x);};
const prog = (t,a,b) => clamp((t-a)/(b-a));
const rand = n => { const v=Math.sin(n*127.1+45.6)*43758.5453; return v-Math.floor(v); };
function group(x,y,scale,angle,fn) { c.save();c.translate(x,y);c.rotate(angle||0);c.scale(scale,scale);fn();c.restore(); }
function alpha(a,fn) { c.save();c.globalAlpha*=clamp(a);fn();c.restore(); }
function polygon(pts,fill,stroke=null,width=3) { c.beginPath();pts.forEach(([x,y],i)=>i?c.lineTo(x,y):c.moveTo(x,y));c.closePath();if(fill){c.fillStyle=fill;c.fill();} if(stroke){c.strokeStyle=stroke;c.lineWidth=width;c.stroke();} }
function rect(x,y,w,h,color) {c.fillStyle=color;c.fillRect(x,y,w,h);}
function line(x,y,x2,y2,color,width=3) {c.beginPath();c.moveTo(x,y);c.lineTo(x2,y2);c.strokeStyle=color;c.lineWidth=width;c.stroke();}
function txt(s,x,y,size=36,color=C.cream,align='left',weight=700) {c.font=`${weight} ${size}px Quad`;c.textAlign=align;c.textBaseline='middle';c.fillStyle=color;c.fillText(s,x,y);}
function shadow(x,y,w=180) { c.save();c.globalAlpha=.2;c.fillStyle=C.ink;c.beginPath();c.ellipse(x,y,w,16,0,0,Math.PI*2);c.fill();c.restore(); }
function sprite(key,x,y,w,h=null,angle=0) {const im=assets[key];h=h||w*im.height/im.width;group(x,y,1,angle,()=>c.drawImage(im,-w/2,-h/2,w,h));}
function alien(pose,x,y,h,t=0,angle=0) {
  const im=assets.alien, sw=im.width/2, sh=im.height/2;
  group(x,y,1,angle,()=>c.drawImage(im,(pose%2)*sw,Math.floor(pose/2)*sh,sw,sh,-h/2,-h,h,h));
}
function person(index,x,y,h,t=0) { const im=assets.crew,sw=im.width/4,sh=im.height/4; group(x,y,1,Math.sin(t*3)*.015,()=>c.drawImage(im,index%4*sw,Math.floor(index/4)*sh,sw,sh,-h/2,-h,h,h)); }
function chip(label,x,y,fg=C.mint,size=20) {c.font=`700 ${size}px Quad`;const w=c.measureText(label).width+34;rect(x,y-19,w,38,C.ink);rect(x,y-19,4,38,fg);txt(label,x+18,y,size,fg);}
function speech(label,x,y,t,size=36) {const a=out(t*4);if(a<=0)return;group(x,y,a,0,()=>{c.font=`800 ${size}px Quad`;let w=c.measureText(label).width+50;rect(-w/2,-40,w,80,C.cream);polygon([[-12,40],[12,40],[5,57],[-12,57]],C.cream);txt(label,0,0,size,C.ink,'center',800);});}
function caption(text,t,sub=null) { if(!text)return; const a=out(t*3);alpha(a,()=>{c.font='600 32px Quad';const w=Math.min(1420,c.measureText(text).width+72);rect((W-w)/2,805,w,62,'#071827ed');rect((W-w)/2,805,4,62,C.gold);txt(text,800,836,32,C.cream,'center',600);if(sub)txt(sub,800,775,18,C.mint,'center',500);}); }
function title(kicker,main,x=100,y=100,size=64,color=C.cream) {txt(kicker,x,y,20,C.mint,'left',600);txt(main,x,y+62,size,color,'left',850);}
function space(t) {
 const g=c.createLinearGradient(0,0,1600,900);g.addColorStop(0,'#061422');g.addColorStop(.65,'#103b4d');g.addColorStop(1,'#182742');c.fillStyle=g;c.fillRect(0,0,W,H);
 for(let i=0;i<110;i++){let x=(rand(i+1)*1800-t*(3+rand(i+3)*9)+1800)%1800-100, y=rand(i+220)*900;let s=1.4+rand(i+88)*3;alpha(.25+.6*(.5+.5*Math.sin(t*.9+i)),()=>rect(x,y,s,s,i%7===0?C.gold:'#b4e8e4'));}
 // Long quiet diagonal bands give depth without a layer of decorative UI.
 alpha(.045,()=>{for(let i=0;i<5;i++)polygon([[i*400-500,900],[i*400+70,0],[i*400+140,0],[i*400-430,900]],C.mint);});
}
function earth(t,dim=0) {let z=1.045+Math.sin(t*.13)*.012; c.save();c.translate(800,450);c.scale(z,z);c.drawImage(assets.earth,-800,-450,1600,900);c.restore();if(dim)rect(0,0,W,H,`rgba(7,24,39,${dim})`);}
function topShade() {const g=c.createLinearGradient(0,0,0,320);g.addColorStop(0,'#071827dd');g.addColorStop(1,'#07182700');c.fillStyle=g;c.fillRect(0,0,W,320);}
function streaks(t,a=1) {alpha(a,()=>{for(let i=0;i<18;i++){let x=(rand(i+72)*1900-t*500)%1900,y=100+rand(i+101)*600;line(x,y,x+70+rand(i)*140,y,'#9be5dc66',2);}});}
function flame(x,y,t,scale=1,angle=0) {group(x,y,scale,angle,()=>{const n=75+15*Math.sin(t*34);polygon([[0,-20],[-n,-11],[-n-20,11],[0,20]],C.coral);polygon([[0,-12],[-n*.7,-7],[-n*.7,7],[0,12]],C.gold);polygon([[0,-5],[-n*.4,-4],[-n*.4,4],[0,5]],C.cream);});}
function ship(x,y,w,t,angle=0,engine=true,pilot=false) {group(x,y,1,angle,()=>{if(engine)flame(-w*.42,0,t,w/450);sprite('ship',0,0,w);if(pilot){c.drawImage(assets.alien,183,79,287,232,-w*.025,-w*.065,w*.16,w*.13);alpha(.13,()=>polygon([[-w*.12,-w*.08],[w*.11,-w*.08],[w*.04,w*.07],[-w*.19,w*.07]],C.cream));}});}
function squaresBurst(x,y,t,duration=1.5) {if(t<0||t>duration)return;let p=t/duration;for(let i=0;i<18;i++){let a=rand(i+310)*Math.PI*2,r=(40+rand(i+500)*130)*out(p);alpha(1-p,()=>group(x+Math.cos(a)*r,y+Math.sin(a)*r+p*p*90,1,p*5+i,()=>rect(-5,-5,10,10,[C.mint,C.gold,C.coral][i%3])));}}
function smoke(x,y,t) {for(let i=0;i<7;i++){let p=(t*.65+i/7)%1;alpha((1-p)*.45,()=>group(x+Math.sin(i*2+t)*30,y-p*160,1+p,Math.sin(i)*.3,()=>rect(-14,-14,28,28,'#39444c')));}}
function coin(x,y,scale,t=0) {group(x,y,scale,0,()=>{const turn=.65+.35*Math.abs(Math.cos(t*4));c.scale(turn,1);polygon([[0,-22],[22,0],[0,22],[-22,0]],C.gold,C.cream,2);polygon([[0,-12],[12,0],[0,12],[-12,0]],'#c8872c');});}
function coinFlight(start,end,t,count=7) {for(let i=0;i<count;i++){let p=prog(t,i*.11,i*.11+.7);if(p<=0||p>=1)continue;coin(mix(start[0],end[0],p),mix(start[1],end[1],p)-Math.sin(p*Math.PI)*180,1,t+i);}}
function bank(x,y,scale,t,fill=0) {group(x,y,scale,0,()=>{polygon([[-100,-64],[90,-64],[110,-45],[-80,-45]],'#e6b875');rect(-100,-45,190,132,'#cc8154');rect(-90,-33,170,108,'#ebac70');rect(-30,-65,64,8,C.ink);txt('우주선 저금통',-3,53,21,C.ink,'center',750);for(let i=0;i<Math.floor(fill);i++)coin(-63+(i%5)*30,-24+Math.floor(i/5)*20,.42,t+i);});}
const artPieces=[
 {p:[[0,0],[380,0],[380,250],[0,250]],f:'#a6dfdd'},
 {p:[[0,150],[380,150],[380,250],[0,250]],f:'#246c76'},
 {p:[[250,24],[296,24],[296,70],[250,70]],f:C.gold},
 {p:[[50,140],[160,140],[160,227],[50,227]],f:C.cream},
 {p:[[40,140],[68,96],[142,96],[171,140]],f:C.coral},
 {p:[[72,164],[99,164],[99,197],[72,197]],f:C.blue},
 {p:[[116,166],[144,166],[144,227],[116,227]],f:'#ad7852'},
 {p:[[240,147],[260,147],[260,228],[240,228]],f:'#835842'},
 {p:[[199,111],[250,74],[301,111],[250,148]],f:'#76b999'},
 {p:[[150,250],[216,250],[314,229],[250,229]],f:C.gold},
 {p:[[0,236],[43,218],[82,238],[43,250]],f:'#67b591'},
 {p:[[329,207],[367,207],[367,235],[329,235]],f:C.coral}
];
function painting(x,y,scale,t=99) {
 group(x,y,scale,0,()=>{
  rect(-214,-150,432,305,'#7d4a2d');rect(-204,-140,412,285,C.gold);rect(-193,-128,390,261,C.cream);
  c.save();c.translate(-190,-125);
  artPieces.forEach((piece,i)=>{let p=out(prog(t,i*.18,i*.18+.65));if(p<=0)return;c.save();c.translate((1-p)*(i%2?350:-400),(1-p)*(-180-i*12));c.globalAlpha*=p;polygon(piece.p,piece.f);c.restore();});c.restore();
  rect(-212,151,430,9,'#633b2a');
 });
}
function easel(x,y,scale,t) {group(x,y,scale,0,()=>{polygon([[-115,75],[-90,75],[-150,355],[-180,355]],'#8d583a');polygon([[95,75],[120,75],[180,355],[150,355]],'#ae7447');rect(-190,130,380,26,'#e0aa6a');painting(0,0,1,t);});}
function house(x,y,scale,t) {
 const parts=[
  {p:[[-248,152],[250,152],[250,177],[-248,177]],f:'#39545b'},
  {p:[[-215,-30],[212,-30],[212,152],[-215,152]],f:'#f4d2a4'},
  {p:[[-215,-30],[-175,-30],[-175,152],[-215,152]],f:'#ba8058'},
  {p:[[-215,50],[212,50],[212,62],[-215,62]],f:'#d7a476'},
  {p:[[-215,112],[212,112],[212,124],[-215,124]],f:'#d7a476'},
  {p:[[-254,-30],[-186,-133],[182,-133],[254,-30]],f:'#237b84'},
  {p:[[-235,-43],[-197,-106],[196,-106],[235,-43]],f:'#33989b'},
  {p:[[-55,22],[44,22],[44,152],[-55,152]],f:'#a16442'},
  {p:[[-42,35],[31,35],[31,142],[-42,142]],f:'#713f35'},
  {p:[[-150,12],[-82,12],[-82,87],[-150,87]],f:'#214c63'},
  {p:[[80,12],[150,12],[150,87],[80,87]],f:'#214c63'},
  {p:[[-143,20],[-89,20],[-89,80],[-143,80]],f:'#f6d77a'},
  {p:[[87,20],[143,20],[143,80],[87,80]],f:'#f6d77a'},
  {p:[[-120,18],[-113,18],[-113,81],[-120,81]],f:C.cream},
  {p:[[112,18],[119,18],[119,81],[112,81]],f:C.cream},
  {p:[[-148,47],[-85,47],[-85,54],[-148,54]],f:C.cream},
  {p:[[85,47],[146,47],[146,54],[85,54]],f:C.cream},
  {p:[[130,-133],[157,-133],[157,-186],[130,-186]],f:'#b86e4b'}
 ];
 group(x,y,scale,0,()=>{parts.forEach((part,i)=>{let p=arrive(prog(t,i*.23,i*.23+.6));if(p<=0)return;c.save();let fromX=(i%3-1)*180; c.translate(fromX*(1-p),-440*(1-p));polygon(part.p,part.f);c.restore();});if(t>4.2){rect(12,89,9,9,C.gold);}});
}
function blueprint(x,y,scale,t) {group(x,y,scale,0,()=>{
 rect(-390,-230,780,460,'#163d51');c.save();c.strokeStyle='#8ddbd52f';c.lineWidth=1;for(let a=-370;a<390;a+=30)line(a,-215,a,214,'#8ddbd51c',1);for(let b=-210;b<220;b+=30)line(-375,b,374,b,'#8ddbd51c',1);c.restore();
 const pol=[ [[-220,-70],[150,-70],[150,70],[-220,70]],[[150,-70],[250,-17],[250,25],[150,70]],[[-220,-70],[-300,-150],[-240,-150],[-140,-70]],[[-220,70],[-300,150],[-240,150],[-140,70]],[[-280,-30],[-220,-30],[-220,30],[-280,30]],[[-130,-43],[95,-43],[95,43],[-130,43]] ];
 pol.forEach((pts,i)=>{alpha(out(prog(t,i*.3,i*.3+.6)),()=>polygon(pts,null,C.mint,3));});
 txt('PROJECT : HOME',-350,-192,19,C.mint,'left',600);txt('새 우주선 설계도',-350,188,25,C.cream);txt('그림 + 집 → 제작비',350,188,22,C.gold,'right');
 if(t>2.2){const p=out(prog(t,2.2,3.3));line(-270,-180,-270+530*p,-180,C.gold,2);line(-270,-190,-270,-170,C.gold,2);line(260,-190,260,-170,C.gold,2);}
 });}
function opening(t) {
 space(t);let pan=ease(prog(t,3.6,6.6));sprite('planet',450-pan*230,452,680*(1-pan*.25),null,Math.sin(t*.3)*.025);
 let flight=out(prog(t,0,.95));let x=mix(1840,1110,flight)+pan*800,y=470+Math.sin(t*1.3)*18+pan*330;
 const angle=.06+pan*.55+(t>4.6?Math.sin(t*30)*.06:0);
 ship(x,y,630,t,angle,true,true);if(t>4.6)smoke(x-260,y,t);
 if(t<3.7){alpha(1-ease(prog(t,3.1,3.7)),()=>{title('아주 먼 우주, 네모난 고향','사각형 행성에서 온 여행자',90,88,49);chip('HOME',370,730,C.gold);});}
 else {alpha(out((t-3.7)*3),()=>{txt('어? 어어?!',1030,260,72,C.gold,'center',850);});}
 caption(t<3.6?'네모난 행성에서 온 작은 여행자.':'그런데… 우주선이 말을 안 듣는다!',t);
}
function crash(t) {
 earth(t,.03);topShade();title('예정에 없던 착륙','여기는… 지구?!',100,90,70);
 let p=ease(prog(t,0,2.1));let x=mix(-300,570,p),y=mix(-170,608,p);
 c.save();if(t>2.1&&t<2.6){c.translate(Math.sin(t*75)*(2.6-t)*22,Math.cos(t*52)*(2.6-t)*12);}
 shadow(570,708,260);ship(x,y,750,t,mix(.65,.18,p),t<2.1,t<2.65);
 if(t>=2.1){smoke(310,530,t);squaresBurst(750,680,t-2.1);line(692,558,722,590,C.ink,6);line(722,590,704,630,C.ink,6);}
 c.restore();
 if(t>2.65){let a=arrive(prog(t,2.65,3.3));alien(1,1050,725,330*a,t,Math.sin(t*3)*.02);shadow(1050,728,120);}
 if(t>4.1){let a=out(prog(t,4.1,4.7));group(1320,445,a,-.07,()=>{rect(-100,-65,200,130,'#684b42');rect(-88,-52,176,104,'#a77754');rect(28,-22,90,46,'#704e3d');txt('텅!',-20,-2,53,C.cream,'center');});}
 caption(t<3.5?'쿵! 다행히 다친 곳은 없지만…':'고향으로 돌아가려면, 새 우주선이 필요해요.',t);
}
function inspiration(t) {
 earth(t,.12);
 shadow(350,734,150);alien(t<.7?0:2,350,742,425,t,Math.sin(t*3)*.025);
 easel(1010,435,1.14,Math.max(-1,t-1.2));
 if(t>.6&&t<2.1)speech('아하!',520,292,t-.6,44);
 const colors=[C.gold,C.teal,C.coral,C.cream,C.blue];
 for(let i=0;i<5;i++){let p=out(prog(t,.3+i*.1,.9+i*.1));let x=650+Math.sin(t+i)*16,y=345+i*65;alpha((1-ease(prog(t,3.2,4.2)))*p,()=>group(x,y,p,t*.2+i,()=>polygon([[-22,-22],[24,-22],[24,22],[-22,22]],colors[i])));}
 if(t>4.8){chip('나의 첫 작품',874,688,C.gold,24);}
 topShade();title('작은 여행자의 커다란 재능','사각형이라면 자신 있어!',100,90,64);
 caption('정사각형, 직사각형, 사다리꼴… 모으면 멋진 그림이 돼요!',t);
}
function artSale(t) {
 earth(t,.09);topShade();title('첫 번째 도전','그림을 그려서 팔자!',100,86,66);
 shadow(270,737,140);alien(2,270,742,380,t,Math.sin(t*3)*.02);
 shadow(1325,740,130);person(6,1325,747,365,t);
 let handed=ease(prog(t,2.8,4.2));painting(mix(785,1170,handed),mix(437,530,handed),mix(1.08,.58,handed));
 bank(680,660,.9,t,Math.floor(prog(t,3.6,5.5)*10));
 if(t<3.2)speech('이 그림, 살게요!',1300,273,t-.3,32);
 if(t>=3){coinFlight([1240,510],[680,595],t-3,9);alpha(out(prog(t,3,3.4)),()=>group(790,376,1,-.10,()=>{rect(-138,-42,276,84,C.coral);txt('판매 완료!',0,0,44,C.cream,'center',850);}));}
 caption(t<3?'마을 사람의 마음에 쏙 든 첫 작품.':'첫 수익은 차곡차곡, 우주선 저금통으로!',t);
}
function construction(t) {
 earth(t,.1);
 if(t<2.6){const a=1-ease(prog(t,1.8,2.6));alpha(a,()=>{group(810,475,1,-.04,()=>{rect(-255,-182,510,364,C.cream);rect(-255,-182,510,58,C.teal);txt('새 집 건축 의뢰',0,-153,30,C.cream,'center');txt('네모 창문이 있는',0,-62,37,C.ink,'center');txt('튼튼한 집을 부탁해요!',0,-4,37,C.ink,'center');house(0,103,.34,99);});person(0,1330,736,350,t);});}
 const a=out(prog(t,.7,1.4));alien(3,285,750,375*a,t,Math.sin(t*4)*.025);shadow(285,746,130);
 if(t>2){shadow(960,738,320);let push=ease(prog(t,5.2,6.8));house(970-12*push,540-5*push,1.13+.05*push,t-2.8);}
 if(t>2.7&&t<7.3){let local=(t-2.7)*2;const k=Math.floor(local),f=local-k;group(590,380+f*150,1,-.2+f*.45,()=>{rect(-8,-50,16,110,'#bc824f');rect(-48,-62,96,40,C.ink);});}
 if(t>7.7){person(0,1370+160*(1-out(prog(t,7.7,8.5))),739,330,t);speech('우리 집, 최고예요!',1280,278,t-7.7,31);}
 if(t>9){bank(565,680,.68,t,10);coinFlight([1330,570],[565,635],t-9,10);alpha(out(prog(t,9,9.5)),()=>group(960,384,1,-.07,()=>{rect(-137,-38,274,76,C.coral);txt('집 판매 완료!',0,0,37,C.cream,'center');}));}
 topShade();title('두 번째 도전','이번엔 집을 지어 주세요!',100,88,64);
 caption(t<2.4?'이번에는 집 건축 의뢰가 들어왔어요.':t<8?'사각형 자재를 쌓고, 지붕과 창문을 달면…':'집을 지어 팔면, 고향으로 가는 꿈도 한 걸음 더!',t);
}
function dream(t) {
 space(t);title('그림 한 장, 집 한 채','차곡차곡 모이는 귀향의 꿈',100,82,58);
 let s=out(prog(t,0,.7));group(800,440,s,-.015,()=>blueprint(0,0,1, t-.4));
 bank(277,630,1.1,t,14);painting(270,340,.48);house(1310,380,.58,99);alien(3,1320,740,295,t,.02);
 if(t>.4&&t<3.1)coinFlight([270,380],[800,470],t-.4,7);
 if(t>1.8&&t<4.5)coinFlight([1320,450],[800,470],t-1.8,8);
 if(t>4.5){alpha(ease(prog(t,4.5,6.5))*.85,()=>ship(800,438,590,t,0,false));}
 caption(t<4.1?'그림과 집을 팔아 모은 돈으로…':'언젠가 고향까지 날아갈 새 우주선을 만들 거예요.',t);
}
function finale(t) {
 space(t);const reveal=ease(prog(t,0,1.6));
 sprite('planet',1190,385,550,null,Math.sin(t*.4)*.018);
 alpha(.28,()=>{c.setLineDash([8,15]);c.beginPath();c.moveTo(590,620);c.bezierCurveTo(800,150,1010,170,1150,340);c.strokeStyle=C.gold;c.lineWidth=3;c.stroke();c.setLineDash([]);});
 ship(800+Math.sin(t*.5)*12,568+Math.sin(t)*10,500,t,-.24,true);
 alien(0,365,744,330,t,Math.sin(t*2)*.012);
 if(t<2.3){alpha(1-ease(prog(t,1.6,2.3)),()=>{txt('집으로 가는 길,',98,126,48,C.mint);txt('우리 손으로 만들자.',98,194,61,C.cream);});}
 if(t>1.6){const p=out(prog(t,1.6,2.5));alpha(p,()=>{txt('그림을 그리고 · 집을 짓고 · 꿈을 모으는',98,94,25,C.mint,'left',500);txt('사각형 월드',98,199,110,C.cream,'left',900);rect(101,275,78,7,C.gold);txt('별빛 고향으로',98,330,43,C.gold,'left',650);});}
 caption('우리, 함께 돌아갈까?',t);
 if(t>4.5){alpha(ease(prog(t,4.5,5.4)),()=>{txt('당신의 첫 사각형에서 모험이 시작됩니다.',98,424,26,C.cream,'left',500);});}
 // Last 1.1 seconds deliberately settle so the title can be read.
}
const shots=[{at:0,run:opening},{at:7,run:crash},{at:14,run:inspiration},{at:21,run:artSale},{at:28,run:construction},{at:39,run:dream},{at:47,run:finale}];
function drawScene(t){let shot=shots[0];for(const s of shots)if(t>=s.at)shot=s;shot.run(t-shot.at);}
window.renderAt = function(seconds) {
 let t=clamp(seconds,0,DURATION-1/1000);
 if(t>53.9)t=53.9;
 const width=Math.max(1,Math.round(innerWidth)),height=Math.max(1,Math.round(innerHeight));
 if(canvas.width!==width||canvas.height!==height){canvas.width=width;canvas.height=height;}
 c.setTransform(width/W,0,0,height/H,0,0);c.globalAlpha=1;c.lineCap='butt';c.lineJoin='miter';c.imageSmoothingEnabled=true;c.imageSmoothingQuality='high';
 drawScene(t);
 // A moving quadrilateral wipes only between scenes, never hides a reading beat.
 for(const cut of [7,14,21,28,39,47]){let d=t-cut;if(d>=-.18&&d<=.22){let p=(d+.18)/.4;let x=mix(-700,2200,p);polygon([[x-420,0],[x-80,0],[x+340,900],[x,900]],C.mint);polygon([[x-455,0],[x-425,0],[x-5,900],[x-35,900]],C.gold);}}
 if(t<.3)alpha(.35*(1-out(t/.3)),()=>rect(0,0,W,H,C.navy));
 window.__frameTime=t;
};
window.ready=Promise.all(Object.entries(paths).map(([key,path])=>new Promise((resolve,reject)=>{let im=new Image();im.onload=()=>{assets[key]=im;resolve();};im.onerror=()=>reject(new Error('Missing image: '+path));im.src='../../assets/generated/'+path;})).concat([document.fonts.load('700 48px Quad'),document.fonts.ready])).then(()=>{
 window.renderAt(0);
 if(!window.__rendering&&!window.__RENDERING&&!window.__CAPTURE){const start=performance.now();function tick(now){window.renderAt((now-start)/1000%DURATION);requestAnimationFrame(tick);}requestAnimationFrame(tick);}
});
window.FILM={title:'사각형 월드 — 별빛 고향으로',duration:DURATION,fps:30,width:1920,height:1080};

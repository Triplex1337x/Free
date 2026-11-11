// Builds the real world (AssetForge + WorldBuilder) under the mock and renders one area with three.js.
// Usage: node world3d.js out.png cx cy cz radius camx camy camz
const fs = require("fs"), path = require("path");
const fengari = require(process.env.FENGARI || "fengari");
const { lua, lauxlib, lualib, to_luastring } = fengari;
const { chromium } = require(process.env.PLAYWRIGHT || "playwright");
const SRC = process.env.SRC || path.join(__dirname, "..", "..", "src");
const THREE_JS = process.env.THREE_JS || path.join(path.dirname(require.resolve("three")), "three.min.js");
const [out, cx, cy, cz, rad, camx, camy, camz] = process.argv.slice(2);
function listing(root) { const o = {}; (function w(d){ const es = fs.readdirSync(d,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name)); o[d]=es.map(e=>({name:e.name,dir:e.isDirectory()})); for (const e of es) if (e.isDirectory()) w(path.join(d,e.name)); })(root);
  let s = "LISTING = {\n"; for (const [d, es] of Object.entries(o)) s += `[${JSON.stringify(d)}] = {` + es.map(e=>`{name=${JSON.stringify(e.name)},dir=${e.dir}}`).join(",") + "},\n"; return s + "}\n"; }
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
const code = `SRC_ROOT = ${JSON.stringify(SRC)}\n${listing(SRC)}R = dofile(${JSON.stringify(path.join(__dirname, "roblox.lua"))})
R.listdir = function(d) return LISTING[d] or {} end
local RS = game:GetService("ReplicatedStorage")
R.mountTree(RS, SRC_ROOT .. "/ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
R.mountTree(SSS, SRC_ROOT .. "/ServerScriptService")
local ok, err = xpcall(function()
  local AF = require(SSS.Managers.AssetForge)
  local WB = require(SSS.Managers.WorldBuilder)
  local assets = AF.Build()
  WB.Build(assets)
end, debug.traceback)
if not ok then print("WORLD ERROR", err) end
local c = Vector3.new(${cx}, ${cy}, ${cz})
local keep = Instance.new("Model")
local n = 0
for _, d in ipairs(workspace:GetDescendants()) do
  if d:IsA("BasePart") and (d.Position - c).Magnitude < ${rad} and (d.Transparency or 0) < 0.98 then
    n = n + 1
    local cl = d:Clone()
    for _, ch in ipairs(cl:GetChildren()) do if ch.ClassName ~= "SpecialMesh" then ch:Destroy() end end
    cl.Parent = keep
  end
end
print("parts", n)
OUTPUT = R.serialize3d(keep)`;
if (lauxlib.luaL_loadstring(L, to_luastring(code)) !== lua.LUA_OK || lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) { console.error(lua.lua_tojsstring(L, -1)); process.exit(1); }
lua.lua_getglobal(L, to_luastring("OUTPUT"));
const data = lua.lua_tojsstring(L, -1);
const html = `<!doctype html><html><body style="margin:0;background:#9cc8f5"><script src="file://${THREE_JS}"></script><script>
const P=${data};
const r=new THREE.WebGLRenderer({antialias:true,preserveDrawingBuffer:true}); r.setSize(1400,800); r.outputEncoding=THREE.sRGBEncoding; r.toneMapping=THREE.ACESFilmicToneMapping; r.shadowMap.enabled=true; document.body.appendChild(r.domElement);
const s=new THREE.Scene(); s.background=new THREE.Color(0x9cc8f5);
s.add(new THREE.HemisphereLight(0xe8f0ff,0x506040,0.9)); const sun=new THREE.DirectionalLight(0xfff4e0,1.2); sun.position.set(${cx}-80,${cy}+160,${cz}-60); sun.target.position.set(${cx},${cy},${cz}); sun.castShadow=true; sun.shadow.mapSize.set(4096,4096); Object.assign(sun.shadow.camera,{left:-${rad},right:${rad},top:${rad},bottom:-${rad},near:1,far:600}); s.add(sun); s.add(sun.target);
const box=new THREE.BoxGeometry(1,1,1), sph=new THREE.SphereGeometry(.5,20,14), cyl=new THREE.CylinderGeometry(.5,.5,1,20); cyl.rotateZ(Math.PI/2);
const wg=new THREE.BufferGeometry(); wg.setAttribute('position',new THREE.Float32BufferAttribute([-.5,-.5,-.5,.5,-.5,-.5,.5,-.5,.5,-.5,-.5,.5,-.5,.5,.5,.5,.5,.5],3)); wg.setIndex([0,2,1,0,3,2,3,4,5,3,5,2,0,1,5,0,5,4,0,4,3,1,2,5]); const wn=wg.toNonIndexed(); wn.computeVertexNormals();
for(const p of P){ let g=box,sx=p.s[0],sy=p.s[1],sz=p.s[2];
 if(p.mesh&&p.mesh.type==='Sphere'){g=sph;} else if(p.shape==='Ball'){g=sph;const m=Math.min(sx,sy,sz);sx=sy=sz=m;} else if(p.shape==='Cylinder'){g=cyl;const d=Math.min(sy,sz);sy=sz=d;} else if(p.c==='WedgePart'||p.c==='CornerWedgePart') g=wn;
 const col=new THREE.Color(p.col[0],p.col[1],p.col[2]).convertSRGBToLinear();
 const m=p.mat==='Neon'?new THREE.MeshStandardMaterial({color:col,emissive:col,emissiveIntensity:.8}):new THREE.MeshStandardMaterial({color:col,roughness:.7});
 if(p.t>0){m.transparent=true;m.opacity=1-p.t;}
 const me=new THREE.Mesh(g,m); const c=p.cf; me.matrixAutoUpdate=false; me.matrix.set(c[3],c[4],c[5],c[0],c[6],c[7],c[8],c[1],c[9],c[10],c[11],c[2],0,0,0,1).multiply(new THREE.Matrix4().makeScale(sx,sy,sz)); me.castShadow=true; me.receiveShadow=true; s.add(me);}
const cam=new THREE.PerspectiveCamera(45,1400/800,.5,2000); cam.position.set(${camx},${camy},${camz}); cam.lookAt(${cx},${cy},${cz}); r.render(s,cam); window.__done=true;
</script></body></html>`;
const tmp = path.join(require("os").tmpdir(), "world3d.html"); fs.writeFileSync(tmp, html);
(async()=>{ const b=await chromium.launch({args:["--use-gl=swiftshader","--enable-webgl","--ignore-gpu-blocklist"]}); const p=await b.newPage({viewport:{width:1400,height:800}});
 p.on("pageerror",e=>console.log("pageerror",e.message)); await p.goto("file://"+tmp); await p.waitForFunction(()=>window.__done===true,null,{timeout:180000}); await p.screenshot({path:out}); await b.close(); console.log("wrote",out); })();

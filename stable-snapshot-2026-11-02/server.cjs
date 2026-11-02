'use strict';
const http = require('node:http');
const crypto = require('node:crypto');
const TTL_MS = 90_000;
const GAME_PLACE = 107778070777162;
function createFinderServer({ roomKey, viewerKeyHash, iconBytes, now = Date.now, ttlMs = TTL_MS } = {}) {
  if (typeof roomKey !== 'string' || roomKey.length < 16) throw new Error('Room key must contain at least 16 characters');
  const sessions = new Map(), buckets = new Map(), joins = new Map(), takenEggs = new Map();
  const JOIN_TTL_MS=300_000;
  const snapshots=new Map();
  const unavailableEggs=new Map();
  const eggHistory=new Map();
  const digest = value => crypto.createHash('sha256').update(String(value || '')).digest();
  const expected = digest(roomKey);
  if (typeof viewerKeyHash !== 'string' || !/^[a-f0-9]{64}$/.test(viewerKeyHash)) throw new Error('Private viewer key hash required');
  const viewerDigest=Buffer.from(viewerKeyHash,'hex');
  const id = value => typeof value === 'string' && /^[A-Za-z0-9_-]{8,160}$/.test(value);
  const finite = (value, max = 1e35) => typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= max;
  const text = (value, limit = 90) => typeof value === 'string' ? value.replace(/[\x00-\x1f\x7f]/g, '').slice(0, limit) : '';
  function clean() {
    const time = now();
    for(const [key,value]of eggHistory)if(time>=value.expiresAt)eggHistory.delete(key);
    for(const [key,value]of unavailableEggs)if(time>=value.expiresAt)unavailableEggs.delete(key);
    for(const [key,snapshot] of snapshots) if(time>=snapshot.expiresAt) snapshots.delete(key);
    for(const [key,slot] of joins) if(time>=slot.expiresAt) joins.delete(key);
    for (const [key, session] of sessions) if (time - session.updatedAt >= ttlMs) sessions.delete(key);
    if(takenEggs.size){
      const live=new Set();
      for(const session of snapshots.values())for(const value of session.eggs)live.add(`${session.placeId}:${session.jobId}:${value.uid}`);
      for(const key of takenEggs.keys())if(!live.has(key))takenEggs.delete(key);
    }
    for (const [key, bucket] of buckets) if (time - bucket.since >= 60_000) buckets.delete(key);
  }
  function quota(key, limit) {
    clean();
    let bucket = buckets.get(key);
    if (!bucket) {
      if (buckets.size >= 12000) return false;
      bucket = { since: now(), count: 0 }; buckets.set(key, bucket);
    }
    return ++bucket.count <= limit;
  }
  function json(res, status, body) {
    res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
    res.end(JSON.stringify(body));
  }
  function egg(value) {
    if (!value || !id(value.uid) || !finite(value.rate) || value.rate === 0 || !finite(value.rank, 100)) return null;
    if (!text(value.name)) return null;
    return {
      uid: value.uid, name: text(value.name), category: text(value.category), rarity: text(value.rarity), rank: value.rank,
      rate: value.rate, scale: finite(value.scale, 1e6) ? value.scale : null,
      weight: finite(value.weight) ? value.weight : null,
      icon: typeof value.icon === 'string' && /^rbxassetid:\/\/\d{1,20}$/.test(value.icon) ? value.icon : '',
      area: text(value.area), mutations: text(value.mutations, 180), estimated: value.estimated === true,
      traitsKnown: value.traitsKnown === true, visualId: value.visualId === true,
      source: value.source === 'event' ? 'event' : 'field'
    };
  }
  function rankedEggs(){
    const entries=new Map();
    for(const session of snapshots.values())for(const value of session.eggs){
      const key=`${session.placeId}:${session.jobId}:${value.uid}`;
      const previous=entries.get(key);
      if(!previous || previous.seenAt<session.updatedAt)entries.set(key,{...value,key,placeId:session.placeId,jobId:session.jobId,seenAt:session.updatedAt,expiresAt:session.expiresAt,resetEstimated:session.resetEstimated,cached:now()-session.updatedAt>30_000,reporters:(previous?.reporters||0)+1});
      else previous.reporters++;
    }
    for(const [key,value] of unavailableEggs)entries.set(key,{...value,key,unavailable:true,cached:false});
    return [...entries.values()].sort((a,b)=>b.rate-a.rate || a.key.localeCompare(b.key));
  }
  const server = http.createServer(async (req, res) => {
    try {
      clean();
      const url = new URL(req.url, 'http://localhost');
      if(req.method==='GET' && url.pathname==='/assets/finder.jpg' && Buffer.isBuffer(iconBytes)){
        res.writeHead(200,{'Content-Type':'image/jpeg','Cache-Control':'public, max-age=86400'});return res.end(iconBytes);
      }
      if (req.method === 'GET' && url.pathname === '/health') return json(res, 200, { ok: true, version: 4.3, features: ['cycle-cache','taken-state'] });
      if (!crypto.timingSafeEqual(digest(req.headers['x-nyx-room']), expected)) return json(res, 401, { error: 'Room key required' });
      const ip = String(req.headers['cf-connecting-ip'] || req.socket.remoteAddress || '').slice(0, 80);
      if(url.pathname==='/v1/join' && req.method==='POST'){
        if(!quota(`join:${ip}`,60)) return json(res,429,{error:'Too many join requests'});
        let body='',size=0;
        for await(const chunk of req){size+=chunk.length;if(size>2048)return json(res,413,{error:'Request too large'});body+=chunk.toString('utf8');}
        let data;try{data=JSON.parse(body)}catch{return json(res,400,{error:'Invalid JSON'})}
        if(!data || data.placeId!==GAME_PLACE || !id(data.jobId) || !id(data.reporterId))return json(res,400,{error:'Invalid join'});
        const ranked=rankedEggs();
        const target=ranked.find(e=>e.jobId===data.jobId && (!data.uid || e.uid===data.uid));
        if(target?.unavailable || (data.uid && !target))return json(res,200,{ok:true,allowed:false,unavailable:true,error:'Egg no longer available'});
        const previous=target && takenEggs.get(target.key);
        if(previous)return json(res,200,{ok:true,allowed:previous.reporterId===data.reporterId,hideAt:previous.hideAt});
        const topIndex=target ? ranked.slice(0,4).findIndex(e=>e.key===target.key) : -1;
        if(topIndex>=0){
          const hideAt=now()+(topIndex<2?5000:3000);
          takenEggs.set(target.key,{hideAt,reporterId:data.reporterId});
          return json(res,200,{ok:true,allowed:true,hideAt});
        }
        const key=`${data.placeId}:${data.jobId}`;
        let slot=joins.get(key);
        if(slot?.reporters.has(data.reporterId))return json(res,200,{ok:true,allowed:true,expiresAt:slot.expiresAt});
        if(slot?.reporters.size>=2)return json(res,200,{ok:true,allowed:false,expiresAt:slot.expiresAt});
        if(![...snapshots.values()].some(s=>s.jobId===data.jobId && s.placeId===data.placeId && s.eggs.length))return json(res,200,{ok:true,allowed:false});
        if(!slot){if(joins.size>=4000)return json(res,503,{error:'Join capacity reached'});slot={reporters:new Set(),expiresAt:Math.min(now()+JOIN_TTL_MS,snapshots.get(data.jobId)?.resetEstimated===false?snapshots.get(data.jobId).expiresAt:Infinity)};joins.set(key,slot)}
        slot.reporters.add(data.reporterId);
        if(slot.reporters.size===2)slot.expiresAt=Math.min(now()+JOIN_TTL_MS,snapshots.get(data.jobId)?.resetEstimated===false?snapshots.get(data.jobId).expiresAt:Infinity);
        return json(res,200,{ok:true,allowed:true,expiresAt:slot.expiresAt});
      }
      if (url.pathname === '/v1/report' && req.method === 'POST') {
        if (!quota(`post:${ip}`, 90)) return json(res, 429, { error: 'Too many reports' });
        if (!String(req.headers['content-type'] || '').includes('application/json')) return json(res, 415, { error: 'JSON required' });
        const chunks = []; let size = 0;
        for await (const chunk of req) {
          size += chunk.length;
          if (size > 96 * 1024) return json(res, 413, { error: 'Report too large' });
          chunks.push(chunk);
        }
        let report;
        try { report = JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { return json(res, 400, { error: 'Invalid JSON' }); }
        if (!report || report.placeId !== GAME_PLACE || !id(report.jobId) || !id(report.reporterId) || !Array.isArray(report.eggs) || report.eggs.length > 40) {
          return json(res, 400, { error: 'Invalid report' });
        }
        if(report.removedUids!==undefined && (!Array.isArray(report.removedUids) || report.removedUids.length>256 || report.removedUids.some(uid=>!id(uid))))return json(res,400,{error:'Invalid removed eggs'});
        if(report.fieldUids!==undefined && (!Array.isArray(report.fieldUids) || report.fieldUids.length>4000 || report.fieldUids.some(uid=>!id(uid))))return json(res,400,{error:'Invalid field snapshot'});
        const sessionKey = `${report.placeId}:${report.jobId}:${report.reporterId}`;
        if (!sessions.has(sessionKey) && sessions.size >= 4000) return json(res, 503, { error: 'Reporter capacity reached' });
        const eggs = new Map();
        for (const raw of report.eggs) { const value = egg(raw); if (value) eggs.set(value.uid, value); }
        // Accept classic 40-egg clients, retain only their highest 15.
        const best=[...eggs.values()].sort((a,b)=>b.rate-a.rate || a.uid.localeCompare(b.uid)).slice(0,15);
        eggs.clear();for(const value of best)eggs.set(value.uid,value);
        const receivedAt=now();
        const validReset=Number.isFinite(report.resetAt) && report.resetAt>receivedAt && report.resetAt<=receivedAt+305_000;
        if(report.resetAt!==undefined && !validReset)return json(res,400,{error:'Invalid or expired reset deadline'});
        const expiresAt=validReset?report.resetAt:receivedAt+ttlMs;
        if(!snapshots.has(report.jobId) && snapshots.size>=4000)return json(res,503,{error:'Snapshot capacity reached'});
        const snapshot={placeId:report.placeId,jobId:report.jobId,updatedAt:receivedAt,expiresAt,resetEstimated:!validReset,eggs:[...eggs.values()]};
        const previousSnapshot=snapshots.get(report.jobId);
        const missing=new Set(report.removedUids||[]);
        if(Array.isArray(report.fieldUids)){
          const present=new Set(report.fieldUids);
          for(const value of eggHistory.values()){
            if(value.jobId===report.jobId && value.placeId===report.placeId && value.source!=='event' && !present.has(value.uid))missing.add(value.uid);
          }
        }
        for(const uid of missing){
          if(eggs.has(uid))continue;
          const key=report.placeId+':'+report.jobId+':'+uid;
          const historical=eggHistory.get(key);
          const previous=historical || previousSnapshot?.eggs.find(e=>e.uid===uid);
          if(!previous || (historical?historical.expiresAt:previousSnapshot.expiresAt)<=receivedAt)continue;
          if(unavailableEggs.size>=160000 && !unavailableEggs.has(key))continue;
          unavailableEggs.set(key,{...previous,placeId:report.placeId,jobId:report.jobId,seenAt:historical?historical.seenAt:previousSnapshot.updatedAt,unavailableAt:receivedAt,expiresAt:Math.min(expiresAt,historical?historical.expiresAt:previousSnapshot.expiresAt),resetEstimated:snapshot.resetEstimated});
        }
        // A stale reporter cannot revive the same confirmed-taken UID.
        for(const value of eggs.values()){
          const key=report.placeId+':'+report.jobId+':'+value.uid;
          if(eggHistory.size<160000 || eggHistory.has(key))eggHistory.set(key,{...value,placeId:report.placeId,jobId:report.jobId,seenAt:receivedAt,expiresAt});
        }
        snapshots.set(report.jobId,snapshot);
        sessions.set(sessionKey,snapshot);
        return json(res, 200, { ok: true, accepted: eggs.size, expiresIn:(expiresAt-receivedAt)/1000,resetAt:expiresAt });
      }
      if (url.pathname === '/v1/eggs' && req.method === 'GET') {
        if (!quota(`unlock:${ip}`, 120)) return json(res, 429, { error: 'Too many access attempts' });
        const premium = url.searchParams.get('tier') === 'premium' || !!req.headers['x-nyx-viewer'];
        if (premium && !crypto.timingSafeEqual(digest(req.headers['x-nyx-viewer']),viewerDigest)) return json(res,401,{error:'Premium access code required'});
        if (!quota(`get:${ip}`, 360)) return json(res, 429, { error: 'Too many requests' });
        const placeId = Number(url.searchParams.get('placeId') || GAME_PLACE);
        if (placeId !== GAME_PLACE) return json(res, 400, { error: 'Unsupported place' });
        const minRate = Math.max(0, Number(url.searchParams.get('minRate')) || 0);
        const minRank = Math.max(0, Number(url.searchParams.get('minRank')) || 0);
        const limit = Math.max(1, Math.min(premium ? 10 : 30, Number(url.searchParams.get('limit')) || (premium ? 10 : 30)));
        const offset = premium ? 0 : Math.max(0, Math.floor(Number(url.searchParams.get('offset')) || 0));
        const excludeJob = url.searchParams.get('excludeJob') || '';
        const onlyJob = url.searchParams.get('onlyJob') || '';
        const jobs = new Set([...snapshots.values()].map(s=>s.jobId));
        // Apply tier ranking before user-controlled filters and join reservations.
        const ranked=rankedEggs();
        const tierEntries=premium ? ranked.slice(0,10) : ranked;
        const visible=tierEntries.filter(e=>{const slot=joins.get(`${e.placeId}:${e.jobId}`),taken=takenEggs.get(e.key);return (e.unavailable || (!(taken && now()>=taken.hideAt) && !(slot?.reporters.size>=2))) && e.jobId!==excludeJob && (!onlyJob || e.jobId===onlyJob) && e.rate>=minRate && e.rank>=minRank}).slice(0,premium?10:30);
        const items=visible.slice(offset,offset+limit).map((e,i)=>({...e,...(premium ? {globalRank:ranked.indexOf(e)+1} : {displayRank:offset+i+1})}));
        return json(res, 200, { tier:premium?'premium':'public', serverTime: now(), retainedServers:snapshots.size, ttlSeconds: ttlMs / 1000, participants: sessions.size, servers: jobs.size, total:visible.length, nextOffset:offset+limit<visible.length ? offset+limit : null, items });
      }
      return json(res, 404, { error: 'Not found' });
    } catch {
      if (!res.headersSent) json(res, 500, { error: 'Request failed' });
      else res.end();
    }
  });
  server.requestTimeout = 12_000;
  server.headersTimeout = 10_000;
  server.importFeed=function(items){
    clean();
    const groups=new Map();
    for(const value of items){
      const checked=egg(value);
      if(!checked || value.placeId!==GAME_PLACE || !id(value.jobId) || !Number.isFinite(value.seenAt))continue;
      // Public clients do not send schedules. Imported deadlines are estimates,
      // derived from the sighting's time, never from the poll/arrival time.
      const expiresAt=(Math.floor(value.seenAt/300_000)+1)*300_000;
      if(expiresAt<=now() || value.seenAt>now()+5000)continue;
      let group=groups.get(value.jobId);
      if(!group){group={placeId:GAME_PLACE,jobId:value.jobId,updatedAt:value.seenAt,expiresAt,resetEstimated:true,eggs:[]};groups.set(value.jobId,group)}
      group.updatedAt=Math.max(group.updatedAt,value.seenAt);group.eggs.push(checked);
    }
    for(const [job,group] of groups){
      const previous=snapshots.get(job);
      if(previous && (!previous.resetEstimated || previous.updatedAt>=group.updatedAt))continue;
      if(!previous && snapshots.size>=4000)continue;
      const merged=new Map(previous && previous.expiresAt===group.expiresAt?previous.eggs.map(e=>[e.uid,e]):[]);
      for(const e of group.eggs)merged.set(e.uid,e);
      group.eggs=[...merged.values()].sort((a,b)=>b.rate-a.rate).slice(0,15);
      snapshots.set(job,group);
    }
  };
  return server;
}
module.exports = { createFinderServer };
if (require.main === module) {
  const path = require('node:path'), fs = require('node:fs');
  const configPath = process.argv[2] || path.join(__dirname, 'host-config.json');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const port = Number(config.port) || 32487;
  const iconPath=path.join(__dirname,'finder-icon.jpg');
  createFinderServer({ roomKey: config.roomKey, viewerKeyHash: config.viewerKeyHash, iconBytes:fs.existsSync(iconPath)?fs.readFileSync(iconPath):undefined }).listen(port, '127.0.0.1', () => console.log(`NYX Finder listening on 127.0.0.1:${port}`));
}

